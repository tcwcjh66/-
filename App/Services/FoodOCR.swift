import UIKit
import Vision
import ImageIO
import CoreImage

/// 一个字和它在图上的位置。位置是分组的关键：一包零食上的字凑在一起。
struct OCRWord {
    var text: String
    var box: CGRect
    /// 这张是图像旋转 90° 后读出来的竖排字，位置不可靠，单独成组
    var rotated: Bool = false
}

struct FoodMatch {
    var food: LocalFood
    var score: Double
    var keyword: String
    var grams: Double
    var note: String
    /// 这一组是几包（同款出现两次就记 2 份）
    var portions: Int = 1
}

/// 读包装上的字，按位置拆成一包一包，再分别去库里对。
/// 一桌五包零食，不能把二十个词搅在一起排名，那样永远只出四条。
enum FoodOCR {

    private static let noise = [
        "营养", "成分", "净含", "含量", "配料", "生产", "保质", "日期",
        "千焦", "能量", "蛋白", "脂肪", "碳水", "钠", "反式", "膳食纤维",
        "克", "毫升", "元", "箱", "袋装", "开袋", "即食", "食用", "请", "无添加",
        "配料表", "致敏", "贮存", "开封", "经销商", "地址", "电话", "标准"
    ]

    private static let flavors = [
        "香辣", "酸辣", "麻辣", "原味", "黄瓜", "番茄", "巧克力", "草莓",
        "烧烤", "藤椒", "海苔", "芝士", "榴莲", "芒果", "葡萄", "柠檬",
        "蜜桃", "乌龙", "抹茶", "咖啡", "生椰", "厚乳", "血糯米", "杨枝甘露"
    ]

    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - 一、读字

    static func read(_ image: UIImage) -> [OCRWord] {
        let scaled = image.preparingThumbnail(of: CGSize(width: 1440, height: 1440)) ?? image
        guard let cg = scaled.cgImage else { return [] }
        let orient = scaled.imageOrientation.cgOrientation

        var words = scan(cg, orient)

        // 中文不到六条，多半是小字、反光或逆光。提对比度再读一遍，再把下半张裁出来放大
        if words.filter({ han($0.text) >= 2 }).count < 6 {
            words += scan(enhanced(cg) ?? cg, orient)
            let w = cg.width
            let h = cg.height
            if let lower = cg.cropping(to: CGRect(x: 0, y: h / 2, width: w, height: h / 2)) {
                words += scan(enhanced(lower) ?? lower, orient)
            }
        }

        // 竖排字：窄而高，Vision 横向读基本读不出来，把整图转 90° 再读一遍
        let vertical = words.filter {
            $0.box.height > $0.box.width * 1.6
                && $0.box.width < 0.14
                && han($0.text) >= 2
        }
        if !vertical.isEmpty,
           words.filter({ han($0.text) >= 2 }).count < 10,
           let rc = rotated(cg) {
            for var w in scan(rc, orient) where han(w.text) >= 2 {
                w.rotated = true
                words.append(w)
            }
        }

        var seen = Set<String>()
        return words.filter { w in
            let k = clean(w.text)
                + "|" + String(Int(w.box.midX * 80))
                + "|" + String(Int(w.box.midY * 80))
            guard !k.isEmpty, !seen.contains(k) else { return false }
            seen.insert(k)
            return true
        }
    }

    private static func scan(_ cg: CGImage, _ orient: CGImagePropertyOrientation) -> [OCRWord] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["zh-Hans", "en-US"]
        req.usesLanguageCorrection = false
        req.minimumTextHeight = 0.006

        let handler = VNImageRequestHandler(cgImage: cg, orientation: orient, options: [:])
        do {
            try handler.perform([req])
        } catch {
            return []
        }
        return (req.results ?? []).compactMap { obs in
            guard let top = obs.topCandidates(1).first else { return nil }
            let t = top.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            return OCRWord(text: t, box: obs.boundingBox)
        }
    }

    /// 降低饱和度 + 提对比度：彩印包装上的小字会清楚很多
    private static func enhanced(_ cg: CGImage) -> CGImage? {
        let input = CIImage(cgImage: cg)
        guard let f = CIFilter(name: "CIColorControls") else { return nil }
        f.setValue(input, forKey: kCIInputImageKey)
        f.setValue(1.24, forKey: kCIInputContrastKey)
        f.setValue(0.0, forKey: kCIInputSaturationKey)
        f.setValue(0.04, forKey: kCIInputBrightnessKey)
        guard let out = f.outputImage else { return nil }
        return ciContext.createCGImage(out, from: out.extent)
    }

    /// 给空态回显用的干净词表：去掉营养表之类的噪音，长词优先
    static func readable(_ words: [OCRWord]) -> [String] {
        words.map { $0.text }
            .filter { t in
                let c = clean(t)
                guard c.count >= 2, c.count <= 12 else { return false }
                return !noise.contains(where: { c.contains($0) })
            }
            .sorted { $0.count > $1.count }
    }

    private static func rotated(_ cg: CGImage) -> CGImage? {
        let w = cg.width
        let h = cg.height
        guard let ctx = CGContext(data: nil, width: h, height: w,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: CGFloat(h) / 2, y: CGFloat(w) / 2)
        ctx.rotate(by: .pi / 2)
        ctx.draw(cg, in: CGRect(x: -CGFloat(w) / 2, y: -CGFloat(h) / 2,
                                width: CGFloat(w), height: CGFloat(h)))
        return ctx.makeImage()
    }

    // MARK: - 二、按位置拆成一包一组

    static func clusters(_ words: [OCRWord]) -> [[OCRWord]] {
        var groups: [[OCRWord]] = []
        var vertical = words.filter { $0.rotated }
        if !vertical.isEmpty {
            // 竖排词按横坐标分桶，一桶一包，别把五包的字搅在一组
            var buckets: [Int: [OCRWord]] = [:]
            for w in vertical { buckets[Int(w.box.midX / 0.25), default: []].append(w) }
            for (_, v) in buckets { groups.append(v) }
            vertical.removeAll()
        }
        for w in words.filter({ !$0.rotated }).sorted(by: { $0.box.midY > $1.box.midY }) {
            var placed = false
            for i in groups.indices {
                let near = groups[i].contains { o in
                    abs(o.box.midY - w.box.midY) < 0.115
                        && abs(o.box.midX - w.box.midX) < 0.33
                }
                if near {
                    groups[i].append(w)
                    placed = true
                    break
                }
            }
            if !placed { groups.append([w]) }
        }
        return groups
    }

    // MARK: - 三、一组一组去对库

    static func match(_ words: [OCRWord], boost: [String: Double] = [:]) -> [FoodMatch] {
        var out: [FoodMatch] = []

        var centers: [String: [CGFloat]] = [:]

        for g in clusters(words) {
            let best = matchGroup(g, boost: boost)
            guard let top = best.first, top.score >= 40 else { continue }
            let cx = g.map { $0.box.midX }.reduce(0, +) / CGFloat(max(1, g.count))

            if let i = out.firstIndex(where: { $0.food.name == top.food.name }) {
                // 横向隔得开才是另一包；同一包上下两段读到同款不算两份
                if let cs = centers[top.food.name], cs.allSatisfy({ abs($0 - cx) > 0.18 }) {
                    out[i].portions += 1
                }
                centers[top.food.name, default: []].append(cx)
            } else {
                out.append(top)
                centers[top.food.name] = [cx]
            }

            // 这一组认得很勉强，把它组里的备选也摆上来，让用户自己挑
            if top.score < 62, best.count > 1, !out.contains(where: { $0.food.name == best[1].food.name }) {
                out.append(best[1])
            }
        }

        let strong = out.filter { $0.score >= 62 }.sorted { $0.score > $1.score }
        let weak = out.filter { $0.score < 62 }.sorted { $0.score > $1.score }
        if strong.isEmpty { return Array(weak.prefix(4)) }
        return Array((strong + Array(weak.prefix(2))).prefix(6))
    }


    // MARK: - 四、把引擎看到的每一步摊开

    /// 一条分组诊断：这组读了哪些字、落在哪、认成什么、多少分、净含量从哪段抠的
    struct GroupDiag: Identifiable {
        var id: Int
        var words: [String]
        var centerX: CGFloat
        var name: String
        var score: Double
        var keyword: String
        var net: Double?
    }

    /// 识别调试台的数据源。阈值猜不准的时候，就靠它看真照片上到底发生了什么事。
    static func diagnostics(_ words: [OCRWord],
                            boost: [String: Double] = [:]) -> (groups: [GroupDiag], vertical: Int) {
        var out: [GroupDiag] = []
        for (i, g) in clusters(words).enumerated() {
            let best = matchGroup(g, boost: boost)
            let cx = g.map { $0.box.midX }.reduce(0, +) / CGFloat(max(1, g.count))
            out.append(GroupDiag(
                id: i + 1,
                words: g.map { "\($0.text)@(\(String(format: "%.2f", $0.box.midX)),\(String(format: "%.2f", $0.box.midY)))" },
                centerX: cx,
                name: best.first?.food.name ?? "",
                score: best.first?.score ?? 0,
                keyword: best.first?.keyword ?? "",
                net: netWeight(g.map { $0.text })
            ))
        }
        return (out, words.filter { $0.rotated }.count)
    }

    private static func matchGroup(_ group: [OCRWord], boost: [String: Double]) -> [FoodMatch] {
        let ordered = group.sorted { $0.box.midX < $1.box.midX }
        var texts: [String] = ordered.map { $0.text }

        // 同一行被切成两段（「魔芋」+「爽」），拼起来才算一个整词
        if ordered.count > 1 {
            for i in 0..<(ordered.count - 1) {
                let a = clean(ordered[i].text)
                let b = clean(ordered[i + 1].text)
                if a.count >= 2, a.count <= 7, b.count >= 2, b.count <= 7 {
                    texts.append(a + b)
                }
            }
        }

        let net = netWeight(texts)
        let learned = FoodLearn.snapshot()
        var best: [String: FoodMatch] = [:]

        func offer(_ f: LocalFood, _ score: Double, _ key: String) {
            // 你近一个月常吃的东西，模糊时优先给它；上限 6 分，不越级抢确定结果
            var s = score + min(6, boost[f.name] ?? 0)
            if flavors.contains(where: { key.contains($0) && f.name.contains($0) }) { s += 6 }
            if let old = best[f.name], old.score >= s { return }
            let isBrandOnly = s < 60
            let note = isBrandOnly
                ? "读到品牌「\(key)」，同品牌里选一款"
                : "读包装「\(key)」"
            best[f.name] = FoodMatch(food: f, score: s, keyword: key, grams: f.portion, note: note)
        }

        for raw in texts {
            let c = clean(raw)
            guard c.count >= 2, c.count <= 16 else { continue }
            guard !noise.contains(where: { c.contains($0) }) else { continue }
            guard han(c) >= 2 else { continue }
            if c.count > 10 && !looksLikeProduct(c) { continue }

            if let name = learned[c], let f = FoodBase.byName[name] {
                offer(f, 97, c)
                continue
            }

            // 整串交给统一匹配。库里常没有同名条目（读到「乐事原味薯片」，库里叫「乐事薯片原味」），
            // 只按名字包含去比就只剩品牌级结果，用户看到的永远是「同品牌里选一款」。
            for fs in FoodRank.rank(c, limit: 3) where fs.score >= 72 {
                offer(fs.food, min(96, fs.score), c)
            }

            for f in FoodBase.items {
                if f.name == c { offer(f, 100, c); continue }
                if f.aliases.contains(where: { $0 == c }) { offer(f, 94, c); continue }
                if f.name.contains(c) { offer(f, 76, c); continue }
                if !f.brand.isEmpty, c.contains(f.brand) { offer(f, 46, f.brand); continue }
                if f.aliases.contains(where: { clean($0).contains(c) && c.count >= 3 }) {
                    offer(f, 68, c); continue
                }
            }
        }

        var picked = Array(best.values.sorted { $0.score > $1.score }.prefix(2))

        // 净含量只算这一包自己的，不跨包乱套
        if let net, net >= 5, net <= 800, !picked.isEmpty {
            picked[0].grams = net
            picked[0].note += " · 净含量 \(Int(net))g"
        }
        return picked
    }

    // MARK: - 小工具

    private static func netWeight(_ texts: [String]) -> Double? {
        for t in texts {
            let c = clean(t)
            guard c.contains("净含") || c.contains("净重") || c.contains("规格") else { continue }
            let nums = c.split(whereSeparator: { !"0123456789.".contains($0) })
                .compactMap { Double($0) }
            if let v = nums.first(where: { $0 >= 5 && $0 <= 800 && $0 != 100 }) {
                return v
            }
        }
        return nil
    }

    private static func looksLikeProduct(_ c: String) -> Bool {
        if c.hasPrefix("本") || c.hasPrefix("如") || c.hasPrefix("请") || c.contains("有限") { return false }
        return flavors.contains(where: { c.contains($0) })
            || ["薯", "糖", "面", "茶", "奶", "片", "条", "干", "饼", "果", "冻", "肠", "爪", "酥", "糕"].contains(where: { c.contains($0) })
    }

    private static func clean(_ raw: String) -> String {
        raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "：", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }

    private static func han(_ s: String) -> Int {
        s.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
    }
}

private extension UIImage.Orientation {
    var cgOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

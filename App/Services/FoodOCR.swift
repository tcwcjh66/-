import UIKit
import Vision
import ImageIO

/// 一条识别候选：命中哪款、命中分数、按多少克算、这句话怎么解释给用户
struct FoodMatch {
    var food: LocalFood
    var score: Double
    var keyword: String
    var grams: Double
    var note: String
}

/// 读照片里的字，再按「别名 > 名字 > 品牌」三级去库里对。
/// 包装零食、现制饮品没有形状可言，只有字是最硬的证据。
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

    // MARK: - 读字

    static func texts(in image: UIImage) -> [String] {
        let scaled = image.preparingThumbnail(of: CGSize(width: 1200, height: 1200)) ?? image
        guard let cg = scaled.cgImage else { return [] }
        let orient = scaled.imageOrientation.cgOrientation

        var found: [String] = []
        found += read(cg, orient)

        // 全图读到的中文太少，说明字很小或者聚在桌面那一片，再切两刀放大读
        let meaningful = found.filter { han($0) >= 2 }
        if meaningful.count < 5 {
            let w = cg.width
            let h = cg.height
            if let lower = cg.cropping(to: CGRect(x: 0, y: h / 2, width: w, height: h / 2)) {
                found += read(lower, orient)
            }
            if let mid = cg.cropping(to: CGRect(x: 0, y: h / 3, width: w, height: h / 3)) {
                found += read(mid, orient)
            }
        }

        // 同一行字常被切成两段（「魔芋」+「爽」），拼起来才算一个整词
        if found.count > 1 {
            var joined: [String] = []
            for i in 0..<(found.count - 1) {
                let a = clean(found[i])
                let b = clean(found[i + 1])
                if a.count >= 2, a.count <= 7, b.count >= 2, b.count <= 7 {
                    joined.append(a + b)
                }
            }
            found += joined
        }

        // 去重后按长度排，长词信息量大
        var seen = Set<String>()
        var out: [String] = []
        for t in found {
            let k = clean(t)
            guard k.count >= 2, !seen.contains(k) else { continue }
            seen.insert(k)
            out.append(t)
        }
        return out.sorted { clean($0).count > clean($1).count }
    }

    private static func read(_ cg: CGImage, _ orient: CGImagePropertyOrientation) -> [String] {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["zh-Hans", "en-US"]
        req.usesLanguageCorrection = false
        req.minimumTextHeight = 0.008

        let handler = VNImageRequestHandler(cgImage: cg, orientation: orient, options: [:])
        do {
            try handler.perform([req])
        } catch {
            return []
        }
        return (req.results ?? []).compactMap { obs in
            obs.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - 对库

    static func match(_ texts: [String]) -> [FoodMatch] {
        var best: [String: FoodMatch] = [:]
        let net = netWeight(texts)
        let learned = FoodLearn.snapshot()

        func offer(_ f: LocalFood, _ score: Double, _ key: String) {
            var s = score
            // 文字里带口味词、食物名里也有，多半就是这一款
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
            // 一整句读者须知之类，不像商品名
            if c.count > 10 && !looksLikeProduct(c) { continue }

            // 上一回你亲手确认过的，优先级压在别名之上
            if let name = learned[c], let f = FoodBase.byName[name] {
                offer(f, 97, c)
                continue
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

        let all = best.values.sorted { $0.score > $1.score }
        let strong = all.filter { $0.score >= 62 }
        var picked = strong.isEmpty ? Array(all.prefix(4)) : Array(strong.prefix(4))

        // 读到净含量就按实际规格算，别一律按库里默认那份
        if let net, net >= 5, net <= 800, !picked.isEmpty {
            for i in 0..<min(2, picked.count) {
                picked[i].grams = net
                picked[i].note += " · 净含量 \(Int(net))g"
            }
        }
        return picked
    }

    /// 从「净含量 45g」「净重：45 克」里抠出真实规格
    private static func netWeight(_ texts: [String]) -> Double? {
        for t in texts {
            let c = clean(t)
            guard c.contains("净含") || c.contains("净重") || c.contains("规格") else { continue }
            let nums = c.split(whereSeparator: { !"0123456789.".contains($0) })
                .compactMap { Double($0) }
            // 排除「100g」这种营养成分表的每百克基准
            if let v = nums.first(where: { $0 >= 5 && $0 <= 800 && $0 != 100 }) {
                return v
            }
        }
        return nil
    }

    private static func looksLikeProduct(_ c: String) -> Bool {
        // 商品名一般含品牌字或口味字，读者须知多半是「本产品…」「如有…」
        if c.hasPrefix("本") || c.hasPrefix("如") || c.hasPrefix("请") || c.contains("有限") { return false }
        return flavors.contains(where: { c.contains($0) })
            || ["薯", "糖", "面", "茶", "奶", "片", "条", "干", "饼", "果", "冻", "肠", "爪", "酥", "糕"].contains(where: { c.contains($0) })
    }

    // MARK: - 小工具

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

import UIKit

struct FoodHit: Identifiable {
    let id = UUID()
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carb: Double
    var fat: Double
    var veg: Double
    var confidence: Double
    /// 这条结果是哪来的：读包装上的字，还是按颜色猜的
    var source: String = "按颜色猜"
    /// 命中的那个词，用户确认后拿去记进学习表
    var keyword: String = ""
}

/// 本机食物识别，两步走：
/// 1. 先用 Vision 读包装上印的字（零食、饮料、连锁品牌全靠这个），读到就去库里对名字；
/// 2. 读不到字才退回颜色分析（白/绿/红/黄的像素比例估米饭、青菜、肉）。
/// 包装袋颜色又艳又杂，这种情况宁可不给结果，也不硬猜成米饭。
enum FoodVision {

    static func analyze(_ image: UIImage) -> [FoodHit] {
        analyzeDetailed(image).hits
    }

    /// 除了结果，还把这回读到的字一并带回去：认不出时把它们摆给用户看，
    /// 比只说一句「没认出来」有用得多，用户会更正拍法或报个准名字。
    static func analyzeDetailed(_ image: UIImage) -> (hits: [FoodHit], words: [String]) {
        let words = FoodOCR.texts(in: image)
        let matched = FoodOCR.match(words)
        if !matched.isEmpty {
            let hits: [FoodHit] = matched.map { m in
                let g = max(1, m.grams)
                let r = g / 100
                return FoodHit(name: m.food.name,
                               grams: g,
                               kcal: m.food.kcal * r,
                               protein: m.food.protein * r,
                               carb: m.food.carb * r,
                               fat: m.food.fat * r,
                               veg: 0,
                               confidence: min(0.99, max(0.4, m.score / 100)),
                               source: m.note,
                               keyword: m.keyword)
            }
            return (hits.sorted { $0.confidence > $1.confidence }, words)
        }

        guard let cg = image.cgImage else { return ([], words) }
        let w = 40
        let h = 40
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return ([], words) }

        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let raw = ctx.data else { return ([], words) }
        let buf = raw.assumingMemoryBound(to: UInt8.self)

        var white = 0
        var green = 0
        var meat = 0
        var yellow = 0
        var orange = 0
        var brown = 0
        var total = 0
        var satSum = 0.0

        for y in 3..<(h - 3) {
            for x in 3..<(w - 3) {
                let i = (y * w + x) * 4
                let r = Double(buf[i]) / 255.0
                let g = Double(buf[i + 1]) / 255.0
                let b = Double(buf[i + 2]) / 255.0
                let v = max(r, max(g, b))
                let mn = min(r, min(g, b))
                let s = v > 0.001 ? (v - mn) / v : 0

                total += 1
                satSum += s

                if v > 0.80 && s < 0.15 {
                    white += 1
                } else if g >= r && g >= b && s > 0.20 && v > 0.18 {
                    green += 1
                } else if r > 0.26 && r >= g && g >= b && (r - b) > 0.10 {
                    meat += 1
                } else if r > 0.62 && g > 0.52 && b < 0.52 && s > 0.22 {
                    yellow += 1
                } else if r > 0.70 && g > 0.38 && g < 0.68 && b < 0.40 && (r - b) > 0.35 {
                    orange += 1
                } else if r > 0.30 && r < 0.58 && g > 0.16 && g < 0.44 && b < 0.30 && s > 0.24 {
                    brown += 1
                }
            }
        }

        guard total > 0 else { return ([], words) }

        // 一堆彩色包装袋：平均饱和度很高，这时候按颜色猜只会猜出「白米饭 + 青菜」这种废话
        let avgSat = satSum / Double(total)
        if avgSat > 0.42 { return ([], words) }

        let pw = Double(white) / Double(total)
        let pg = Double(green) / Double(total)
        let pm = Double(meat) / Double(total)
        let py = Double(yellow) / Double(total)
        let po = Double(orange) / Double(total)
        let pb = Double(brown) / Double(total)

        var hits: [FoodHit] = []

        if pw > 0.10 {
            let grams = clamp(roundTo5(pw * 420 + 55), 60, 320)
            hits.append(FoodHit(
                name: "白米饭 / 主食",
                grams: grams,
                kcal: grams * 1.16,
                protein: grams * 0.026,
                carb: grams * 0.259,
                fat: grams * 0.003,
                veg: 0,
                confidence: min(0.95, 0.55 + pw * 0.8)
            ))
        }

        if pg > 0.07 {
            let grams = clamp(roundTo5(pg * 900 + 35), 40, 260)
            hits.append(FoodHit(
                name: "深色绿叶菜",
                grams: grams,
                kcal: grams * 0.30,
                protein: grams * 0.025,
                carb: grams * 0.055,
                fat: grams * 0.004,
                veg: grams,
                confidence: min(0.92, 0.52 + pg * 1.1)
            ))
        }

        if pm > 0.08 {
            let grams = clamp(roundTo5(pm * 620 + 40), 45, 260)
            hits.append(FoodHit(
                name: "肉类（猪/牛/鸡）",
                grams: grams,
                kcal: grams * 1.55,
                protein: grams * 0.194,
                carb: grams * 0.005,
                fat: grams * 0.085,
                veg: 0,
                confidence: min(0.90, 0.50 + pm * 0.9)
            ))
        }

        if py > 0.08 && hits.count < 3 {
            let grams = clamp(roundTo5(py * 520 + 30), 30, 200)
            hits.append(FoodHit(
                name: "蛋 / 玉米 / 面点",
                grams: grams,
                kcal: grams * 1.60,
                protein: grams * 0.085,
                carb: grams * 0.180,
                fat: grams * 0.060,
                veg: 0,
                confidence: min(0.85, 0.46 + py * 0.8)
            ))
        }

        if po > 0.09 && hits.count < 3 {
            let grams = clamp(roundTo5(po * 420 + 40), 40, 200)
            hits.append(FoodHit(
                name: "胡萝卜 / 番茄 / 南瓜",
                grams: grams,
                kcal: grams * 0.32,
                protein: grams * 0.011,
                carb: grams * 0.065,
                fat: grams * 0.004,
                veg: grams,
                confidence: min(0.82, 0.45 + po * 0.9)
            ))
        }

        if pb > 0.08 && hits.count < 3 {
            let grams = clamp(roundTo5(pb * 500 + 45), 45, 220)
            hits.append(FoodHit(
                name: "酱汁 / 红烧肉",
                grams: grams,
                kcal: grams * 1.90,
                protein: grams * 0.13,
                carb: grams * 0.06,
                fat: grams * 0.13,
                veg: 0,
                confidence: min(0.80, 0.44 + pb * 0.8)
            ))
        }

        return (hits.sorted { $0.confidence > $1.confidence }, words)
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    private static func roundTo5(_ v: Double) -> Double {
        (v / 5).rounded() * 5
    }
}

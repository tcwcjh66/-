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
}

/// 本机食物识别：把照片缩到 40×40 采样，按像素色相/明度/饱和度分类，
/// 再用各颜色占据的比例换算分量。不做云端推理，断网也能出结果。
enum FoodVision {

    static func analyze(_ image: UIImage) -> [FoodHit] {
        guard let cg = image.cgImage else { return [] }
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
        ) else { return [] }

        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let raw = ctx.data else { return [] }
        let buf = raw.assumingMemoryBound(to: UInt8.self)

        var white = 0
        var green = 0
        var meat = 0
        var yellow = 0
        var total = 0

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

                if v > 0.80 && s < 0.15 {
                    white += 1
                } else if g >= r && g >= b && s > 0.20 && v > 0.18 {
                    green += 1
                } else if r > 0.26 && r >= g && g >= b && (r - b) > 0.10 {
                    meat += 1
                } else if r > 0.62 && g > 0.52 && b < 0.52 && s > 0.22 {
                    yellow += 1
                }
            }
        }

        guard total > 0 else { return [] }
        let pw = Double(white) / Double(total)
        let pg = Double(green) / Double(total)
        let pm = Double(meat) / Double(total)
        let py = Double(yellow) / Double(total)

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

        return hits.sorted { $0.confidence > $1.confidence }
    }

    private static func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }

    private static func roundTo5(_ v: Double) -> Double {
        (v / 5).rounded() * 5
    }
}

import UIKit
import Vision
import ImageIO

/// 读照片里的文字。包装零食靠颜色永远认不出，但包装上一定印着大字，
/// 用 Vision 的文本识别（本机跑，离线可用）把字读出来，再去食物库按名字对。
enum FoodOCR {

    private static let noise = [
        "营养", "成分", "净含", "含量", "配料", "生产", "保质", "日期", "保质期",
        "千焦", "能量", "蛋白", "脂肪", "碳水", "钠", "反式", "膳食纤维",
        "克", "毫升", "元", "箱", "袋装", "开袋", "即食", "食用", "请", "无添加"
    ]

    static func texts(in image: UIImage) -> [String] {
        // 大图先缩到 1200，识别快一些，包装上的大字照样读得出来
        let scaled = image.preparingThumbnail(of: CGSize(width: 1200, height: 1200)) ?? image
        guard let cg = scaled.cgImage else { return [] }

        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.recognitionLanguages = ["zh-Hans", "en-US"]
        req.usesLanguageCorrection = false
        req.minimumTextHeight = 0.010

        let handler = VNImageRequestHandler(cgImage: cg,
                                            orientation: scaled.imageOrientation.cgOrientation,
                                            options: [:])
        do {
            try handler.perform([req])
        } catch {
            return []
        }

        let shapes = (req.results ?? []).compactMap { obs -> (String, Double)? in
            guard let c = obs.topCandidates(1).first else { return nil }
            let t = c.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            let area = Double(obs.boundingBox.width * obs.boundingBox.height)
            return (t, area)
        }
        // 字大、面积大的排前面，那是包装正面的大字
        return shapes.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    /// 把 OCR 读到的词去库里找同名食物。长词优先，避免「卫龙」这种品牌词乱命中
    static func hits(from texts: [String], limit: Int = 4) -> [(LocalFood, String)] {
        var out: [(LocalFood, String)] = []
        var seen = Set<String>()

        for raw in texts {
            let clean = raw
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "　", with: "")
                .replacingOccurrences(of: "：", with: "")
            guard clean.count >= 2, clean.count <= 14 else { continue }
            guard !noise.contains(where: { clean.contains($0) }) else { continue }
            // 纯数字、纯英文商品码一律跳过
            let hanCount = clean.unicodeScalars.filter { $0.value >= 0x4E00 && $0.value <= 0x9FFF }.count
            guard hanCount >= 2 else { continue }

            if let f = FoodBase.items.first(where: { $0.name.contains(clean) }) {
                if seen.contains(f.name) { continue }
                seen.insert(f.name)
                out.append((f, clean))
            }
            if out.count >= limit { break }
        }
        return out
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

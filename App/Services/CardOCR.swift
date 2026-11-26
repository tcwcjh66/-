import UIKit
import Vision
import ImageIO

/// 门禁卡正面通常印着一串 8–16 位卡号，拍下来读它，比手抄十六位数字省事得多。
enum CardOCR {

    static func codes(in image: UIImage) -> [String] {
        let scaled = image.preparingThumbnail(of: CGSize(width: 1400, height: 1400)) ?? image
        guard let cg = scaled.cgImage else { return [] }
        let orient = scaled.imageOrientation.cardOrientation

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

        var found: [String] = []
        for obs in req.results ?? [] {
            for cand in obs.topCandidates(3) {
                found += extract(cand.string)
            }
        }

        var seen = Set<String>()
        return found
            .filter { seen.insert($0).inserted }
            .sorted { $0.count > $1.count }
    }

    /// 把「1234 5678」「0012-3456-7890」这类分隔写法先合并，再抓 8–16 位纯数字
    private static func extract(_ raw: String) -> [String] {
        let compact = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "—", with: "")
            .replacingOccurrences(of: "_", with: "")

        var out: [String] = []
        var run = ""
        for ch in compact {
            if ch.isNumber {
                run.append(ch)
            } else {
                if run.count >= 8 && run.count <= 16 { out.append(run) }
                run = ""
            }
        }
        if run.count >= 8 && run.count <= 16 { out.append(run) }
        return out
    }
}

private extension UIImage.Orientation {
    var cardOrientation: CGImagePropertyOrientation {
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

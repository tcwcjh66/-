import SwiftUI
import Photos
import UIKit

/// 训练成绩单：把结算页的核心数字渲成一张 3x 竖图，存进相簿或直接分享。
enum TWShareCard {
    @MainActor
    static func render(entry: SessionLog, streak: Int, headline: String, subline: String) -> UIImage? {
        let card = ShareCardContent(entry: entry, streak: streak, headline: headline, subline: subline)
            .frame(width: 340, height: 460)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage
    }

    static func save(_ image: UIImage, done: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { done(false) }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { ok, _ in
                DispatchQueue.main.async { done(ok) }
            }
        }
    }
}

struct ShareCardContent: View {
    let entry: SessionLog
    let streak: Int
    let headline: String
    let subline: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.28, blue: 0.86),
                    Color(red: 0.24, green: 0.18, blue: 0.62),
                    Color(red: 0.10, green: 0.10, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 右上角一圈光，给纯色底一点层次
            Circle()
                .fill(Color(red: 0.62, green: 0.46, blue: 0.98).opacity(0.55))
                .frame(width: 220, height: 220)
                .blur(radius: 60)
                .offset(x: 120, y: -150)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                    Text("天才威")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Text(DateFormatter.twShort.string(from: Date()))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Image("avatar-win")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                Text(headline)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text("\(entry.plan) · \(entry.day)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.top, 3)

                HStack(spacing: 0) {
                    stat("\(entry.sets)", "组")
                    stat("\(entry.minutes)", "分钟")
                    stat("\(entry.moves)", "个动作")
                    if streak > 1 { stat("\(streak)", "连续天") }
                }
                .padding(.top, 16)

                if let t = entry.tonnage, t > 0 {
                    Text("总容量 \(Int(t)) kg")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.top, 10)
                }

                Text(subline)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(2)
                    .padding(.top, 8)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "iphone")
                        .font(.system(size: 9))
                    Text("天才威 · 本机记录，不含模拟数据")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.white.opacity(0.4))
            }
            .padding(22)
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(v)
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 周报长图

struct WeekSnapshot {
    var range: String
    var sets: Int
    var mins: Int
    var tonnage: Double
    var steps: Int
    var verdict: String
    var insight: String
}

enum TWWeekCard {
    @MainActor
    static func render(_ s: WeekSnapshot) -> UIImage? {
        let card = WeekCardContent(s: s).frame(width: 340, height: 560)
        let r = ImageRenderer(content: card)
        r.scale = 3
        return r.uiImage
    }
}

struct WeekCardContent: View {
    let s: WeekSnapshot

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(red: 0.10, green: 0.10, blue: 0.20),
                Color(red: 0.30, green: 0.20, blue: 0.58),
                Color(red: 0.44, green: 0.30, blue: 0.90)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Color(red: 0.62, green: 0.46, blue: 0.98).opacity(0.45))
                .frame(width: 240, height: 240)
                .blur(radius: 70)
                .offset(x: 130, y: 190)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("天才威 · 周报")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.9))

                Text(s.range)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .monospacedDigit()
                    .padding(.top, 4)

                Text(s.verdict)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 18)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    stat("\(s.sets)", "组")
                    stat("\(s.mins)", "分钟")
                    stat(s.tonnage > 0 ? "\(Int(s.tonnage))" : "—", "总容量 kg")
                    stat(s.steps > 0 ? "\(s.steps)" : "—", "日均步数")
                }
                .padding(.top, 20)

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 0.7)
                    .padding(.vertical, 18)

                Text(s.insight)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "iphone")
                        .font(.system(size: 9))
                    Text("本机记录，不含模拟数据")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.white.opacity(0.38))
            }
            .padding(22)
        }
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(v)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

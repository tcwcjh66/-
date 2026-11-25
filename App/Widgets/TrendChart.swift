import SwiftUI

/// 真实数据折线图。数据来自 TWStore.logs（本地持久化），没有数据时明确显示占位而不是造假点。
struct TrendChart: View {
    var title: String
    var values: [Double]
    var labels: [String]
    var tint: Color
    var unit: String
    var decimals: Int = 0

    private var maxV: Double { max(values.max() ?? 1, 1) }
    private var minV: Double { values.min() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                if let last = values.last {
                    Text(fmt(last) + " " + unit)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                }
            }

            if values.count >= 2 {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let span = max(maxV - minV, 1)
                    let pts: [CGPoint] = values.enumerated().map { i, v in
                        CGPoint(
                            x: w * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                            y: h - CGFloat((v - minV) / span) * h * 0.78 - h * 0.11
                        )
                    }

                    ZStack {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h))
                            for pt in pts { p.addLine(to: pt) }
                            p.addLine(to: CGPoint(x: w, y: h))
                        }
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.26), tint.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        Path { p in
                            p.move(to: pts[0])
                            for pt in pts.dropFirst() { p.addLine(to: pt) }
                        }
                        .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                        ForEach(Array(pts.enumerated()), id: \.offset) { pair in
                            Circle()
                                .fill(tint)
                                .frame(width: pair.offset == pts.count - 1 ? 7 : 4,
                                       height: pair.offset == pts.count - 1 ? 7 : 4)
                                .position(pair.element)
                        }
                    }
                }
                .frame(height: 88)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.34))
                    .frame(height: 88)
                    .overlay {
                        Text("记录满 2 天后出现趋势")
                            .font(.system(size: 12))
                            .foregroundStyle(TWColor.ink3)
                    }
            }

            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { pair in
                    Text(pair.element)
                        .font(.system(size: 10.5))
                        .foregroundStyle(TWColor.ink3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func fmt(_ v: Double) -> String {
        if decimals == 0 { return "\(Int(v))" }
        return String(format: "%.\(decimals)f", v)
    }
}

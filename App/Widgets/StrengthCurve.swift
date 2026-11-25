import SwiftUI

/// 单个动作的力量曲线：把每次训练的最高 e1RM 连起来，看是不是真在变强。
struct StrengthCurveCard: View {
    let points: [E1RMPoint]

    private var firstKg: Double { points.first?.kg ?? 0 }
    private var lastKg: Double { points.last?.kg ?? 0 }
    private var delta: Double { lastKg - firstKg }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("力量曲线")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer(minLength: 0)
                if points.count >= 2 {
                    Text(delta >= 0 ? "+\(fmt(delta)) kg" : "\(fmt(delta)) kg")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(delta >= 0 ? TWColor.mint : TWColor.coral)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background {
                            Capsule().fill((delta >= 0 ? TWColor.mint : TWColor.coral).opacity(0.12))
                        }
                }
            }

            if points.count < 2 {
                Text("再练 1 次就能画出来了。每记一组都会算一次 e1RM（按重量和次数估的 1RM），攒够两次就成线。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                chart
                    .frame(height: 82)

                HStack {
                    Text(short(points.first?.date ?? ""))
                    Spacer()
                    Text("最新 \(fmt(lastKg)) kg")
                        .foregroundStyle(TWColor.purple)
                    Spacer()
                    Text(short(points.last?.date ?? ""))
                }
                .font(.system(size: 10))
                .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(14)
        .twGlass(radius: 18)
    }

    private var chart: some View {
        GeometryReader { geo in
            let pts = cgPoints(geo.size)
            ZStack(alignment: .topLeading) {
                // 三条参考基线
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(TWColor.ink3.opacity(0.10))
                        .frame(height: 0.6)
                        .offset(y: geo.size.height * CGFloat(i) / 2)
                }

                // 上映过来的面积，让线有重量
                Path { p in
                    guard pts.count > 1 else { return }
                    p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                    for q in pts { p.addLine(to: CGPoint(x: q.x, y: q.y)) }
                    p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                }
                .fill(
                    LinearGradient(colors: [TWColor.purple.opacity(0.18), TWColor.purple.opacity(0.0)],
                                   startPoint: .top, endPoint: .bottom)
                )

                Path { p in
                    guard pts.count > 1 else { return }
                    p.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
                    for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.x, y: q.y)) }
                }
                .stroke(
                    LinearGradient(colors: [TWColor.violet, TWColor.purple],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(pts.enumerated()), id: \.offset) { pair in
                    Circle()
                        .fill(pair.offset == pts.count - 1 ? TWColor.purple : TWColor.glass(0.9))
                        .frame(width: pair.offset == pts.count - 1 ? 7 : 5,
                               height: pair.offset == pts.count - 1 ? 7 : 5)
                        .overlay {
                            Circle().strokeBorder(TWColor.purple.opacity(pair.offset == pts.count - 1 ? 0 : 0.55),
                                                  lineWidth: 1)
                        }
                        .position(x: pair.element.x, y: pair.element.y)
                }
            }
        }
    }

    private struct Pt { var x: CGFloat; var y: CGFloat }

    private func cgPoints(_ size: CGSize) -> [Pt] {
        let hi = max(points.map(\.kg).max() ?? 1, 1)
        let lo = min(points.map(\.kg).min() ?? 0, hi)
        let span = max(hi - lo, 0.5)
        let pad: CGFloat = 6
        let usable = max(size.height - pad * 2, 1)
        return points.enumerated().map { i, p in
            let x = points.count <= 1 ? size.width / 2
                : size.width * CGFloat(i) / CGFloat(points.count - 1)
            let y = size.height - pad - CGFloat((p.kg - lo) / span) * usable
            return Pt(x: min(max(x, 2), size.width - 2), y: y)
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: v == v.rounded() ? "%.0f" : "%.1f", v)
    }

    private func short(_ d: String) -> String {
        // 2026-11-26 → 11/26
        let parts = d.split(separator: "-")
        guard parts.count == 3 else { return d }
        return "\(Int(parts[1]) ?? 0)/\(Int(parts[2]) ?? 0)"
    }
}

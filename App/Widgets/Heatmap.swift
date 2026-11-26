import SwiftUI

/// 训练热力图：一列一周、一行一天，颜色越深当天练得越多。
/// 数据来自 store.sessions，缺的日子留空格，不补假数据。
struct TrainingHeatmap: View {
    /// dayKey(yyyy-MM-dd) → 当天总吨位
    var values: [String: Double]
    var weeks: Int = 18
    var cell: CGFloat = 10

    private var maxV: Double {
        max(values.values.max() ?? 1, 1)
    }

    /// 一天只算一次，滚页面时不去反复跑 126 次 DateFormatter
    private static var keyCache: (day: String, cols: [[String]])?

    private var dayKeys: [[String]] {
        let stamp = DateFormatter.twDay.string(from: Date())
        if let c = Self.keyCache, c.day == stamp { return c.cols }
        let cols = buildKeys()
        Self.keyCache = (stamp, cols)
        return cols
    }

    private func buildKeys() -> [[String]] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 对齐到本周最后一天，让最后一列是"本周"
        var out: [[String]] = []
        let start = cal.date(byAdding: .day, value: -(weeks * 7 - 1), to: today) ?? today
        for w in 0..<weeks {
            var col: [String] = []
            for d in 0..<7 {
                let day = cal.date(byAdding: .day, value: w * 7 + d, to: start) ?? start
                col.append(DateFormatter.twDay.string(from: day))
            }
            out.append(col)
        }
        return out
    }

    private func tint(_ v: Double) -> Color {
        guard v > 0 else { return TWColor.glass(0.10) }
        let p = min(v / maxV, 1)
        return TWColor.purple.opacity(0.18 + 0.72 * p)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("训练热力")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
                Text("近 \(weeks) 周")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
            }

            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(dayKeys.enumerated()), id: \.offset) { col in
                    VStack(spacing: 3) {
                        ForEach(Array(col.element.enumerated()), id: \.offset) { row in
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(tint(values[row.element] ?? 0))
                                .frame(width: cell, height: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Text("少").font(.tw(10)).foregroundStyle(TWColor.ink3)
                ForEach(0..<4, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(TWColor.purple.opacity(i == 0 ? 0.10 : 0.18 + 0.24 * Double(i)))
                        .frame(width: 9, height: 9)
                }
                Text("多").font(.tw(10)).foregroundStyle(TWColor.ink3)
                Spacer(minLength: 0)
                Text("\(values.count) 天有记录")
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(16)
        .twGlass()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("训练热力图，近 \(weeks) 周，\(values.count) 天有记录")
    }
}

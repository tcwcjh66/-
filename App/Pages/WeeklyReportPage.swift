import SwiftUI

/// 最近 7 天的周报。所有数字都从本机日志现算，缺数据的天留空不补。
struct WeeklyReportPage: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    @State private var cardMsg: String? = nil

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: -(6 - $0), to: Date()) }
    }

    private var keys: [String] { days.map { dayFormatter.string(from: $0) } }

    private var weekSessions: [SessionLog] {
        store.sessions.filter { keys.contains($0.date) }
    }

    private var totalSets: Int { weekSessions.reduce(0) { $0 + $1.sets } }
    private var totalMins: Int { weekSessions.reduce(0) { $0 + $1.minutes } }

    private var totalTonnage: Double {
        weekSessions.reduce(0) { $0 + ($1.tonnage ?? 0) }
    }

    private func sets(on key: String) -> Int {
        weekSessions.filter { $0.date == key }.reduce(0) { $0 + $1.sets }
    }

    private var weekLogs: [DayLog] { store.logs.filter { keys.contains($0.id) } }

    private var avgSteps: Int {
        let vals = weekLogs.map { $0.steps }.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / vals.count
    }

    private var avgProtein: Double {
        let vals = weekLogs.compactMap { $0.protein }.filter { $0 > 0 }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var proteinRef: Double { store.dietTarget * 0.25 / 4 }

    private var weightChange: Double? {
        let vals = store.weightLogs.filter { keys.contains($0.id) }.sorted { $0.id < $1.id }
        guard let first = vals.first, let last = vals.last, vals.count >= 2 else { return nil }
        return last.kg - first.kg
    }

    private var trainDays: Int {
        Set(weekSessions.map { $0.date }).count
    }

    private var bestDay: (String, Int)? {
        let grouped = Dictionary(grouping: weekSessions, by: { $0.date })
            .mapValues { $0.reduce(0) { $0 + $1.sets } }
        guard let top = grouped.max(by: { $0.value < $1.value }), top.value > 0 else { return nil }
        return (top.key, top.value)
    }

    private var verdict: String {
        if trainDays >= 4 && totalSets >= 40 { return "这周练得很到位" }
        if trainDays >= 3 { return "节奏保住了，继续保持" }
        if trainDays >= 1 { return "练了 \(trainDays) 天，下周争取多一天" }
        return "这周还没开练，先补一次"
    }

    /// 一句能落地的话，不堆形容词
    private var insight: String {
        var parts: [String] = []
        if !weekLogs.isEmpty {
            let hit = weekLogs.filter { ($0.protein ?? 0) >= proteinRef }.count
            parts.append("蛋白达标 \(hit)/\(weekLogs.count) 天")
        }
        if avgSteps > 0 { parts.append("日均 \(avgSteps) 步") }
        if trainDays > 0 { parts.append("练 \(trainDays) 天 · \(Int(totalTonnage)) kg 容量") }
        if let w = weightChange {
            parts.append(String(format: "体重 %+.1f kg", w))
        }
        return parts.isEmpty ? "这周还没有能算的数据。" : parts.joined(separator: " · ")
    }

    // MARK: - 和上周比

    private var lastWeekKeys: [String] {
        let cal = Calendar.current
        return days.compactMap { cal.date(byAdding: .day, value: -7, to: $0) }
            .map { dayFormatter.string(from: $0) }
    }

    private var lastWeekLogs: [DayLog] {
        store.logs.filter { lastWeekKeys.contains($0.id) }
    }

    private var lastWeekAvgSteps: Int {
        let l = lastWeekLogs
        guard !l.isEmpty else { return 0 }
        return Int(l.reduce(0) { $0 + $1.steps } / l.count)
    }

    private var lastWeekTonnage: Double {
        store.sessions.filter { lastWeekKeys.contains($0.date) }
            .reduce(0) { $0 + ($1.tonnage ?? 0) }
    }

    private var lastWeekTrainDays: Int {
        Set(store.sessions.filter { lastWeekKeys.contains($0.date) }.map { $0.date }).count
    }

    /// 三项跟上周同期的对比；上周完全没有数据就不显示，免得出现「+8600」这种假涨幅
    private var vsLastWeek: String? {
        var parts: [String] = []

        if avgSteps > 0, lastWeekAvgSteps > 0 {
            let d = avgSteps - lastWeekAvgSteps
            parts.append(d == 0 ? "日均步数持平" : "日均步数 \(d > 0 ? "+" : "")\(d)")
        }

        if totalTonnage > 0, lastWeekTonnage > 0 {
            let d = Int(totalTonnage - lastWeekTonnage)
            parts.append("容量 \(d >= 0 ? "+" : "")\(d) kg")
        }

        if trainDays > 0 || lastWeekTrainDays > 0 {
            let d = trainDays - lastWeekTrainDays
            if d == 0 { parts.append("练的天数持平") }
            else { parts.append("\(d > 0 ? "多" : "少")练 \(abs(d)) 天") }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack {
            AuroraBG()

            ScrollView {
                VStack(spacing: 16) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本周报告")
                            .font(.tw(24, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Text("\(keys.first ?? "") 至 \(keys.last ?? "")")
                            .font(.tw(12))
                            .foregroundStyle(TWColor.ink3)
                            .monospacedDigit()
                        Text(verdict)
                            .font(.tw(13, .semibold))
                            .foregroundStyle(TWColor.purple)
                            .padding(.top, 4)

                        Text(insight)
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                            .lineSpacing(2.5)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)

                        if let v = vsLastWeek {
                            HStack(alignment: .top, spacing: 5) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.tw(9, .bold))
                                    .padding(.top, 2)
                                Text("比上周 " + v)
                                    .font(.tw(11))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(TWColor.purple.opacity(0.85))
                            .padding(.top, 3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)

                    HStack(spacing: 10) {
                        big("\(trainDays)", "训练天数", TWColor.purple)
                        big("\(totalSets)", "总组数", TWColor.blue)
                        big("\(totalMins)", "分钟", TWColor.coral)
                    }
                    .padding(.horizontal, 18)

                    // 每天组数柱
                    VStack(alignment: .leading, spacing: 12) {
                        Text("每天做了几组")
                            .font(.tw(13, .bold))
                            .foregroundStyle(TWColor.ink2)

                        let peak = max(1, days.map { sets(on: dayFormatter.string(from: $0)) }.max() ?? 1)
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(days, id: \.self) { d in
                                let key = dayFormatter.string(from: d)
                                let v = sets(on: key)
                                VStack(spacing: 5) {
                                    Text(v > 0 ? "\(v)" : "")
                                        .font(.tw(10, .bold))
                                        .foregroundStyle(TWColor.purple)
                                        .monospacedDigit()
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(LinearGradient(colors: [TWColor.purple.opacity(0.9), TWColor.violet.opacity(0.55)],
                                                             startPoint: .bottom, endPoint: .top))
                                        .frame(height: max(6, CGFloat(v) / CGFloat(peak) * 78))
                                    Text(weekName(d))
                                        .font(.tw(10, .medium))
                                        .foregroundStyle(Calendar.current.isDateInToday(d) ? TWColor.purple : TWColor.ink3)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 112, alignment: .bottom)

                        if let b = bestDay {
                            Text("练得最多的是 \(b.0)，\(b.1) 组")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                        } else {
                            Text("这周还没有训练记录")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                    }
                    .padding(16)
                    .twGlass()
                    .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        row("总吨位", totalTonnage > 0 ? "\(Int(totalTonnage)) kg" : "无记录")
                        divider
                        row("平均步数", avgSteps > 0 ? "\(avgSteps.formatted()) 步" : "无记录")
                        divider
                        row("平均蛋白", avgProtein > 0
                            ? String(format: "%.0f g / 天（参考目标 %.0f g）", avgProtein, proteinRef)
                            : "无记录")
                        divider
                        row("体重变化", weightText)
                        divider
                        row("今天饮水", "\(store.waterML) ml / \(store.waterTargetML) ml")
                    }
                    .padding(16)
                    .twGlass()
                    .padding(.horizontal, 18)

                    Text("周报只统计本机已有的记录；没连手表或没记饮食的日子不参与平均。")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    Button { saveWeekCard() } label: {
                        HStack(spacing: 7) {
                            Image(systemName: cardMsg == nil ? "square.and.arrow.down" : "checkmark.circle.fill")
                                .font(.tw(13, .bold))
                            Text(cardMsg ?? "存一张周报长图")
                                .font(.tw(14, .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                     startPoint: .leading, endPoint: .trailing))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)

                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        dismiss()
                    } label: {
                        Text("关掉")
                            .font(.tw(15, .bold))
                            .foregroundStyle(TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(TWColor.glass(0.5))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.35)) { appeared = true } }
    }

    @MainActor
    private func saveWeekCard() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        guard cardMsg == nil else { return }
        let snap = WeekSnapshot(
            range: "\(keys.first ?? "") 至 \(keys.last ?? "")",
            sets: totalSets,
            mins: totalMins,
            tonnage: totalTonnage,
            steps: avgSteps,
            verdict: verdict,
            insight: insight
        )
        guard let img = TWWeekCard.render(snap) else {
            cardMsg = "渲染失败"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { cardMsg = nil }
            return
        }
        TWShareCard.save(img) { ok in
            cardMsg = ok ? "已存进相簿" : "没存成，去设置给相册权限"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { cardMsg = nil }
        }
    }

    private var weightText: String {
        guard let d = weightChange else { return "本周不足两次记录" }
        if abs(d) < 0.05 { return "基本没动" }
        return String(format: "%@%.1f kg", d > 0 ? "涨了 " : "掉了 ", abs(d))
    }

    private var divider: some View {
        Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(height: 0.7)
    }

    private func weekName(_ d: Date) -> String {
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        return names[Calendar.current.component(.weekday, from: d) - 1]
    }

    private func big(_ v: String, _ unit: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(v)
                .font(.tw(24, .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(unit)
                .font(.tw(11, .semibold))
                .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TWColor.glass(0.5))
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k)
                .font(.tw(12.5, .medium))
                .foregroundStyle(TWColor.ink3)
            Spacer(minLength: 8)
            Text(v)
                .font(.tw(12.5, .semibold))
                .foregroundStyle(TWColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }
}

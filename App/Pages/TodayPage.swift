import SwiftUI
import UIKit

struct TodayPage: View {
    @EnvironmentObject var store: TWStore
    @State private var appeared = false
    @State private var showSettings = false
    @State private var showWaterLog = false
    var onOpenFlow: () -> Void = {}

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            heroDial
            ringsCard
            todayTrainCard
            statsRow
            waterQuick
            trendCard
            tipCard
            moodRow
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWaterLog) {
            WaterLogSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(TWColor.ink3)
                TwGradientText(text: "今天", size: 31)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 38, height: 38)
                    .twGlass(radius: 19)
            }
            .buttonStyle(.plain)
        }
    }

    private var heroDial: some View {
        ZStack {
            BigDial()
                .opacity(0.92)

            RadialGradient(
                colors: [TWColor.glass(0.45), .clear],
                center: .center, startRadius: 10, endRadius: 155
            )
            .frame(width: 310, height: 310)
            .blendMode(.plusLighter)

            LivingAvatar(asset: store.avatarAsset, mood: store.mood,
                         hour: Calendar.current.component(.hour, from: Date()))
                .id(store.avatarAsset)
                .transition(.opacity)
        }
        .frame(height: 322)
        .animation(.easeInOut(duration: 0.42), value: store.avatarAsset)
    }

    private var ringsCard: some View {
        HStack(spacing: 16) {
            FourRings(
                move: store.ringMove,
                exercise: store.ringExercise,
                stand: store.ringStand,
                hrv: store.ringHrv
            )
            .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 11) {
                ringRow(color: TWColor.purple, label: "活动", value: "\(Int(store.moveKcal))",
                        unit: "/\(Int(store.moveTarget))kcal")
                ringRow(color: TWColor.pink, label: "锻炼", value: "\(Int(store.exerciseMin))",
                        unit: "/\(Int(store.exerciseTarget))分")
                ringRow(color: TWColor.mint, label: "站立", value: "\(Int(store.standHours))",
                        unit: "/\(Int(store.standTarget))时")
                ringRow(color: TWColor.amber, label: "HRV", value: "\(store.hrv)", unit: "ms")
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .twGlass()
    }

    private func ringRow(color: Color, label: String, value: String, unit: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(TWColor.ink)
            Text(unit)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(TWColor.ink3)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(icon: "shoeprints.fill", title: "步数", value: "\(store.stepsForDisplay)", tint: TWColor.blue)
            statCard(icon: "heart.fill", title: "心率",
                     value: store.hr > 0 ? "\(store.hr)" : "—", tint: TWColor.coral)
            statCard(icon: "waveform.path.ecg", title: "HRV",
                     value: store.hrv > 0 ? "\(store.hrv)" : "—", tint: TWColor.mint)
        }
    }

    private var recentLogs: [DayLog] {
        Array(store.logs.suffix(7))
    }

    private var dayLabels: [String] {
        recentLogs.map { log in
            let p = log.id.split(separator: "-")
            if p.count == 3 { return "\(p[1])/\(p[2])" }
            return log.id
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            TrendChart(title: "步数 · 最近 7 天",
                       values: recentLogs.map { Double($0.steps) },
                       labels: dayLabels,
                       tint: TWColor.blue,
                       unit: "步")
            TrendChart(title: "心率 · 最近 7 天",
                       values: recentLogs.map { Double($0.hr) },
                       labels: dayLabels,
                       tint: TWColor.coral,
                       unit: "bpm")
        }
        .padding(16)
        .twGlass()
    }

    private func statCard(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
            }
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(TWColor.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .twGlass(radius: 17)
    }

    private var weekCount: Int {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let since = f.string(from: start)
        return store.sessions.filter { $0.date >= since }.count
    }

    private var todayTrainCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("今日训练")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: "本周 \(weekCount) 次", tint: TWColor.mint)
            }

            if store.sessionStart != nil {
                HStack(spacing: 8) {
                    Circle()
                        .fill(TWColor.purple)
                        .frame(width: 7, height: 7)
                    Text("正在练：\(store.sessionMoves.first ?? "")\(store.sessionMoves.count > 1 ? " 等" : "")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TWColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("已 \(store.sessionSets) 组")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                }
            } else if let hint = store.nextDayHint {
                HStack(spacing: 8) {
                    Text(hint.day)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(TWColor.ink)
                    Text(hint.plan)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(TWColor.ink3)
                    Spacer(minLength: 0)
                    if let last = store.sessions.first {
                        Text("上次 \(shortDay(last.date))")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
            } else {
                Text("还没有训练记录。挑一套方案，从今天开始。")
                    .font(.system(size: 13))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenFlow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(store.sessionStart != nil ? "回到训练" : "去训练")
                        .font(.system(size: 14.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .twGlass(radius: 18)
    }

    private func shortDay(_ raw: String) -> String {
        let p = raw.split(separator: "-")
        return p.count == 3 ? "\(p[1])/\(p[2])" : raw
    }

    private var waterQuick: some View {
        HStack(spacing: 11) {
            Image(systemName: "drop.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TWColor.blue)
                .frame(width: 30, height: 30)
                .background { Circle().fill(TWColor.blue.opacity(0.12)) }

            VStack(alignment: .leading, spacing: 2) {
                Text("饮水")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                Text("\(store.waterML) ml / \(store.waterTargetML) ml")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showWaterLog = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.blue)
                    .frame(width: 32, height: 32)
                    .background { Circle().fill(TWColor.blue.opacity(0.12)) }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation(.snappy(duration: 0.18)) { store.addWater() }
            } label: {
                Text("+1 杯")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                      startPoint: .leading, endPoint: .trailing))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .twGlass(radius: 17, shadow: false)
    }

    private var todayTip: (String, String, String, Color) {
        let hour = Calendar.current.component(.hour, from: Date())

        if store.sessionStart != nil {
            return ("训练中", "组间别拖太久，90 秒左右回来，全程保持呼吸。", "dumbbell.fill", TWColor.purple)
        }
        if store.hr > 0, store.restingHR > 0, store.hr > store.restingHR + 30 {
            return ("心率偏高", "静息比平时高 30 以上，今天别上强度，散步或拉伸即可。", "heart.fill", TWColor.coral)
        }
        if hour >= 22 {
            return ("该睡了", "睡眠是恢复的第一步，睡够了明天练才不白练。", "moon.fill", TWColor.blue)
        }
        if store.waterCups < 3, hour >= 12 {
            return ("水喝少了", "今天才 \(store.waterML) ml，先来一杯再练。", "drop.fill", TWColor.blue)
        }
        if let hint = store.nextDayHint {
            return ("今天该练", "\(hint.plan) · \(hint.day)，先热身 5 分钟再上重量。", "figure.strengthtraining.traditional", TWColor.mint)
        }
        return ("保持节奏", "今天没安排也没关系，走够步数、吃够蛋白就是在进步。", "leaf.fill", TWColor.mint)
    }

    private var tipCard: some View {
        let tip = todayTip
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: tip.2)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tip.3)
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(tip.3.opacity(0.14))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.0)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Text(tip.1)
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .twGlass(radius: 17)
    }

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天感觉怎么样")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text(moodLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
            }

            HStack(spacing: 8) {
                ForEach(moods) { m in
                    MoodChip(
                        option: m,
                        selected: store.mood == m.id,
                        onTap: { store.mood = m.id }
                    )
                }
            }
        }
        .padding(14)
        .twGlass(radius: 18)
    }

    private var moods: [MoodOption] {
        [
            MoodOption(id: "win",   name: "充沛", emoji: "😄"),
            MoodOption(id: "ok",    name: "还行", emoji: "🙂"),
            MoodOption(id: "tired", name: "疲惫", emoji: "🥲"),
            MoodOption(id: "sleep", name: "缺觉", emoji: "😴")
        ]
    }

    private var moodLabel: String {
        switch store.mood {
        case "win":   return "状态很好"
        case "tired": return "该减量了"
        case "sleep": return "优先补觉"
        case "calm":  return "平静 · 刚沉思过"
        default:      return "保持节奏"
        }
    }
}

struct MoodOption: Identifiable {
    let id: String
    var name: String
    var emoji: String
}

struct MoodChip: View {
    let option: MoodOption
    let selected: Bool
    let onTap: () -> Void

    private var fill: Color {
        selected ? TWColor.glass(0.85) : TWColor.glass(0.32)
    }

    private var stroke: Color {
        selected ? TWColor.purple.opacity(0.35) : TWColor.glass(0.5)
    }

    private var labelColor: Color {
        selected ? TWColor.ink : TWColor.ink3
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.snappy(duration: 0.26)) { onTap() }
        } label: {
            VStack(spacing: 4) {
                Text(option.emoji)
                    .font(.system(size: 23))
                Text(option.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(labelColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

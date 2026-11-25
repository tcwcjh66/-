import SwiftUI
import UIKit

struct TodayPage: View {
    @EnvironmentObject var store: TWStore
    @State private var appeared = false
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
            trendCard
            moodRow
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
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
            } label: {
                Image(systemName: "bell.badge")
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
                colors: [Color.white.opacity(0.45), .clear],
                center: .center, startRadius: 10, endRadius: 155
            )
            .frame(width: 310, height: 310)
            .blendMode(.plusLighter)

            LivingAvatar(asset: store.avatarAsset, mood: store.mood)
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
        selected ? Color.white.opacity(0.85) : Color.white.opacity(0.32)
    }

    private var stroke: Color {
        selected ? TWColor.purple.opacity(0.35) : Color.white.opacity(0.5)
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

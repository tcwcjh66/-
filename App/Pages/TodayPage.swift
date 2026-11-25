import SwiftUI
import UIKit

struct TodayPage: View {
    @EnvironmentObject var store: TWStore
    @State private var appeared = false

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
            statsRow
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
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(TWColor.ink3)
                TwGradientText(text: "今天", size: 31)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .semibold))
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
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundStyle(TWColor.ink2)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
            Text(unit)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(TWColor.ink3)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(icon: "shoeprints.fill", title: "步数", value: "\(store.steps)", tint: TWColor.blue)
            statCard(icon: "heart.fill", title: "心率", value: "\(store.hr)", tint: TWColor.coral)
            statCard(icon: "drop.fill", title: "饮水", value: "1.8", tint: TWColor.mint)
        }
    }

    private func statCard(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink3)
            }
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .twGlass(radius: 17)
    }

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天感觉怎么样")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text(moodLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 21))
                Text(option.name)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
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

import SwiftUI

/// 训练结束后的结算页。只展示这次真实记下来的数字，不编造重量。
struct SessionSummarySheet: View {
    var entry: SessionLog
    var prev: SessionLog?
    var streak: Int
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false

    private var setDelta: Int? {
        guard let p = prev else { return nil }
        return entry.sets - p.sets
    }

    private var minDelta: Int? {
        guard let p = prev else { return nil }
        return entry.minutes - p.minutes
    }

    private var headline: String {
        if entry.sets >= 25 { return "这顿练得挺狠" }
        if entry.sets >= 15 { return "节奏很稳" }
        if entry.sets >= 8 { return "完成得不错" }
        return "开了个头"
    }

    private var subline: String {
        if let d = setDelta, d > 0 {
            return "比上次同样的 \(entry.day) 多做了 \(d) 组"
        }
        if let d = setDelta, d == 0 {
            return "跟上一次 \(entry.day) 打平"
        }
        if let d = setDelta {
            return "比上次少 \(abs(d)) 组，今天可能是留力了"
        }
        return "这是第一记录这个 \(entry.day)"
    }

    var body: some View {
        ZStack {
            AuroraBG()

            ScrollView {
                VStack(spacing: 18) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .padding(.top, 8)

                    ZStack(alignment: .bottom) {
                        // 练完切胜利态：叉腰大笑那版
                        LivingAvatar(asset: "avatar-win", mood: "win", hour: -1)
                            .frame(height: 288)
                            .scaleEffect(appeared ? 1 : 0.58)
                            .opacity(appeared ? 1 : 0)

                        HStack(spacing: 5) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .heavy))
                            Text("训练完成")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background {
                            Capsule().fill(LinearGradient(colors: [TWColor.mint, TWColor.blue],
                                                          startPoint: .leading, endPoint: .trailing))
                        }
                        .shadow(color: TWColor.mint.opacity(0.35), radius: 9, y: 4)
                        .padding(.bottom, 4)
                    }
                    .frame(height: 288)

                    VStack(spacing: 6) {
                        Text(headline)
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(TWColor.ink)
                        Text("\(entry.plan) · \(entry.day)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TWColor.purple)
                        Text(subline)
                            .font(.system(size: 12.5))
                            .foregroundStyle(TWColor.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    HStack(spacing: 10) {
                        stat("\(entry.sets)", "组", TWColor.purple)
                        stat("\(entry.minutes)", "分钟", TWColor.blue)
                        stat("\(entry.moves)", "个动作", TWColor.coral)
                    }
                    .padding(.horizontal, 18)

                    VStack(spacing: 0) {
                        row("计划", "\(entry.plan)")
                        divider
                        row("训练日", entry.day)
                        divider
                        row("做完的动作", (entry.moveNames ?? []).joined(separator: " · "))
                        if streak > 1 {
                            divider
                            row("连续训练", "\(streak) 天")
                        }
                        if let m = minDelta {
                            divider
                            row("时长变化", m > 0 ? "多了 \(m) 分钟" : (m == 0 ? "持平" : "少了 \(abs(m)) 分钟"))
                        }
                        if let t = entry.tonnage, t > 0 {
                            divider
                            row("总吨位", "\(Int(t)) kg（重量 × 次数累计）")
                        }
                    }
                    .padding(16)
                    .twGlass()

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    } label: {
                        Text("收工")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { appeared = true }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.12))
            .frame(height: 0.7)
    }

    private func stat(_ v: String, _ unit: String, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(v)
                .font(.system(size: 26, weight: .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TWColor.glass(0.5))
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(k)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TWColor.ink3)
                .frame(width: 74, alignment: .leading)
            Text(v.isEmpty ? "—" : v)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TWColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }
}

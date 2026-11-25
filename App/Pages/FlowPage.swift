import SwiftUI
import Combine
import UIKit

struct FlowPage: View {
    @EnvironmentObject var store: TWStore

    @State private var total: Int = 90
    @State private var remain: Int = 90
    @State private var running: Bool = false
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        total > 0 ? Double(remain) / Double(total) : 0
    }

    private var clock: String {
        String(format: "%d:%02d", remain / 60, remain % 60)
    }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "训练", subtitle: "今日 · 上肢推")

            timerCard
            sessionCard
            tipCard
        }
        .onReceive(tick) { _ in
            guard running else { return }
            if remain > 0 {
                remain -= 1
            } else {
                running = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private var timerCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("组间休息")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: running ? "计时中" : "已暂停", tint: running ? TWColor.mint : TWColor.ink3)
            }

            ZStack {
                ProgressRing(
                    value: 1 - progress,
                    lineWidth: 13,
                    colors: [TWColor.purple, TWColor.pink, TWColor.violet],
                    size: 186
                )
                .opacity(0.9)

                VStack(spacing: 2) {
                    Text(clock)
                        .font(.system(size: 50, weight: .heavy))
                        .foregroundStyle(TWColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text("剩余")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(TWColor.ink3)
                }
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if remain == 0 { remain = total }
                    withAnimation(.snappy) { running.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: running ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(running ? "暂停" : (remain == 0 ? "再来一组" : "继续"))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy) {
                        running = false
                        remain = total
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 46)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.55))
                        }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach([60, 90, 120, 180], id: \.self) { s in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy) {
                            total = s
                            remain = s
                            running = false
                        }
                    } label: {
                        Text("\(s)s")
                            .font(.system(size: 13, weight: total == s ? .bold : .medium))
                            .foregroundStyle(total == s ? TWColor.purple : TWColor.ink3)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(total == s ? TWColor.purple.opacity(0.14) : Color.white.opacity(0.4))
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .twGlass()
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("上肢推 · 第 3 周")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: "4 个动作", tint: TWColor.blue)
            }

            ForEach(Array(sessionItems.enumerated()), id: \.offset) { pair in
                HStack(spacing: 10) {
                    Text("\(pair.offset + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background { Circle().fill(TWColor.purple.opacity(0.75)) }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pair.element.0)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text(pair.element.2)
                            .font(.system(size: 11.5, weight: .regular))
                            .foregroundStyle(TWColor.ink3)
                    }

                    Spacer(minLength: 0)

                    Text(pair.element.1)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TWColor.amber)
            Text("每组的最后两次要到「再做一个就做不动」的程度，太轻只能练耐力。")
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(TWColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .twGlass(radius: 16, shadow: false)
    }

    private var sessionItems: [(String, String, String)] {
        [
            ("杠铃平板卧推", "65kg × 8", "肩胛收紧，别让杠弹胸"),
            ("哑铃上斜卧推", "22kg × 10", "凳角 30°，控制下放 2 秒"),
            ("哑铃肩上推举", "16kg × 10", "核心收紧，别塌腰"),
            ("窄距俯卧撑", "自重 × 15", "肘贴身体，别外张")
        ]
    }
}

import SwiftUI
import UIKit

struct SleepSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tracker = SleepTracker()

    @State private var newLog: SleepLog?
    @State private var confirmCancel = false

    var body: some View {
        ZStack {
            AuroraBG()

            if tracker.recording {
                recordingView
            } else if let log = newLog {
                reportView(log, fresh: true)
            } else {
                idleView
            }
        }
        .confirmationDialog("放弃这次记录？", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("放弃", role: .destructive) { tracker.cancel() }
            Button("继续记录", role: .cancel) {}
        } message: {
            Text("已经记了 \(Int(tracker.elapsed / 60)) 分钟，放弃后这一段不会保存。")
        }
        .onDisappear {
            if tracker.recording { tracker.cancel() }
        }
    }

    // MARK: - 待机

    private var idleView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                header

                if let last = store.lastSleep {
                    lastCard(last)
                }

                startCard

                if store.sleepLogs.count > 1 {
                    historyCard
                }

                explainCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 34)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("睡眠")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                Text("用手机加速度计做体动记录，不靠手表、不靠健康权限")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 33, height: 33)
                    .background {
                        Circle().fill(Color.white.opacity(0.5))
                            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.8))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    private func lastCard(_ log: SleepLog) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text("上一晚")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text(log.date)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
            }

            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text("\(log.score)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(log.score))
                    Text(log.scoreLabel)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
                .frame(width: 92)

                VStack(alignment: .leading, spacing: 8) {
                    stageBar(log, height: 12)
                    legendRow(log)
                }
            }

            reportView(log, fresh: false, embedded: true)
        }
        .padding(16)
        .twGlass()
    }

    private var startCard: some View {
        VStack(spacing: 13) {
            VStack(spacing: 8) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                    .frame(width: 64, height: 64)
                    .background {
                        Circle().fill(TWColor.purple.opacity(0.10))
                    }

                Text("睡前点一下，整夜记体动")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Text("把手机放在枕头边或床头柜，插上充电器。锁屏也能继续记，第二天点结束就出报告。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                newLog = nil
                tracker.start()
            } label: {
                Text("开始记录睡眠")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .leading, endPoint: .trailing))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 记录中

    private var recordingView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("正在记录")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.purple)
                Spacer()
                Button("放弃") { confirmCancel = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)

            Spacer()

            VStack(spacing: 18) {
                Text(timeText(tracker.elapsed))
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()

                Text("已记 \(tracker.epochCount) 段（每 30 秒一段）")
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.ink3)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TWColor.pink)
                        Text("当前体动")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TWColor.ink3)
                        Spacer()
                        Text("\(Int(tracker.liveAct))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(TWColor.ink2)
                            .monospacedDigit()
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.55))
                            Capsule()
                                .fill(LinearGradient(colors: [TWColor.mint, TWColor.amber, TWColor.coral],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(6, geo.size.width * CGFloat(tracker.liveAct / 100)))
                        }
                    }
                    .frame(height: 9)
                }
                .padding(14)
                .twGlass(radius: 16, shadow: false)

                Text("现在可以锁屏睡觉了。别把 App 划掉，也别关后台刷新。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 22)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                if let r = tracker.stop() {
                    store.addSleep(start: r.start, end: r.end, acts: r.acts)
                    newLog = store.lastSleep
                }
            } label: {
                Text("结束并生成报告")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .leading, endPoint: .trailing))
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    // MARK: - 报告

    private func reportView(_ log: SleepLog, fresh: Bool, embedded: Bool = false) -> some View {
        Group {
            if embedded {
                reportBody(log, fresh: fresh, embedded: embedded)
            } else {
                reportBody(log, fresh: fresh, embedded: embedded)
                    .padding(16)
                    .twGlass(radius: 22)
            }
        }
    }

    private func reportBody(_ log: SleepLog, fresh: Bool, embedded: Bool) -> some View {
        VStack(spacing: 14) {
            if !embedded {
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text("\(log.score)")
                            .font(.system(size: 52, weight: .heavy, design: .rounded))
                            .foregroundStyle(scoreColor(log.score))
                        Text(log.scoreLabel)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink3)
                    }
                    .frame(width: 110)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("睡了 \(log.durationText)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(TWColor.ink)
                        Text("\(log.startText) 入睡 · \(log.endText) 起床")
                            .font(.system(size: 12))
                            .foregroundStyle(TWColor.ink3)
                        stageBar(log, height: 12)
                        legendRow(log)
                    }
                }

                VStack(spacing: 9) {
                    HStack {
                        Text("体动曲线")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(TWColor.ink2)
                        Spacer()
                        Text("越高越可能醒着")
                            .font(.system(size: 10.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    actChart(log)
                }
            }

            VStack(spacing: 8) {
                statRow("深睡", "\(log.deepMinutes) 分", TWColor.purple)
                statRow("浅睡", "\(log.lightMinutes) 分", TWColor.blue)
                statRow("清醒", "\(log.awakeMinutes) 分", TWColor.amber)
            }

            if !embedded {
                adviceCard(log)
            }

            if fresh {
                Text("报告全部来自这次的真实体动数据，没有补任何默认值。\n体动法能判断「睡稳没睡稳」和大概的深浅，跟医院的多导睡眠图不是一回事。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2.5)

                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(TWColor.purple.opacity(0.11))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statRow(_ title: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 9) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
        }
    }

    // MARK: - 补觉建议

    private func adviceCard(_ log: SleepLog) -> some View {
        let debt = store.sleepDebt
        let tonight = store.sleepTonightMin
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("今晚补多少")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("目标 \(store.sleepGoalMin / 60) 小时 \(store.sleepGoalMin % 60) 分")
                    .font(.system(size: 10.5))
                    .foregroundStyle(TWColor.ink3)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(tonight / 60) 小时 \(tonight % 60) 分")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
                Text("建议今晚")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                adviceCell("昨晚缺口", "\(log.durationMinutes < store.sleepGoalMin ? store.sleepGoalMin - log.durationMinutes : 0) 分")
                Rectangle().fill(TWColor.ink3.opacity(0.2)).frame(width: 1, height: 22)
                adviceCell("近 7 天欠", "\(debt) 分")
                Rectangle().fill(TWColor.ink3.opacity(0.2)).frame(width: 1, height: 22)
                adviceCell("建议入睡", store.sleepBedtimeText)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(store.sleepAdviceTitle)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(TWColor.purple)
                Text(store.sleepAdviceBody)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink2)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TWColor.purple.opacity(0.07))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.45))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.65), lineWidth: 0.8)
                }
        }
    }

    private func adviceCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private func stageBar(_ log: SleepLog, height: CGFloat) -> some View {
        let codes = log.stageCodes
        let segs = mergedSegments(codes)
        let total = max(1, codes.count)
        return GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(segs) { seg in
                    Rectangle()
                        .fill(stageColor(seg.kind))
                        .frame(width: max(1, geo.size.width * CGFloat(seg.len) / CGFloat(total) - 1))
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .background {
            Capsule().fill(Color.white.opacity(0.35))
        }
    }

    private func legendRow(_ log: SleepLog) -> some View {
        HStack(spacing: 12) {
            legendDot("深 \(log.deepMinutes)分", TWColor.purple)
            legendDot("浅 \(log.lightMinutes)分", TWColor.blue)
            legendDot("醒 \(log.awakeMinutes)分", TWColor.amber)
        }
    }

    private func legendDot(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
        }
    }

    private func actChart(_ log: SleepLog) -> some View {
        Canvas { ctx, size in
            let n = log.acts.count
            guard n > 1 else { return }
            let step = max(1, n / 140)
            var path = Path()
            var idx = 0
            for i in stride(from: 0, to: n, by: step) {
                let x = size.width * CGFloat(i) / CGFloat(n - 1)
                let y = size.height * (1 - CGFloat(min(1, log.acts[i] / 100)))
                if idx == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
                idx += 1
            }
            ctx.stroke(path, with: .color(TWColor.pink.opacity(0.75)), lineWidth: 1.4)
        }
        .frame(height: 54)
        .padding(.horizontal, 2)
    }

    // MARK: - 历史 / 说明

    private var historyCard: some View {
        VStack(spacing: 11) {
            HStack {
                Text("最近记录")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text("\(store.sleepLogs.count) 晚")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
            }
            ForEach(store.sleepLogs.prefix(6)) { log in
                HStack(spacing: 10) {
                    Text(log.date.suffix(5))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(TWColor.ink3)
                        .frame(width: 46, alignment: .leading)
                    Text(log.scoreLabel)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                    Spacer()
                    Text("\(log.score)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(scoreColor(log.score))
                        .monospacedDigit()
                    Text(log.durationText)
                        .font(.system(size: 11.5))
                        .foregroundStyle(TWColor.ink3)
                        .frame(width: 74, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private var explainCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("这个监测是怎么做的")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("整夜以 20Hz 采集加速度，每 30 秒归纳成一段体动强度。安静不动的长段判为睡眠，其中连续 20 分钟以上不动的判深睡，频繁翻动的时间算清醒。\n\n这是睡眠医学里的体动记录法（actigraphy），能反映睡眠的连续性和睡眠量，测不出脑电和血氧。想要精确分期得上手表或睡眠带。")
                .font(.system(size: 12.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 工具

    private struct Seg: Identifiable {
        let id = UUID()
        let kind: Int
        let len: Int
    }

    private func mergedSegments(_ codes: [Int]) -> [Seg] {
        guard !codes.isEmpty else { return [] }
        var out: [Seg] = []
        var cur = codes[0]
        var cnt = 1
        for c in codes.dropFirst() {
            if c == cur { cnt += 1 }
            else { out.append(Seg(kind: cur, len: cnt)); cur = c; cnt = 1 }
        }
        out.append(Seg(kind: cur, len: cnt))
        return out
    }

    private func stageColor(_ kind: Int) -> Color {
        switch kind {
        case 0: return TWColor.purple
        case 1: return TWColor.blue
        default: return TWColor.amber
        }
    }

    private func scoreColor(_ s: Int) -> Color {
        switch s {
        case 80...: return TWColor.mint
        case 65..<80: return TWColor.blue
        case 50..<65: return TWColor.amber
        default: return TWColor.coral
        }
    }

    private func timeText(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

import SwiftUI
import Combine
import UIKit

struct FlowPage: View {
    @EnvironmentObject var store: TWStore

    @State private var total: Int = 90
    @State private var remain: Int = 90
    @State private var running: Bool = false
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var planIndex: Int = 0
    @State private var dayIndex: Int = 0
    @State private var doneMoves: Set<String> = []
    @State private var detailSession: SessionLog?

    private var plan: PlanTemplate {
        planTemplates[min(planIndex, planTemplates.count - 1)]
    }

    private var day: PlanDay {
        plan.days[min(dayIndex, plan.days.count - 1)]
    }

    private var progress: Double {
        total > 0 ? Double(remain) / Double(total) : 0
    }

    private var clock: String {
        String(format: "%d:%02d", remain / 60, remain % 60)
    }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "训练", subtitle: "\(plan.name) · \(day.title)")

            planPicker

            if plan.days.count > 1 {
                dayTabs
            }

            sessionBar
            sessionCard
            timerCard
            progressionCard
            historyCard
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
        .sheet(item: $detailSession) { s in
            SessionDetailSheet(session: s)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    // MARK: - 方案选择

    private var planPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(planTemplates.enumerated()), id: \.element.id) { pair in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.22)) {
                            planIndex = pair.offset
                            dayIndex = 0
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.element.name)
                                .font(.system(size: 14, weight: planIndex == pair.offset ? .heavy : .bold))
                                .foregroundStyle(planIndex == pair.offset ? .white : TWColor.ink)
                            Text("\(pair.element.daysPerWeek) 天/周 · \(pair.element.level)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(planIndex == pair.offset ? .white.opacity(0.80) : TWColor.ink3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(planIndex == pair.offset
                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(Color.white.opacity(0.58)))
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 训练日切换

    private var dayTabs: some View {
        HStack(spacing: 7) {
            ForEach(Array(plan.days.enumerated()), id: \.element.id) { pair in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.snappy(duration: 0.2)) { dayIndex = pair.offset }
                } label: {
                    Text(pair.element.title)
                        .font(.system(size: 13.5, weight: dayIndex == pair.offset ? .bold : .medium))
                        .foregroundStyle(dayIndex == pair.offset ? TWColor.purple : TWColor.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(dayIndex == pair.offset ? TWColor.purple.opacity(0.15) : Color.white.opacity(0.42))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 今日动作

    private var sessionBar: some View {
        Group {
            if let start = store.sessionStart {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("训练中")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(TWColor.purple)
                        Text("已 \(store.sessionSets) 组 · \(elapsed(from: start))")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)

                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) { store.addSet() }
                    } label: {
                        Text("记一组")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) {
                            store.endSession(plan: plan.name, day: day.title,
                                             moves: day.items.count,
                                             moveNames: day.items.map { $0.name })
                            doneMoves.removeAll()
                        }
                    } label: {
                        Text("结束")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(TWColor.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.55))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .twGlass(radius: 18)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.snappy(duration: 0.2)) {
                        store.startSession(moves: day.items.map { $0.name })
                        doneMoves.removeAll()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("开始今天的训练")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func elapsed(from start: Date) -> String {
        let s = Int(Date().timeIntervalSince(start))
        return "\(s / 60) 分钟"
    }

    private func toggleDone(_ name: String, key: String) {
        if store.sessionStart == nil {
            store.startSession(moves: day.items.map { $0.name })
        }
        if doneMoves.contains(key) {
            doneMoves.remove(key)
        } else {
            doneMoves.insert(key)
            store.addSet()
        }
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.focus)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(plan.summary)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                GlassPill(text: "\(day.items.count) 个动作", tint: TWColor.blue)
            }

            VStack(spacing: 0) {
                ForEach(Array(day.items.enumerated()), id: \.element.id) { pair in
                    let key = "\(day.title)｜\(pair.element.name)"
                    let done = doneMoves.contains(key)
                    HStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) {
                                toggleDone(pair.element.name, key: key)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(done
                                          ? AnyShapeStyle(TWColor.mint)
                                          : AnyShapeStyle(LinearGradient(colors: [TWColor.purple.opacity(0.85),
                                                                                  TWColor.violet.opacity(0.85)],
                                                                         startPoint: .top, endPoint: .bottom)))
                                    .frame(width: 24, height: 24)
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(pair.offset + 1)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Text(pair.element.name)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(done ? TWColor.ink3 : TWColor.ink)
                            .strikethrough(done, color: TWColor.ink3)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text("\(pair.element.sets) × \(pair.element.reps)")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(done ? TWColor.ink3 : TWColor.purple)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 9)

                    if pair.offset < day.items.count - 1 {
                        Rectangle()
                            .fill(TWColor.ink3.opacity(0.12))
                            .frame(height: 0.7)
                    }
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 组间休息

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
                    size: 176
                )
                .opacity(0.9)

                VStack(spacing: 2) {
                    Text(clock)
                        .font(.system(size: 48, weight: .heavy))
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
                    .padding(.vertical, 13)
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
                        .frame(width: 48)
                        .padding(.vertical, 13)
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
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

    // MARK: - 进阶规则

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录")
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: "\(store.sessions.count) 次", tint: TWColor.mint)
            }

            if store.sessions.isEmpty {
                Text("完成一次训练并点「结束」后，记录会出现在这里。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(store.sessions.prefix(5).enumerated()), id: \.element.id) { pair in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        detailSession = pair.element
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(pair.element.day.isEmpty
                                     ? pair.element.plan
                                     : "\(pair.element.plan) · \(pair.element.day)")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(TWColor.ink)
                                    .lineLimit(1)
                                Text("\(pair.element.sets) 组 · \(pair.element.minutes) 分钟 · \(pair.element.moves) 个动作")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            Spacer(minLength: 4)
                            Text(shortDate(pair.element.date))
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(TWColor.ink3)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(TWColor.ink3.opacity(0.6))
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if pair.offset < min(store.sessions.count, 5) - 1 {
                        Rectangle()
                            .fill(TWColor.ink3.opacity(0.12))
                            .frame(height: 0.7)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private func shortDate(_ raw: String) -> String {
        let p = raw.split(separator: "-")
        return p.count == 3 ? "\(p[1])/\(p[2])" : raw
    }

    // MARK: - 进阶规则

    private var progressionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("怎么加重量")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: plan.cycle, tint: TWColor.mint)
            }
            Text(plan.progression)
                .font(.system(size: 13.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }
}

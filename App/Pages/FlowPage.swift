import SwiftUI
import Combine
import UIKit

struct FlowPage: View {
    @EnvironmentObject var store: TWStore

    @State private var total: Int = 90
    @State private var remain: Int = 90
    @State private var running: Bool = false
    @State private var tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var doneMoves: Set<String> = []
    @State private var restFrom: String = ""
    @State private var summaryEntry: SessionLog?
    @State private var summaryPrev: SessionLog?
    @State private var summaryStreak: Int = 1
    @State private var setWeight: Double = 20
    @State private var setReps: Int = 8
    /// 这组还剩几次余力，0 = 力竭；默认留两次
    @State private var rir: Int = 2
    /// 最近点过的动作，用来知道“记一组”记的是哪个动作
    @State private var activeMove: String = ""
    @State private var restNext: String = ""
    @State private var detailSession: SessionLog?
    @State private var pendingPlan: Int?
    @State private var showSwitchConfirm = false
    @State private var showPlanEditor = false
    @State private var editPlanIndex: Int?
    @State private var showRestSet = false
    /// 本次训练替换过的动作：key 是计划里的原名，value 是实际练的动作。
    /// 只影响这次训练，不动计划模板。
    @State private var swapped: [String: String] = [:]
    @State private var swapTarget: PlanItem?

    /// 这组自己的秒表：组间休息管“歇多久”，它管“这一组做了多久”
    @State private var setRun = false
    @State private var setElapsed = 0
    @State private var tempoOn = TWTempo.isOn
    @State private var weightNote = ""

    private var planIndex: Int {
        min(max(store.planPick, 0), max(store.allPlans.count - 1, 0))
    }

    private var dayIndex: Int {
        min(max(store.dayPick, 0), plan.days.count - 1)
    }

    private var plan: PlanTemplate {
        store.allPlans[planIndex]
    }

    private var day: PlanDay {
        plan.days[dayIndex]
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
            planTools

            if plan.days.count > 1 {
                dayTabs
            }

            tipCard
            sessionBar
            sessionCard
            setCard
            timerCard
            progressionCard
            calendarCard
            historyCard
        }
        .onReceive(tick) { _ in
            tickSet()
            guard running else { return }
            if remain > 0 {
                remain -= 1
            } else {
                running = false
                // 前台自己响（系统不会弹横幅），顺带撤掉还没触发的那条通知
                TWNotify.cancelRest()
                TWRestLive.endAll()
                TWNotify.playRestAlert()
                TWVoice.announceNext(restNext)
            }
        }
        .onAppear {
            // 休息提醒要靠通知权限，第一次进来问一次，之后不再弹
            Task { await TWNotify.requestPermission() }
        }
        .sheet(item: $summaryEntry) { e in
            SessionSummarySheet(entry: e, prev: summaryPrev, streak: summaryStreak)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(item: $detailSession) { s in
            SessionDetailSheet(session: s)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPlanEditor) {
            PlanEditorSheet(editIndex: editPlanIndex)
                .environmentObject(store)
        }
        .sheet(isPresented: $showRestSet) {
            RestSettingSheet()
                .environmentObject(store)
                .presentationDetents([.height(420)])
                .presentationCornerRadius(26)
        }
        .sheet(item: $swapTarget) { item in
            SwapMoveSheet(current: swapped[item.name] ?? item.name) { picked in
                withAnimation(.snappy(duration: 0.2)) {
                    if picked == item.name {
                        swapped[item.name] = nil
                    } else {
                        swapped[item.name] = picked
                    }
                }
                activeMove = picked
                restFrom = ""
                restNext = ""
            }
            .environmentObject(store)
        }
        .confirmationDialog("正在训练，切换方案会清空当前组数？",
                            isPresented: $showSwitchConfirm,
                            titleVisibility: .visible) {
            Button("切换", role: .destructive) {
                if let p = pendingPlan {
                    withAnimation(.snappy(duration: 0.22)) {
                        store.setPlan(p, day: 0)
                        doneMoves.removeAll()
                    }
                }
                pendingPlan = nil
            }
            Button("继续当前训练", role: .cancel) { pendingPlan = nil }
        } message: {
            Text("已经记了 \(store.sessionSets) 组，切过去这些数据不会保留。")
        }
    }

    // MARK: - 方案选择

    private var planTools: some View {
        HStack(spacing: 8) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                editPlanIndex = nil
                showPlanEditor = true
            } label: {
                toolChip("自定义方案", icon: "plus.circle.fill", active: false)
            }
            .buttonStyle(.plain)

            if store.planPick >= planTemplates.count {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    editPlanIndex = store.planPick - planTemplates.count
                    showPlanEditor = true
                } label: {
                    toolChip("编辑当前", icon: "slider.horizontal.3", active: true)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showRestSet = true
            } label: {
                toolChip(store.restOverride == 0 ? "休息 · 跟随" : "休息 \(store.restOverride)s",
                         icon: "timer", active: store.restOverride > 0)
            }
            .buttonStyle(.plain)
        }
    }

    private func toolChip(_ text: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.tw(11, .bold))
            Text(text)
                .font(.tw(11.5, .bold))
        }
        .foregroundStyle(active ? TWColor.purple : TWColor.ink2)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(active ? TWColor.purple.opacity(0.13) : TWColor.glass(0.55))
        }
        .overlay {
            Capsule().stroke(TWColor.glass(0.7), lineWidth: 0.8)
        }
    }

    private var planPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(store.allPlans.enumerated()), id: \.element.id) { pair in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        if store.sessionStart != nil && store.sessionSets > 0 {
                            pendingPlan = pair.offset
                            showSwitchConfirm = true
                        } else {
                            withAnimation(.snappy(duration: 0.22)) {
                                store.setPlan(pair.offset, day: 0)
                                doneMoves.removeAll()
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pair.element.name)
                                .font(.tw(14, planIndex == pair.offset ? .heavy : .bold))
                                .foregroundStyle(planIndex == pair.offset ? .white : TWColor.ink)
                            Text("\(pair.element.daysPerWeek) 天/周 · \(pair.element.level)")
                                .font(.tw(11, .medium))
                                .foregroundStyle(planIndex == pair.offset ? TWColor.glass(0.80) : TWColor.ink3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(planIndex == pair.offset
                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(TWColor.glass(0.58)))
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
                    withAnimation(.snappy(duration: 0.2)) {
                        store.setPlan(planIndex, day: pair.offset)
                        doneMoves.removeAll()
                    }
                } label: {
                    Text(pair.element.title)
                        .font(.tw(13.5, dayIndex == pair.offset ? .bold : .medium))
                        .foregroundStyle(dayIndex == pair.offset ? TWColor.purple : TWColor.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(dayIndex == pair.offset ? TWColor.purple.opacity(0.15) : TWColor.glass(0.42))
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 今日动作

    private var tipCard: some View {
        Group {
            if let tip = store.trainTip {
                Button {
                    jumpTo(group: tip.group)
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "target")
                            .font(.tw(16, .bold))
                            .foregroundStyle(TWColor.mint)
                            .frame(width: 36, height: 36)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(TWColor.mint.opacity(0.12))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.days.map { "距上次练\(tip.group) \($0) 天" } ?? "还没练过\(tip.group)")
                                .font(.tw(14, .bold))
                                .foregroundStyle(TWColor.ink)
                                .lineLimit(1)
                            Text(tip.urgent ? "恢复够了，今天正好安排\(tip.group)" : "\(tip.group)还在恢复，先把别的练完")
                                .font(.tw(11))
                                .foregroundStyle(TWColor.ink3)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        Text("切到这天")
                            .font(.tw(11, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background { Capsule().fill(TWColor.mint) }
                    }
                    .padding(14)
                    .twGlass(radius: 16)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 在当前方案里找 focus 对上这个肌群的那天，直接切过去
    private func jumpTo(group: String) {
        if let i = plan.days.firstIndex(where: {
            $0.focus.contains(group) || $0.title.contains(group)
        }) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.snappy(duration: 0.25)) { store.dayPick = i }
        }
    }

    private var sessionBar: some View {
        Group {
            if let start = store.sessionStart {
                VStack(spacing: 11) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("训练中")
                            .font(.tw(13, .bold))
                            .foregroundStyle(TWColor.purple)
                        Text("已 \(store.sessionSets) 组 · \(elapsed(from: start))" +
                             (store.sessionTonnage > 0 ? " · \(Int(store.sessionTonnage)) kg 总量" : ""))
                            .font(.tw(12.5, .medium))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)

                    Button {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) {
                            store.addSet(weight: setWeight, reps: setReps, move: activeMove, rir: rir)
                        }
                    } label: {
                        Text("记一组")
                            .font(.tw(14, .bold))
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
                            if let e = store.endSession(plan: plan.name, day: day.title,
                                                        moves: day.items.count,
                                                        moveNames: day.items.map { swapped[$0.name] ?? $0.name }) {
                                summaryEntry = e
                                summaryPrev = store.sessions.dropFirst()
                                    .first { $0.plan == e.plan && $0.day == e.day }
                                summaryStreak = max(1, store.trainingStreak)
                            }
                            doneMoves.removeAll()
                            running = false
                            restFrom = ""
                            restNext = ""
                        }
                    } label: {
                        Text("结束")
                            .font(.tw(14, .bold))
                            .foregroundStyle(TWColor.ink2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(TWColor.glass(0.55))
                            }
                    }
                    .buttonStyle(.plain)
                }

                loadRow

                }
                .padding(14)
                .twGlass(radius: 18)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.snappy(duration: 0.2)) {
                        store.startSession(moves: day.items.map { swapped[$0.name] ?? $0.name })
                        doneMoves.removeAll()
                        activeMove = day.items.first.map { swapped[$0.name] ?? $0.name } ?? ""
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "play.circle.fill")
                            .font(.tw(17, .bold))
                        Text("开始今天的训练")
                            .font(.tw(15, .bold))
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

    private func fmtKg(_ v: Double) -> String {
        String(format: v == v.rounded() ? "%.0f" : "%.1f", v)
    }

    /// 把 "8–12" / "10 次" 这类文案里的第一个数字取出来当目标次数
    private func firstInt(_ s: String) -> Int {
        var digits = ""
        for ch in s {
            if ch.isNumber { digits.append(ch) }
            else if !digits.isEmpty { break }
        }
        return Int(digits) ?? 8
    }

    private func elapsed(from start: Date) -> String {
        let s = Int(Date().timeIntervalSince(start))
        return "\(s / 60) 分钟"
    }

    /// 把 PlanItem.rest 的文案解析成秒（"45 秒" / "2 分钟" / "3–5 分钟" → 取区间下限）
    private func restSeconds(_ text: String) -> Int {
        let t = text.replacingOccurrences(of: " ", with: "")
        let isMin = t.contains("分钟")
        let raw = t.replacingOccurrences(of: "分钟", with: "").replacingOccurrences(of: "秒", with: "")
        let head = raw.replacingOccurrences(of: "–", with: "-")
            .split(separator: "-").first.map(String.init) ?? ""
        let v = Double(head) ?? (isMin ? 2 : 45)
        return max(10, Int((isMin ? v * 60 : v).rounded()))
    }

    private func toggleDone(_ name: String, key: String, rest: String, next: String) {
        if store.sessionStart == nil {
            store.startSession(moves: day.items.map { swapped[$0.name] ?? $0.name })
            activeMove = day.items.first.map { swapped[$0.name] ?? $0.name } ?? ""
        }
        if doneMoves.contains(key) {
            doneMoves.remove(key)
        } else {
            doneMoves.insert(key)
            activeMove = name
            // 这组结束，秒表归零，接着走休息倒计时
            setRun = false
            setElapsed = 0
            weightNote = ""
            store.addSet(weight: setWeight, reps: setReps, move: name, rir: rir)
            // 按这个动作自己的 rest 起休息倒计时，不用再手调
            let sec = store.restOverride > 0 ? store.restOverride : restSeconds(rest)
            withAnimation(.snappy(duration: 0.25)) {
                total = sec
                remain = sec
                running = true
                restFrom = name
                restNext = next
            }
            // 就算把手机揣兜里、切出去刷视频，到点也会响
            TWNotify.scheduleRest(after: sec, move: name)
            TWRestLive.start(seconds: sec, move: name, next: next)
            TWVoice.announceRest(sec, move: name)
        }
    }

    private var loadRow: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                loadChip("重量", String(format: "%g", setWeight) + " kg",
                         minus: { setWeight = max(0, setWeight - 2.5) },
                         plus: { setWeight = min(500, setWeight + 2.5) })
                loadChip("次数", "\(setReps) 次",
                         minus: { setReps = max(1, setReps - 1) },
                         plus: { setReps = min(50, setReps + 1) })
            }
            rirRow
        }
    }

    /// 余力次数：记完这组还剩几下的余量，比「次数做满没」更能决定该不该加重量
    private var rirRow: some View {
        HStack(spacing: 7) {
            Text("还能再做")
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
            ForEach([0, 1, 2, 3], id: \.self) { n in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.snappy(duration: 0.15)) { rir = n }
                } label: {
                    Text(n == 3 ? "3+" : "\(n)")
                        .font(.tw(11.5, .bold))
                        .foregroundStyle(rir == n ? .white : TWColor.ink2)
                        .frame(width: 30, height: 24)
                        .background {
                            Capsule().fill(rir == n
                                           ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                          startPoint: .top, endPoint: .bottom))
                                           : AnyShapeStyle(TWColor.glass(0.5)))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("这组还剩 \(n) 次余力")
            }
            Spacer(minLength: 0)
            Text(rir <= 1 ? "已经到头，别再加" : "留有余力")
                .font(.tw(10.5, .medium))
                .foregroundStyle(rir <= 1 ? TWColor.coral : TWColor.ink3)
        }
        .padding(.horizontal, 3)
    }

    private func loadChip(_ title: String, _ value: String,
                          minus: @escaping () -> Void,
                          plus: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                minus()
            } label: {
                Image(systemName: "minus")
                    .font(.tw(10, .heavy))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 22, height: 22)
                    .background { Circle().fill(TWColor.glass(0.6)) }
            }
            .buttonStyle(.plain)
            Text(value)
                .font(.tw(12.5, .bold))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
                .frame(minWidth: 44)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                plus()
            } label: {
                Image(systemName: "plus")
                    .font(.tw(10, .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background { Circle().fill(TWColor.purple.opacity(0.85)) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule().fill(TWColor.glass(0.42))
        }
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(day.focus)
                        .font(.tw(15.5, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(plan.summary)
                        .font(.tw(12, .regular))
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
                    let nm = swapped[pair.element.name] ?? pair.element.name
                    HStack(spacing: 10) {
                        Button {
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) {
                                toggleDone(nm, key: key,
                                           rest: pair.element.rest,
                                           next: pair.offset + 1 < day.items.count ? day.items[pair.offset + 1].name : "")
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
                                        .font(.tw(11, .bold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text("\(pair.offset + 1)")
                                        .font(.tw(12, .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(nm)
                                .font(.tw(14.5, .semibold))
                                .foregroundStyle(done ? TWColor.ink3 : TWColor.ink)
                                .strikethrough(done, color: TWColor.ink3)
                                .lineLimit(1)
                            let lastRecs = store.lastSets(move: nm)
                            if !lastRecs.isEmpty {
                                Text("上次 " + lastRecs.map { "\(fmtKg($0.weight))×\($0.reps)" }.joined(separator: " · "))
                                    .font(.tw(10.5, .medium))
                                    .foregroundStyle(TWColor.ink3)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 4)

                        if !done, let sug = store.suggestFor(move: nm,
                                                             targetReps: firstInt(pair.element.reps)) {
                            Button {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                withAnimation(.snappy(duration: 0.2)) {
                                    setWeight = sug.kg
                                    setReps = sug.reps
                                    activeMove = nm
                                    weightNote = sug.note
                                }
                            } label: {
                                Text("建议 \(fmtKg(sug.kg))kg × \(sug.reps)")
                                    .font(.tw(10.5, .bold))
                                    .foregroundStyle(TWColor.mint)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background {
                                        Capsule().fill(TWColor.mint.opacity(0.14))
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            swapTarget = pair.element
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.tw(9, .bold))
                                Text(swapped[pair.element.name] == nil ? "换" : "已换")
                                    .font(.tw(9.5, .bold))
                            }
                            .foregroundStyle(swapped[pair.element.name] == nil ? TWColor.ink3 : TWColor.mint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background { Capsule().fill(TWColor.ink3.opacity(0.09)) }
                        }
                        .buttonStyle(.plain)

                        Text("\(pair.element.sets) × \(pair.element.reps)")
                            .font(.tw(12.5, .bold))
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

    // MARK: - 这组计时

    /// 一组大约 4 秒一次（下放 3 秒、推起 1 秒），按次数估个目标时长
    private var setTarget: Int { max(12, setReps * 4) }

    private var setClock: String {
        String(format: "%d:%02d", setElapsed / 60, setElapsed % 60)
    }

    /// 3 秒下放、1 秒停、2 秒推起
    private var tempoPhaseText: String {
        let m = setElapsed % 6
        switch m {
        case 0, 1, 2: return "下放 \(3 - m) 秒"
        case 3:       return "停 1 秒"
        default:      return "推起 \(6 - m) 秒"
        }
    }

    private func tickSet() {
        guard setRun else { return }
        setElapsed += 1
        if tempoOn {
            // 6 秒一个循环：0-2 下放（低音），3 停（不响），4-5 推起（高音）
            let m = setElapsed % 6
            if m != 3 { TWTempo.beat(hi: m >= 4) }
        }
        if setElapsed == setTarget {
            setRun = false
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            TWVoice.speak("这组到点了，\(setReps) 次做完就可以记一组")
        }
    }

    private var setCard: some View {
        VStack(spacing: 13) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(activeMove.isEmpty ? "这组计时" : "\(activeMove) · 这组")
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .lineLimit(1)
                    Text(setElapsed >= setTarget
                         ? "超时 \(setElapsed - setTarget) 秒 · 该收了"
                         : "目标 \(setTarget) 秒 · 按 \(setReps) 次估")
                        .font(.tw(11.5, .regular))
                        .foregroundStyle(setElapsed >= setTarget ? TWColor.amber : TWColor.ink3)
                    if !weightNote.isEmpty {
                        Text(weightNote)
                            .font(.tw(10.5, .regular))
                            .foregroundStyle(TWColor.mint)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    tempoOn.toggle()
                    TWTempo.isOn = tempoOn
                } label: {
                    Image(systemName: tempoOn ? "waveform" : "waveform.slash")
                        .font(.tw(13, .bold))
                        .foregroundStyle(tempoOn ? TWColor.blue : TWColor.ink3)
                        .frame(width: 30, height: 30)
                        .background {
                            Circle().fill(tempoOn ? TWColor.blue.opacity(0.13) : TWColor.ink3.opacity(0.08))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tempoOn ? "关掉节拍器" : "打开节拍器")
                GlassPill(text: setRun ? "计时中" : (setElapsed >= setTarget ? "到点" : (setElapsed > 0 ? "已 \(setElapsed) 秒" : "待开始")),
                          tint: setRun ? TWColor.mint : (setElapsed >= setTarget ? TWColor.amber : TWColor.ink3))
            }

            HStack(spacing: 14) {
                Text(setClock)
                    .font(.tw(32, .heavy))
                    .foregroundStyle(setElapsed >= setTarget ? TWColor.amber : TWColor.ink)
                    .monospacedDigit()
                    .frame(width: 92, alignment: .leading)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TWColor.ink3.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: setElapsed >= setTarget
                                                 ? [TWColor.amber, TWColor.coral]
                                                 : [TWColor.mint, TWColor.blue],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(1, Double(setElapsed) / Double(setTarget)))
                    }
                }
                .frame(height: 7)
            }

            if tempoOn && setRun {
                Text(tempoPhaseText)
                    .font(.tw(11.5, .bold))
                    .foregroundStyle(TWColor.blue)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if setElapsed >= setTarget { setElapsed = 0 }
                    withAnimation(.snappy) { setRun.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: setRun ? "pause.fill" : "play.fill")
                            .font(.tw(13, .bold))
                        Text(setRun ? "暂停" : (setElapsed > 0 ? "继续" : "开始这组"))
                            .font(.tw(15, .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.mint, TWColor.blue],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy) {
                        setRun = false
                        setElapsed = 0
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.tw(14, .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 46, height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(TWColor.ink3.opacity(0.09))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("这组计时归零")
            }
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 组间休息

    private var timerCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(restFrom.isEmpty ? "组间休息" : "\(restFrom) 之后的休息")
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink2)
                    if !restNext.isEmpty {
                        Text("下一个：\(restNext)")
                            .font(.tw(11.5, .regular))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
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
                        .font(.tw(48, .heavy))
                        .foregroundStyle(TWColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                    Text("剩余")
                        .font(.tw(12, .semibold))
                        .tracking(2)
                        .foregroundStyle(TWColor.ink3)
                }
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if remain == 0 { remain = total }
                    withAnimation(.snappy) { running.toggle() }
                    // 暂停就撤通知，继续就按剩余秒数重约一条
                    if running {
                        TWNotify.scheduleRest(after: remain, move: restFrom)
                        TWRestLive.start(seconds: remain, move: restFrom, next: restNext)
                    } else {
                        TWNotify.cancelRest()
                        TWRestLive.endAll()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: running ? "pause.fill" : "play.fill")
                            .font(.tw(14, .bold))
                        Text(running ? "暂停" : (remain == 0 ? (restNext.isEmpty ? "再来一组" : "开始下一组") : "继续"))
                            .font(.tw(15, .bold))
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
                    TWNotify.cancelRest()
                    withAnimation(.snappy) {
                        running = false
                        remain = total
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 48)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(TWColor.glass(0.55))
                        }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach([60, 90, 120, 180], id: \.self) { s in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        TWNotify.cancelRest()
                        withAnimation(.snappy) {
                            total = s
                            remain = s
                            running = false
                        }
                    } label: {
                        Text("\(s)s")
                            .font(.tw(13, total == s ? .bold : .medium))
                            .foregroundStyle(total == s ? TWColor.purple : TWColor.ink3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(total == s ? TWColor.purple.opacity(0.14) : TWColor.glass(0.4))
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

    // MARK: - 最近 7 天

    private func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private func dayBefore(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: Date()) ?? Date()
    }

    private func hasTraining(_ d: Date) -> Bool {
        let key = dayKey(d)
        return store.sessions.contains { $0.date == key }
    }

    private var calendarCard: some View {
        let days: [Date] = (0..<7).map { dayBefore(6 - $0) }
        let count = days.filter { hasTraining($0) }.count
        let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近 7 天")
                    .font(.tw(15.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: "练了 \(count) 天", tint: count > 0 ? TWColor.mint : TWColor.ink3)
            }

            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { i in
                    let d = days[i]
                    let done = hasTraining(d)
                    let wd = Calendar.current.component(.weekday, from: d) - 1
                    VStack(spacing: 5) {
                        Text(weekdayNames[max(0, min(wd, 6))])
                            .font(.tw(10.5, .medium))
                            .foregroundStyle(TWColor.ink3)
                        ZStack {
                            Circle()
                                .fill(done
                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                     startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(TWColor.glass(0.40)))
                                .frame(width: 32, height: 32)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.tw(13, .bold))
                                    .foregroundStyle(.white)
                            } else {
                                Circle()
                                    .fill(TWColor.ink3.opacity(0.35))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        Text("\(Calendar.current.component(.day, from: d))")
                            .font(.tw(10, .semibold))
                            .foregroundStyle(TWColor.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 进阶规则

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录")
                    .font(.tw(15.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: "\(store.sessions.count) 次", tint: TWColor.mint)
            }

            if store.sessions.isEmpty {
                Text("完成一次训练并点「结束」后，记录会出现在这里。")
                    .font(.tw(12.5))
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
                                    .font(.tw(13.5, .semibold))
                                    .foregroundStyle(TWColor.ink)
                                    .lineLimit(1)
                                Text("\(pair.element.sets) 组 · \(pair.element.minutes) 分钟 · \(pair.element.moves) 个动作")
                                    .font(.tw(11.5))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            Spacer(minLength: 4)
                            Text(shortDate(pair.element.date))
                                .font(.tw(11.5, .semibold))
                                .foregroundStyle(TWColor.ink3)
                            Image(systemName: "chevron.right")
                                .font(.tw(10, .bold))
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
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("怎么加重量")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: plan.cycle, tint: TWColor.mint)
            }
            Text(plan.progression)
                .font(.tw(13.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }
}

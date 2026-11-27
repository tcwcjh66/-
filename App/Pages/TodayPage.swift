import SwiftUI
import UIKit

struct TodayPage: View {
    @EnvironmentObject var store: TWStore
    @EnvironmentObject var live: TWLive
    @State private var appeared = false
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var showWaterLog = false
    @State private var showRingInfo = false
    var onOpenFlow: () -> Void = {}

    private var dateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 10)
            if let issue = store.saveIssue {
                saveBanner(issue)
                    .padding(.bottom, 10)
            }
            VStack(spacing: 0) {
                heroDial
                ringsCard
                recoveryBar
                if firstRun { firstRunCard }
                hairline
                todayTrainCard
                weekGridCard
                hairline
                statsRow
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                hairline
                waterQuick
                hairline
                trendCard
                hairline
                tipCard
                hairline
                moodRow
            }
            .twGlass(radius: 26)
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
        .sheet(isPresented: $showSearch) {
            GlobalSearchSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWaterLog) {
            WaterLogSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showRingInfo) {
            RingInfoSheet()
                .environmentObject(store)
                .presentationDetents([.height(460), .large])
                .presentationCornerRadius(26)
        }
    }

    /// 自动备份失败时的一条细横幅，点叉能关掉，不挡内容
    private func saveBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.tw(11, .bold))
                .foregroundStyle(TWColor.amber)
            Text(text)
                .font(.tw(11))
                .foregroundStyle(TWColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { store.saveIssue = nil } label: {
                Image(systemName: "xmark")
                    .font(.tw(10, .bold))
                    .foregroundStyle(TWColor.ink3)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .twGlass(radius: 14)
    }

    /// 今天一条数据都没有：新装第一天，或者刚清空过
    private var firstRun: Bool {
        store.stepsForDisplay == 0 && store.meals.isEmpty && store.sessions.isEmpty
    }

    private var firstRunCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("第一天，从这三件开始")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            hintLine("1", "定个目标", "「我的」→ 填体重和目标，四环才有分母", TWColor.purple)
            hintLine("2", "拍第一餐", "「饮食」→ 拍包装或搜食物，热量自动算", TWColor.mint)
            hintLine("3", "练第一次", "选个方案点「开始今天的训练」，记下来的组会进曲线", TWColor.blue)

            Text("想测心率就「身体」→ 指尖轻压后置镜头，20 秒出数。不测也能用。")
                .font(.tw(10))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenFlow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle.fill")
                        .font(.tw(14, .bold))
                    Text("去训练")
                        .font(.tw(13.5, .bold))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private func hintLine(_ n: String, _ title: String, _ detail: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(n)
                .font(.tw(10, .bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
                .background { Circle().fill(tint.opacity(0.14)) }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink)
                Text(detail)
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateText)
                    .font(.tw(13, .semibold))
                    .tracking(1.2)
                    .foregroundStyle(TWColor.ink3)
                TwGradientText(text: "今天", size: 31)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 38, height: 38)
                        .twGlass(radius: 19)
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                    .font(.tw(16, .semibold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 38, height: 38)
                    .twGlass(radius: 19)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 段与段之间的细线：整页是一张卡，靠线分层而不是靠留白分块
    private var hairline: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.10))
            .frame(height: 0.6)
            .padding(.horizontal, 14)
    }

    private var heroDial: some View {
        GeometryReader { geo in
            let isSleep = store.avatarAsset.hasSuffix("sleep")
            let h: CGFloat = isSleep ? 252 : 322
            // 两边各留 12pt，别让它贴着卡片边；横版按宽度换算出来的高度正好落在 h 里
            let w = max(180, geo.size.width - 24)
            ZStack {
                LivingAvatar(asset: store.avatarAsset, mood: store.mood,
                             hour: Calendar.current.component(.hour, from: Date()),
                             boxWidth: w,
                             boxHeight: h)
                    .id(store.avatarAsset)
                    .transition(.opacity)
            }
            .frame(width: geo.size.width, height: h)
        }
        .frame(height: store.avatarAsset.hasSuffix("sleep") ? 252 : 322)
        .animation(.easeInOut(duration: 0.42), value: store.avatarAsset)
    }

    /// 只有 HRV / 睡眠 / 训练记录里至少有一项时才出现，不编分数
    private var recoveryBar: some View {
        Group {
            if let r = TWRecovery.today(store) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(r.tint.opacity(0.16))
                            .frame(width: 34, height: 34)
                        Text("\(r.value)")
                            .font(.tw(13, .heavy))
                            .foregroundStyle(r.tint)
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("恢复度 · \(r.advice)")
                            .font(.tw(12.5, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text(r.reasons.prefix(2).joined(separator: "，"))
                            .font(.tw(10))
                            .foregroundStyle(TWColor.ink3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("恢复度 \(r.value)，\(r.advice)")
            }
        }
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
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showRingInfo = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("四环：活动 \(Int(store.moveKcal)) 千卡，目标 \(Int(store.moveTarget)) 千卡；锻炼 \(Int(store.exerciseMin)) 分钟，目标 \(Int(store.exerciseTarget)) 分钟；站立 \(Int(store.standHours)) 小时，目标 \(Int(store.standTarget)) 小时；HRV \(store.hrv) 毫秒")
        .accessibilityHint("轻点查看每一项怎么算出来的")
    }

    private func ringRow(color: Color, label: String, value: String, unit: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.5), radius: 3)
            Text(label)
                .font(.tw(13.5, .semibold))
                .foregroundStyle(TWColor.ink2)
            Text(value)
                .font(.tw(16, .heavy))
                .foregroundStyle(TWColor.ink)
            Text(unit)
                .font(.tw(12, .medium))
                .foregroundStyle(TWColor.ink3)
        }
    }

    /// 本周七天摆出来：练过的打勾，今天描一圈。
    /// 「这周练了几次、还差几次」是训练计划最需要的反馈，之前只能自己数。
    private var weekGridCard: some View {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let offset = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -offset,
                              to: cal.startOfDay(for: today)) ?? today
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
        let doneDays = Set(store.sessions.map { $0.date })
        let done = days.filter { doneDays.contains(DateFormatter.twDay.string(from: $0)) }.count
        let goal = max(1, store.weeklyGoal)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("本周训练")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: done >= goal ? "达标 \(done)/\(goal)" : "\(done)/\(goal) 次",
                          tint: done >= goal ? TWColor.mint : TWColor.amber)
            }

            HStack(spacing: 7) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    let key = DateFormatter.twDay.string(from: d)
                    let has = doneDays.contains(key)
                    let isToday = cal.isDateInToday(d)
                    VStack(spacing: 6) {
                        Text(["一", "二", "三", "四", "五", "六", "日"][i])
                            .font(.tw(10, isToday ? .bold : .semibold))
                            .foregroundStyle(isToday ? TWColor.ink : TWColor.ink3)
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(has ? TWColor.mint.opacity(0.82) : TWColor.glass(0.38))
                                .frame(height: 40)
                            if has {
                                Image(systemName: "checkmark")
                                    .font(.tw(13, .bold))
                                    .foregroundStyle(.white)
                            } else if isToday {
                                Circle()
                                    .strokeBorder(TWColor.mint.opacity(0.55), lineWidth: 1.5)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(TWColor.mint.opacity(0.75), lineWidth: 1.4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(done >= goal
                 ? "本周已经达标，剩下的当加练。"
                 : "还差 \(goal - done) 次，排一天 40 分钟就能补上。")
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(14)
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
    }

    private func statCard(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.tw(12, .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.ink3)
            }
            Text(value)
                .font(.tw(22, .heavy))
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
                    .font(.tw(14.5, .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: "本周 \(weekCount) 次", tint: TWColor.mint)
            }

            // 本周七天，练了打勾、今天描紫边
            HStack(spacing: 4) {
                ForEach(Array(weekCells.enumerated()), id: \.offset) { pair in
                    weekPill(pair.element)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if pair.element.isToday { onOpenFlow() }
                        }
                }
            }

            Text(todayPlanLine)
                .font(.tw(11.5, .regular))
                .foregroundStyle(TWColor.ink3)

            if store.sessionStart != nil {
                HStack(spacing: 8) {
                    Circle()
                        .fill(TWColor.purple)
                        .frame(width: 7, height: 7)
                    Text("正在练：\(store.sessionMoves.first ?? "")\(store.sessionMoves.count > 1 ? " 等" : "")")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("已 \(store.sessionSets) 组")
                        .font(.tw(12, .bold))
                        .foregroundStyle(TWColor.purple)
                }
            } else if let hint = store.nextDayHint {
                HStack(spacing: 8) {
                    Text(hint.day)
                        .font(.tw(20, .heavy))
                        .foregroundStyle(TWColor.ink)
                    Text(hint.plan)
                        .font(.tw(12, .medium))
                        .foregroundStyle(TWColor.ink3)
                    Spacer(minLength: 0)
                    if let last = store.sessions.first {
                        Text("上次 \(shortDay(last.date))")
                            .font(.tw(11.5, .semibold))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
            } else {
                Text("还没有训练记录。挑一套方案，从今天开始。")
                    .font(.tw(13))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenFlow()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.tw(13, .bold))
                    Text(store.sessionStart != nil ? "回到训练" : "去训练")
                        .font(.tw(14.5, .bold))
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
    }

    // MARK: - 本周七天

    private var weekCells: [TodayWeekCell] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let wd = cal.component(.weekday, from: today)   // 1 = 周日
        let back = (wd + 5) % 7                          // 周一为一周第一天
        let monday = cal.date(byAdding: .day, value: -back, to: today) ?? today
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        var out: [TodayWeekCell] = []
        for i in 0..<7 {
            let d = cal.date(byAdding: .day, value: i, to: monday) ?? monday
            let key = f.string(from: d)
            out.append(TodayWeekCell(label: labels[i],
                                     day: cal.component(.day, from: d),
                                     trained: store.sessions.contains { $0.date == key },
                                     isToday: cal.isDateInToday(d)))
        }
        return out
    }

    private var todayPlanLine: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: Date())
        if let s = store.sessions.first(where: { $0.date == key }) {
            return "今天练过了：\(s.day) · \(s.sets) 组"
        }
        if store.sessionStart != nil {
            return "正在练：\(store.sessionMoves.first ?? "")"
        }
        if let hint = store.nextDayHint {
            return "今天该练：\(hint.day)（\(hint.plan)）"
        }
        return "本周目标 3 次，练一次就点亮一格"
    }

    private func weekPill(_ c: TodayWeekCell) -> some View {
        VStack(spacing: 3) {
            Text(c.label)
                .font(.tw(10, .semibold))
                .foregroundStyle(c.isToday ? TWColor.purple : TWColor.ink3)
            ZStack {
                Circle()
                    .fill(c.trained ? TWColor.mint : TWColor.ink3.opacity(0.08))
                    .frame(width: 30, height: 30)
                if c.isToday {
                    Circle()
                        .strokeBorder(TWColor.purple, lineWidth: 1.6)
                        .frame(width: 30, height: 30)
                }
                if c.trained {
                    Image(systemName: "checkmark")
                        .font(.tw(11, .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(c.day)")
                        .font(.tw(11, c.isToday ? .heavy : .medium))
                        .foregroundStyle(c.isToday ? TWColor.purple : TWColor.ink3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(c.label + " 周" + (c.trained ? "已训练" : "未训练"))
    }

    private func shortDay(_ raw: String) -> String {
        let p = raw.split(separator: "-")
        return p.count == 3 ? "\(p[1])/\(p[2])" : raw
    }

    private var waterQuick: some View {
        HStack(spacing: 11) {
            Image(systemName: "drop.fill")
                .font(.tw(13, .semibold))
                .foregroundStyle(TWColor.blue)
                .frame(width: 30, height: 30)
                .background { Circle().fill(TWColor.blue.opacity(0.12)) }

            VStack(alignment: .leading, spacing: 2) {
                Text("饮水")
                    .font(.tw(11, .semibold))
                    .foregroundStyle(TWColor.ink3)
                Text("\(store.waterML) ml / \(store.waterTargetML) ml")
                    .font(.tw(13.5, .bold))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showWaterLog = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.tw(13, .semibold))
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
                    .font(.tw(13, .bold))
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
                .font(.tw(14, .semibold))
                .foregroundStyle(tip.3)
                .frame(width: 30, height: 30)
                .background {
                    Circle().fill(tip.3.opacity(0.14))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.0)
                    .font(.tw(13.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Text(tip.1)
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天感觉怎么样")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text(moodLabel)
                    .font(.tw(13, .semibold))
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
                    .font(.tw(23))
                Text(option.name)
                    .font(.tw(11, .medium))
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

/// 点四环弹出来：每个数从哪来，说清楚，不做模糊表述。
struct RingInfoSheet: View {
    @EnvironmentObject var store: TWStore
    @EnvironmentObject var live: TWLive
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 9)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("这四个环怎么算的")
                            .font(.tw(20, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Text("每个数都能追到来源，没有一项是编的")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.tw(12, .bold))
                            .foregroundStyle(TWColor.ink2)
                            .frame(width: 32, height: 32)
                            .background { Circle().fill(TWColor.glass(0.55)) }
                    }
                    .buttonStyle(.plain)
                }

                infoRow(tint: TWColor.purple, title: "活动",
                        value: "\(Int(store.moveKcal)) / \(Int(store.moveTarget)) kcal",
                        detail: "吃进去的每 1000 kcal 记 60 的活动；每记一组训练再加 22 kcal。")
                infoRow(tint: TWColor.pink, title: "锻炼",
                        value: "\(Int(store.exerciseMin)) / \(Int(store.exerciseTarget)) 分钟",
                        detail: "每记一组约 2.5 分钟；手表回传的锻炼分钟也会并进来。")
                infoRow(tint: TWColor.mint, title: "站立",
                        value: "\(Int(store.standHours)) / \(Int(store.standTarget)) 小时",
                        detail: "每记一组加 0.15 小时；主体来自手表回传的站立小时，iPhone 自己测不了。")
                infoRow(tint: TWColor.amber, title: "HRV",
                        value: "\(store.hrv) ms",
                        detail: "指尖测量或快捷指令回传的最新值，不会拿心率去推。")

                Text("环没满只是还没到目标。某项是 0 就代表今天确实没这个数据，这里不做估算。")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func infoRow(tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(title)
                        .font(.tw(13.5, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(value)
                        .font(.tw(12))
                        .foregroundStyle(TWColor.ink2)
                        .monospacedDigit()
                }
                Text(detail)
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.46))
        }
    }
}

struct TodayWeekCell {
    let label: String
    let day: Int
    let trained: Bool
    let isToday: Bool
}

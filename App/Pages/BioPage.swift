import SwiftUI
import UIKit
import CoreMotion

struct BioPage: View {
    @EnvironmentObject var store: TWStore
    @EnvironmentObject var live: TWLive

    @State private var showPulse = false
    @State private var showManual = false
    @State private var manualText = ""
    @State private var motionStatus: String = "未查询"

    @State private var showBody = false
    @State private var wText = ""
    @State private var hText = ""
    @State private var waistText = ""
    @State private var goalText = ""
    @State private var chestText = ""
    @State private var armText = ""
    @State private var thighText = ""
    @State private var hipText = ""
    @State private var girthPick = 0
    @State private var showSleep = false
    @State private var showWatch = false
    @State private var showWater = false
    @State private var showWaterLog = false
    @State private var showWeekly = false
    @State private var showAch = false
    @State private var showProgress = false
    @State private var showBackfill = false


    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "身体", subtitle: "本机实测 · 不含模拟数据")

            weeklyCard
            heatmapCard
            hrCard
            watchSyncCard
            spo2Card
            stepCard
            sleepCard
            sleepTrainCard
            groupVolumeCard
            bodyCard
            weightTrendCard

            trainingStatsCard
            progressCard
            girthCard
            girthCompareCard
            achievementCard
            waterCard
            sourceCard
        }
        .sheet(isPresented: $showBackfill) {
            BackfillSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showProgress) {
            ProgressPhotoSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showPulse) {
            PulseView { bpm, hrv in
                store.measuredHR = bpm
                store.measuredHRV = hrv
                store.measuredAt = Date()
                store.hrSource = "指尖 PPG"
                store.hr = bpm
                store.hrv = hrv
                PhoneLink.shared.pushToWatch()
            }
        }
        .sheet(isPresented: $showManual) {
            ManualHeartSheet(text: $manualText) { bpm in
                store.measuredHR = bpm
                store.measuredAt = Date()
                store.hrSource = "手动录入"
                store.hr = bpm
                PhoneLink.shared.pushToWatch()
            }
            .presentationDetents([.height(320)])
            .presentationCornerRadius(26)
        }
        .onAppear { loadSteps() }
        .onReceive(NotificationCenter.default.publisher(for: .twDeepLink)) { note in
            if (note.object as? String) == "bio:weight" { showBody = true }
        }
        .sheet(isPresented: $showBody) {
            BodySheet(w: $wText, h: $hText, waist: $waistText, goal: $goalText,
                      chest: $chestText, arm: $armText, thigh: $thighText, hip: $hipText) {
                kg, height, waist, goal, chest, arm, thigh, hip in
                if height > 0 { store.heightCM = height }
                if waist > 0 { store.waistCM = waist }
                if chest > 0 { store.chestCM = chest }
                if arm > 0 { store.armCM = arm }
                if thigh > 0 { store.thighCM = thigh }
                if hip > 0 { store.hipCM = hip }
                if goal > 0 { store.weightGoal = goal }
                if kg > 0 { store.logWeight(kg) }
                store.logGirth()
                store.persist()
            }
            .presentationDetents([.large])
            .presentationCornerRadius(26)
        }
        .sheet(isPresented: $showSleep) {
            SleepSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(26)
        }
        .sheet(isPresented: $showWatch) {
            WatchSyncSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(26)
        }
        .sheet(isPresented: $showAch) {
            AchievementsSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWaterLog) {
            WaterLogSheet()
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWeekly) {
            WeeklyReportPage()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showWater) {
            WaterSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(26)
        }
    }

    // MARK: - 身体数据

    private var bmiText: String {
        let b = store.bmi
        guard b > 0 else { return "先填身高" }
        let label: String
        switch b {
        case ..<18.5: label = "偏瘦"
        case ..<24:   label = "正常"
        case ..<28:   label = "偏高"
        default:      label = "肥胖"
        }
        return String(format: "BMI %.1f · %@", b, label)
    }

    private var weightPoints: [Double] {
        Array(store.weightLogs.suffix(7)).map { $0.kg }
    }

    private var weightLabels: [String] {
        store.weightLogs.suffix(7).map { log in
            let p = log.id.split(separator: "-")
            return p.count == 3 ? "\(p[1])/\(p[2])" : log.id
        }
    }

    private var weeklyCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showWeekly = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [TWColor.blue.opacity(0.9), TWColor.purple.opacity(0.8)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 42, height: 42)
                    Image(systemName: "chart.bar.xaxis")
                        .font(.tw(18, .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("本周报告")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text("训练 · 步数 · 蛋白 · 体重，最近 7 天一次算完")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .twGlass()
    }

    private var watchSyncCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showWatch = true
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.mint)
                    Text("手表同步")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Text(store.watchSyncAt == nil ? "去配置" : "详情")
                        .font(.tw(12, .semibold))
                        .foregroundStyle(TWColor.mint)
                    Image(systemName: "chevron.right")
                        .font(.tw(10, .bold))
                        .foregroundStyle(TWColor.ink3)
                }

                if let t = store.watchSyncAt {
                    Text("上次同步 \(DateFormatter.twShort.string(from: t)) · 累计 \(store.watchSyncCount) 次")
                        .font(.tw(12))
                        .foregroundStyle(TWColor.ink2)

                    HStack(spacing: 0) {
                        watchCell("心率", store.hr > 0 ? "\(store.hr)" : "—", "bpm")
                        watchSep
                        watchCell("步数", store.watchSteps > 0 ? "\(store.watchSteps)" : "—", "步")
                        watchSep
                        watchCell("睡眠", store.watchSleepMin > 0 ? "\(store.watchSleepMin / 60)h\(store.watchSleepMin % 60)" : "—", "深睡 \(store.watchDeepMin) 分")
                    }
                    .padding(.top, 2)
                } else {
                    Text("快捷指令自动化，打开 App 就自动把心率、步数、睡眠、能耗灌进来")
                        .font(.tw(12))
                        .foregroundStyle(TWColor.ink3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private var watchSep: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.2))
            .frame(width: 1, height: 24)
    }

    private func watchCell(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.tw(18, .heavy, .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Text("\(title) · \(unit)")
                .font(.tw(10, .semibold))
                .foregroundStyle(TWColor.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    /// 血氧（手表 / 快捷指令通道）
    private var spo2Card: some View {
        let v = store.watchSpO2
        let tint: Color = v == 0 ? TWColor.ink3 : (v >= 95 ? TWColor.mint : (v >= 90 ? TWColor.amber : TWColor.coral))
        let state: String = v == 0 ? "还没测" : (v >= 95 ? "正常" : (v >= 90 ? "偏低" : "明显偏低，建议就医"))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lungs.fill")
                    .font(.tw(15, .semibold))
                    .foregroundStyle(tint)
                Text("血氧 SpO₂")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text(state)
                    .font(.tw(11.5, .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background { Capsule().fill(tint.opacity(0.13)) }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(v == 0 ? "—" : "\(v)")
                    .font(.tw(34, .heavy, .rounded))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
                Text("%")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                if let t = store.watchSpO2At {
                    Text(DateFormatter.twShort.string(from: t))
                        .font(.tw(11.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            Text(v == 0
                 ? "在手表上测一次血氧，再用「手表同步」那条快捷指令把 spo2 一起带进来。无法直接读健康数据，走快捷指令是免费签名下唯一的路。"
                 : "来自手表血氧传感器。正常范围 95–100%；长期低于 90% 要尽快就医。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private var sleepCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showSleep = true
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.purple)
                    Text("睡眠")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Text(store.lastSleep == nil ? "去记录" : "详情")
                        .font(.tw(12, .semibold))
                        .foregroundStyle(TWColor.purple)
                    Image(systemName: "chevron.right")
                        .font(.tw(10, .bold))
                        .foregroundStyle(TWColor.ink3)
                }

                if store.watchSleepMin > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                            .font(.tw(11, .semibold))
                            .foregroundStyle(TWColor.mint)
                        Text("手表夜间 \(store.watchSleepMin / 60) 小时 \(store.watchSleepMin % 60) 分 · 深睡 \(store.watchDeepMin) 分")
                            .font(.tw(11.5, .semibold))
                            .foregroundStyle(TWColor.ink2)
                        Spacer(minLength: 0)
                    }
                }

                if let s = store.lastSleep {
                    HStack(spacing: 14) {
                        VStack(spacing: 1) {
                            Text("\(s.score)")
                                .font(.tw(34, .heavy, .rounded))
                                .foregroundStyle(sleepScoreColor(s.score))
                            Text(s.scoreLabel)
                                .font(.tw(11, .semibold))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .frame(width: 84)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("睡了 \(s.durationText)")
                                .font(.tw(13.5, .bold))
                                .foregroundStyle(TWColor.ink)
                            Text("深 \(s.deepMinutes) 分 · 浅 \(s.lightMinutes) 分 · 醒 \(s.awakeMinutes) 分")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                            sleepMiniBar(s)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .font(.tw(17, .semibold))
                            .foregroundStyle(TWColor.ink3)
                            .frame(width: 40, height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(TWColor.purple.opacity(0.08))
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("还没有睡眠记录")
                                .font(.tw(13.5, .bold))
                                .foregroundStyle(TWColor.ink)
                            Text("睡前点开始，手机放枕边整夜记体动")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                                .lineSpacing(2)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(16)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private func sleepMiniBar(_ log: SleepLog) -> some View {
        let codes = log.stageCodes
        let total = max(1, codes.count)
        var segs: [(Int, Int)] = []
        if let first = codes.first {
            var cur = first
            var cnt = 1
            for c in codes.dropFirst() {
                if c == cur { cnt += 1 }
                else { segs.append((cur, cnt)); cur = c; cnt = 1 }
            }
            segs.append((cur, cnt))
        }
        return GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(segs.enumerated()), id: \.offset) { pair in
                    Rectangle()
                        .fill(stageTint(pair.element.0))
                        .frame(width: max(1, geo.size.width * CGFloat(pair.element.1) / CGFloat(total) - 1))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .background {
            Capsule().fill(TWColor.glass(0.35))
        }
    }

    private func stageTint(_ code: Int) -> Color {
        switch code {
        case 0: return TWColor.purple
        case 1: return TWColor.blue
        default: return TWColor.amber
        }
    }

    private func sleepScoreColor(_ s: Int) -> Color {
        switch s {
        case 80...: return TWColor.mint
        case 65..<80: return TWColor.blue
        case 50..<65: return TWColor.amber
        default: return TWColor.coral
        }
    }

    // MARK: - 睡眠对训练

    /// 每一场有容量的训练，配当天或前一晚的睡眠时长
    private var sleepTrainData: [(h: Double, ton: Double)] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var out: [(h: Double, ton: Double)] = []
        for s in store.sessions {
            guard let ton = s.tonnage, ton > 0 else { continue }
            var prev = ""
            if let d = f.date(from: s.date),
               let p = Calendar.current.date(byAdding: .day, value: -1, to: d) {
                prev = f.string(from: p)
            }
            let log = store.sleepLogs.first { $0.date == s.date }
                ?? store.sleepLogs.first { $0.date == prev }
            if let log {
                out.append((h: Double(log.durationMinutes) / 60, ton: ton))
            }
        }
        return out
    }

    private var sleepTrainVerdict: String {
        let d = sleepTrainData
        let short = d.filter { $0.h < 6 }.map { $0.ton }
        let good = d.filter { $0.h >= 7 }.map { $0.ton }
        guard short.count >= 2, good.count >= 2 else {
            let need = max(0, 2 - short.count) + max(0, 2 - good.count)
            return "再记 \(need) 场「睡够 / 没睡够」的训练，就能看出差了。"
        }
        let a = short.reduce(0, +) / Double(short.count)
        let b = good.reduce(0, +) / Double(good.count)
        guard b > 0 else { return "样本还不够。" }
        let drop = (b - a) / b * 100
        if drop >= 8 { return "睡不到 6 小时那几天，平均容量比睡够时低 \(Int(drop))%。" }
        if drop <= -8 { return "睡得少反而练得多——注意别硬撑，疲劳是攒出来的。" }
        return "睡得少和睡够的容量差不多，你的恢复力还行。"
    }

    @ViewBuilder
    private var sleepTrainCard: some View {
        let d = sleepTrainData
        if !d.isEmpty {
            let short = d.filter { $0.h < 6 }.map { $0.ton }
            let good = d.filter { $0.h >= 7 }.map { $0.ton }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "bed.double.fill")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.purple)
                    Text("睡眠对训练")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    GlassPill(text: "\(d.count) 场有睡眠数据", tint: TWColor.ink3)
                }

                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(good.isEmpty ? "—" : "\(Int(good.reduce(0, +) / Double(good.count)))")
                            .font(.tw(20, .heavy))
                            .foregroundStyle(TWColor.mint)
                        Text("睡够时容量 kg")
                            .font(.tw(10, .regular))
                            .foregroundStyle(TWColor.ink3)
                    }
                    .frame(maxWidth: .infinity)
                    Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(width: 0.7, height: 30)
                    VStack(spacing: 2) {
                        Text(short.isEmpty ? "—" : "\(Int(short.reduce(0, +) / Double(short.count)))")
                            .font(.tw(20, .heavy))
                            .foregroundStyle(TWColor.coral)
                        Text("睡不足 6h 时")
                            .font(.tw(10, .regular))
                            .foregroundStyle(TWColor.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text(sleepTrainVerdict)
                    .font(.tw(12, .regular))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .twGlass()
        }
    }

    /// 本周每个肌群做了多少组。常用区间 10–20 组/周，超了过量、欠了该补。
    private var groupVolumeCard: some View {
        let rows = store.weeklyGroupSets()
        let total = rows.reduce(0) { $0 + $1.sets }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("本周肌群分布")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: rows.isEmpty ? "近 7 天" : "\(total) 组", tint: TWColor.blue)
            }

            if rows.isEmpty {
                Text("这七天还没有训练记录。练完回来，这里会按胸、背、腿分开算组数。")
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 9) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { pair in
                        let g = pair.element.group
                        let n = pair.element.sets
                        groupBar(g, sets: n)
                    }
                }
                Text(volumeAdvice)
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .twGlass()
    }

    private func groupBar(_ g: String, sets n: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(g)
                    .font(.tw(12.5, .semibold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 4)
                Text("\(n) 组")
                    .font(.tw(12, .bold))
                    .foregroundStyle(volumeTint(n))
                    .monospacedDigit()
                Text(n > 20 ? "偏多" : (n < 10 ? "偏少" : "合适"))
                    .font(.tw(10, .medium))
                    .foregroundStyle(volumeTint(n))
                    .frame(width: 30, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TWColor.ink3.opacity(0.12))
                    Capsule()
                        .fill(volumeTint(n))
                        .frame(width: geo.size.width * min(1, Double(n) / 20))
                }
            }
            .frame(height: 6)
        }
    }

    private func volumeTint(_ n: Int) -> Color {
        if n > 20 { return TWColor.coral }
        if n < 10 { return TWColor.ink3 }
        return TWColor.mint
    }

    /// 最久没练的那块，直接点名，省得自己翻记录
    private var volumeAdvice: String {
        let groups = ["胸", "背", "腿", "肩", "手臂", "核心"]
        var bestName = ""
        var bestDays = 0
        for g in groups {
            guard let d = store.daysSinceTrain(group: g) else { continue }
            if d >= 2, d > bestDays {
                bestName = g
                bestDays = d
            }
        }
        if !bestName.isEmpty {
            return "最久没练：\(bestName)，\(bestDays) 天前。下次排课把它补上。"
        }
        return "各肌群最近两天都练过，分布均衡。"
    }

    /// 体重趋势：单次数字没意义，方向才有。
    /// 目标线画在图上，减了几斤、离目标还有多少，一眼看完。
    private var weightTrendCard: some View {
        let logs = store.weightLogs.sorted { $0.id < $1.id }
        let recent = Array(logs.suffix(30))
        let vals = recent.map { $0.kg }
        let goal = store.weightGoal
        let lo = min(vals.min() ?? 0, goal > 0 ? goal : (vals.min() ?? 0))
        let hi = max(vals.max() ?? 0, goal > 0 ? goal : (vals.max() ?? 0))
        let span = max(0.6, hi - lo)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("体重趋势")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: recent.count >= 2 ? "近 \(recent.count) 次" : "还不够画线",
                          tint: recent.count >= 2 ? TWColor.mint : TWColor.ink3)
            }

            if recent.count < 2 {
                Text("至少记两次才能看出方向。每天早上空腹、同一台秤称一次，趋势比单次数字可靠。")
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let step = w / CGFloat(max(1, recent.count - 1))
                    ZStack(alignment: .topLeading) {
                        if goal > 0 {
                            Path { p in
                                let y = h - CGFloat((goal - lo) / span) * (h - 10) - 5
                                p.move(to: CGPoint(x: 0, y: y))
                                p.addLine(to: CGPoint(x: w, y: y))
                            }
                            .stroke(TWColor.amber.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 1, dash: [4, 3]))

                            Text("目标 \(String(format: "%.1f", goal))")
                                .font(.tw(9.5, .semibold))
                                .foregroundStyle(TWColor.amber)
                                .offset(x: 4,
                                        y: h - CGFloat((goal - lo) / span) * (h - 10) - 20)
                        }

                        Path { p in
                            for (i, v) in vals.enumerated() {
                                let pt = CGPoint(x: CGFloat(i) * step,
                                                 y: h - CGFloat((v - lo) / span) * (h - 10) - 5)
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                        }
                        .stroke(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                               startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                        if let last = vals.last {
                            Circle()
                                .fill(TWColor.mint)
                                .frame(width: 7, height: 7)
                                .offset(x: w - 7,
                                        y: h - CGFloat((last - lo) / span) * (h - 10) - 8)
                        }
                    }
                }
                .frame(height: 108)

                if let first = recent.first, let last = recent.last {
                    let diff = last.kg - first.kg
                    HStack(spacing: 14) {
                        trendTag("起始", String(format: "%.1f", first.kg), TWColor.ink2)
                        trendTag("现在", String(format: "%.1f", last.kg), TWColor.ink)
                        trendTag(diff >= 0 ? "变化 +" : "变化 −",
                                 String(format: "%.1f", abs(diff)),
                                 diff >= 0 ? TWColor.coral : TWColor.mint)
                        Spacer(minLength: 0)
                        if goal > 0 {
                            trendTag("离目标", String(format: "%.1f", abs(last.kg - goal)), TWColor.amber)
                        }
                    }

                    if let eta = weightETA(recent) {
                        Text("照最近四周的速度，预计 \(eta) 到 \(String(format: "%.1f", goal)) kg")
                            .font(.tw(10.5))
                            .foregroundStyle(TWColor.mint)
                    } else if goal > 0 {
                        Text("记够两周、方向稳定后，会给出预计到达日期。")
                            .font(.tw(10))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private func trendTag(_ k: String, _ v: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k)
                .font(.tw(9.5))
                .foregroundStyle(TWColor.ink3)
            Text(v)
                .font(.tw(15, .bold))
                .foregroundStyle(tint)
        }
    }

    /// 按最近四周的净变化推目标日期；方向反了或数据太少就不硬算。
    /// Deurenberg 估算：BMI + 年龄 + 性别。没有颈围，用不了海军公式。
    private var bodyFatEstimate: (pct: Double, fatKg: Double, leanKg: Double)? {
        guard store.bmi > 0, store.age > 0, store.bodyWeight > 0 else { return nil }
        let base = 1.8 * store.bmi + 0.23 * Double(store.age)
        let pct = store.sexMale ? base - 16.4 : base - 5.4
        guard pct > 3, pct < 60 else { return nil }
        let fatKg = store.bodyWeight * pct / 100
        return (pct, fatKg, store.bodyWeight - fatKg)
    }

    private func weightETA(_ logs: [WeightLog]) -> String? {
        let goal = store.weightGoal
        guard goal > 0, logs.count >= 2 else { return nil }
        let cutoff = Date().addingTimeInterval(-28 * 86400)
        let recent = logs.filter { (DateFormatter.twDay.date(from: $0.id) ?? .distantPast) > cutoff }
        guard recent.count >= 2,
              let first = recent.first, let last = recent.last,
              let d1 = DateFormatter.twDay.date(from: first.id),
              let d2 = DateFormatter.twDay.date(from: last.id) else { return nil }
        let weeks = max(1.0, d2.timeIntervalSince(d1) / 604800)
        let rate = (last.kg - first.kg) / weeks
        let delta = goal - last.kg
        guard abs(rate) > 0.05, delta * rate > 0 else { return nil }
        let days = Int(abs(delta / rate) * 7)
        guard days > 0, days < 520 else { return nil }
        let f = DateFormatter()
        f.dateFormat = "M 月 d 日"
        return f.string(from: Date().addingTimeInterval(Double(days) * 86400))
    }

    /// 近半年训练量：柱高是次数，下面一行是当月的时长和吨位
    private var trainingStatsCard: some View {
        let cal = Calendar.current
        let now = Date()
        func key(_ d: Date) -> String {
            let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f.string(from: d)
        }
        func label(_ d: Date) -> String {
            let f = DateFormatter(); f.dateFormat = "M月"; return f.string(from: d)
        }
        let months = (0..<6).reversed().compactMap { off -> (String, Int, Int, Double)? in
            guard let d = cal.date(byAdding: .month, value: -off, to: now) else { return nil }
            let k = key(d)
            let list = store.sessions.filter { $0.date.hasPrefix(k) }
            return (label(d), list.count, list.reduce(0) { $0 + $1.minutes },
                    list.reduce(0.0) { $0 + ($1.tonnage ?? 0) })
        }
        let peak = max(1, months.map { $0.1 }.max() ?? 1)
        let thisMonth = months.last

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("训练统计")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    showBackfill = true
                } label: {
                    Text("补录")
                        .font(.tw(11, .bold))
                        .foregroundStyle(TWColor.mint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(TWColor.mint.opacity(0.13)) }
                }
                .buttonStyle(.plain)
                GlassPill(text: "近 6 个月", tint: TWColor.purple)
            }

            if store.sessions.isEmpty {
                Text("练完一次，这里就会开始长柱子。")
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink3)
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(Array(months.enumerated()), id: \.offset) { i, m in
                        VStack(spacing: 5) {
                            Text("\(m.1)")
                                .font(.tw(9.5, .bold))
                                .foregroundStyle(i == months.count - 1 ? TWColor.ink : TWColor.ink3)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(i == months.count - 1
                                      ? LinearGradient(colors: [TWColor.mint, TWColor.blue],
                                                       startPoint: .top, endPoint: .bottom)
                                      : LinearGradient(colors: [TWColor.ink3.opacity(0.45), TWColor.ink3.opacity(0.18)],
                                                       startPoint: .top, endPoint: .bottom))
                                .frame(height: max(6, CGFloat(m.1) / CGFloat(peak) * 62))
                            Text(m.0)
                                .font(.tw(9))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 118, alignment: .bottom)

                if let m = thisMonth {
                    HStack(spacing: 20) {
                        trendTag("本月次数", "\(m.1)", TWColor.ink)
                        trendTag("总时长", "\(m.2) 分", TWColor.blue)
                        trendTag("总吨位", String(format: "%.0f", m.3), TWColor.purple)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("身体数据")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: bmiText, tint: TWColor.purple)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.bodyWeight > 0 ? String(format: "%.1f", store.bodyWeight) : "--")
                    .font(.tw(42, .heavy))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                Text("kg")
                    .font(.tw(13, .medium))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("腰围")
                        .font(.tw(11, .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Text(store.waistCM > 0 ? "\(Int(store.waistCM)) cm" : "--")
                        .font(.tw(17, .bold))
                        .foregroundStyle(TWColor.blue)
                }
            }

            if store.bmi > 0 {
                VStack(spacing: 5) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        ZStack(alignment: .leading) {
                            HStack(spacing: 0) {
                                Rectangle().fill(TWColor.blue.opacity(0.55)).frame(width: w * 0.21)
                                Rectangle().fill(TWColor.mint.opacity(0.55)).frame(width: w * 0.32)
                                Rectangle().fill(TWColor.amber.opacity(0.55)).frame(width: w * 0.24)
                                Rectangle().fill(TWColor.coral.opacity(0.55))
                            }
                            .clipShape(Capsule())

                            Capsule()
                                .fill(Color.white)
                                .frame(width: 4, height: 18)
                                .shadow(color: .black.opacity(0.28), radius: 1.5, y: 0.5)
                                .offset(x: CGFloat(min(max((store.bmi - 15) / 17, 0), 1)) * (w - 4))
                        }
                    }
                    .frame(height: 18)

                    HStack {
                        Text("偏瘦 18.5").font(.tw(9.5)).foregroundStyle(TWColor.ink3)
                        Spacer()
                        Text("正常 24").font(.tw(9.5)).foregroundStyle(TWColor.ink3)
                        Spacer()
                        Text("偏高 28").font(.tw(9.5)).foregroundStyle(TWColor.ink3)
                    }
                }

                if let fat = bodyFatEstimate {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("体脂约")
                                .font(.tw(9.5))
                                .foregroundStyle(TWColor.ink3)
                            Text(String(format: "%.1f%%", fat.pct))
                                .font(.tw(18, .bold))
                                .foregroundStyle(TWColor.amber)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("脂肪量")
                                .font(.tw(9.5))
                                .foregroundStyle(TWColor.ink3)
                            Text(String(format: "%.1f kg", fat.fatKg))
                                .font(.tw(13, .semibold))
                                .foregroundStyle(TWColor.ink2)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("去脂体重")
                                .font(.tw(9.5))
                                .foregroundStyle(TWColor.ink3)
                            Text(String(format: "%.1f kg", fat.leanKg))
                                .font(.tw(13, .semibold))
                                .foregroundStyle(TWColor.ink2)
                        }
                        Spacer(minLength: 0)
                    }
                    Text("按 BMI + 年龄估的，误差约 ±5%，只用来看趋势，不用当体检结论。")
                        .font(.tw(9.5))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 0) {
                girthCell(title: "胸", value: store.chestCM)
                Rectangle().fill(TWColor.ink3.opacity(0.14)).frame(width: 0.8, height: 26)
                girthCell(title: "臂", value: store.armCM)
                Rectangle().fill(TWColor.ink3.opacity(0.14)).frame(width: 0.8, height: 26)
                girthCell(title: "腿", value: store.thighCM)
                Rectangle().fill(TWColor.ink3.opacity(0.14)).frame(width: 0.8, height: 26)
                girthCell(title: "臀", value: store.hipCM)
            }
            .padding(.vertical, 8)

            if weightPoints.count >= 2 {
                TrendChart(title: "体重 · 最近 7 次",
                           values: weightPoints,
                           labels: weightLabels,
                           tint: TWColor.purple,
                           unit: "kg",
                           decimals: 1,
                           goal: store.weightGoal > 0 ? store.weightGoal : nil)
            }

            if store.weightGoal > 0 {
                let diff = store.bodyWeight - store.weightGoal
                HStack(spacing: 8) {
                    Image(systemName: abs(diff) < 0.3 ? "checkmark.circle.fill" : "flag.fill")
                        .font(.tw(13, .semibold))
                        .foregroundStyle(abs(diff) < 0.3 ? TWColor.mint : TWColor.amber)
                    Text("目标 \(String(format: "%.1f", store.weightGoal)) kg")
                        .font(.tw(12.5, .semibold))
                        .foregroundStyle(TWColor.ink2)
                    Spacer()
                    Text(abs(diff) < 0.3
                         ? "已达成"
                         : (diff > 0
                            ? String(format: "还差 %.1f kg", diff)
                            : String(format: "超目标 %.1f kg", -diff)))
                        .font(.tw(12.5, .bold))
                        .foregroundStyle(abs(diff) < 0.3 ? TWColor.mint : TWColor.amber)
                }

                if abs(diff) >= 0.3, let eta = store.weightGoalETA {
                    Text("照最近两周的速度，大约 \(eta.formatted(.dateTime.month().day())) 到目标")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                wText = store.bodyWeight > 0 ? String(format: "%.1f", store.bodyWeight) : ""
                hText = store.heightCM > 0 ? "\(Int(store.heightCM))" : ""
                waistText = store.waistCM > 0 ? "\(Int(store.waistCM))" : ""
                goalText = store.weightGoal > 0 ? String(format: "%.1f", store.weightGoal) : ""
                chestText = store.chestCM > 0 ? "\(Int(store.chestCM))" : ""
                armText = store.armCM > 0 ? "\(Int(store.armCM))" : ""
                thighText = store.thighCM > 0 ? "\(Int(store.thighCM))" : ""
                hipText = store.hipCM > 0 ? "\(Int(store.hipCM))" : ""
                showBody = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.tw(14, .bold))
                    Text("记录身体数据")
                        .font(.tw(14.5, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .twGlass()
    }

    private func girthCell(title: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
            Text(value > 0 ? String(format: "%.0f", value) : "--")
                .font(.tw(16, .heavy))
                .foregroundStyle(TWColor.ink)
        }
        .frame(maxWidth: .infinity)
    }

    private var girthLogs7: [GirthLog] {
        Array(store.girthLogs.suffix(7))
    }

    private var girthValues: [Double] {
        switch girthPick {
        case 0: return girthLogs7.map { $0.waist }
        case 1: return girthLogs7.map { $0.chest }
        case 2: return girthLogs7.map { $0.arm }
        case 3: return girthLogs7.map { $0.thigh }
        default: return girthLogs7.map { $0.hip }
        }
    }

    private var girthLabels: [String] {
        girthLogs7.map { log in
            let p = log.id.split(separator: "-")
            return p.count == 3 ? "\(p[1])/\(p[2])" : log.id
        }
    }

    private var girthTitles: [String] { ["腰围", "胸围", "臂围", "腿围", "臀围"] }

    private var progressCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showProgress = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple.opacity(0.20), TWColor.violet.opacity(0.10)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.tw(17, .semibold))
                        .foregroundStyle(TWColor.purple)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("进度照")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(store.progressPhotos.isEmpty
                         ? "拍第一张，以后并排比变化"
                         : "已存 \(store.progressPhotos.count) 张 · 最早 \(store.progressPhotos.last?.date ?? "")")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(11, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private var girthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("围度趋势")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: girthTitles[min(girthPick, 4)], tint: TWColor.blue)
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) { girthPick = i }
                    } label: {
                        Text(String(girthTitles[i].prefix(1)))
                            .font(.tw(13, girthPick == i ? .bold : .medium))
                            .foregroundStyle(girthPick == i ? .white : TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(girthPick == i
                                          ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.purple],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                          : AnyShapeStyle(TWColor.glass(0.42)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            if girthValues.count >= 2 {
                TrendChart(title: girthTitles[min(girthPick, 4)] + " · 最近 7 次",
                           values: girthValues,
                           labels: girthLabels,
                           tint: TWColor.blue,
                           unit: "cm",
                           decimals: 1)
            } else {
                Text("同一个部位记录两次以上，就会出现变化曲线。")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 围度首尾对比

    @ViewBuilder
    private var girthCompareCard: some View {
        let sorted = store.girthLogs.sorted { $0.id < $1.id }
        if sorted.count >= 2, let first = sorted.first, let last = sorted.last {
            let span = spanText(from: first.id, to: last.id)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "ruler")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.mint)
                    Text("这段时间的变化")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    GlassPill(text: span, tint: TWColor.ink3)
                }

                Text("第一次 \(shortDay(first.id)) → 最近 \(shortDay(last.id))")
                    .font(.tw(11, .regular))
                    .foregroundStyle(TWColor.ink3)

                VStack(spacing: 9) {
                    if first.chest > 0, last.chest > 0 {
                        girthRow("胸", first.chest, last.chest, goodUp: true)
                    }
                    if first.waist > 0, last.waist > 0 {
                        girthRow("腰", first.waist, last.waist, goodUp: false)
                    }
                    if first.hip > 0, last.hip > 0 {
                        girthRow("臀", first.hip, last.hip, goodUp: false)
                    }
                    if first.arm > 0, last.arm > 0 {
                        girthRow("臂", first.arm, last.arm, goodUp: true)
                    }
                    if first.thigh > 0, last.thigh > 0 {
                        girthRow("腿", first.thigh, last.thigh, goodUp: false)
                    }
                }

                Text(girthVerdict(first, last))
                    .font(.tw(11.5, .regular))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .twGlass()
        }
    }

    private func girthRow(_ name: String, _ from: Double, _ to: Double, goodUp: Bool) -> some View {
        let d = to - from
        let flat = abs(d) < 0.25
        let better = goodUp ? d > 0 : d < 0
        let tint = flat ? TWColor.ink3 : (better ? TWColor.mint : TWColor.coral)
        return HStack(spacing: 8) {
            Text(name)
                .font(.tw(12.5, .semibold))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 24, alignment: .leading)
            Text(String(format: "%.1f", from))
                .font(.tw(12.5, .regular))
                .foregroundStyle(TWColor.ink3)
                .monospacedDigit()
            Image(systemName: "arrow.right")
                .font(.tw(9, .bold))
                .foregroundStyle(TWColor.ink3.opacity(0.55))
            Text(String(format: "%.1f", to))
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: flat ? "minus" : (d > 0 ? "arrow.up.right" : "arrow.down.right"))
                    .font(.tw(9, .bold))
                Text(flat ? "没变" : String(format: "%.1f", abs(d)))
                    .font(.tw(11.5, .semibold))
            }
            .foregroundStyle(tint)
        }
    }

    private func girthVerdict(_ a: GirthLog, _ b: GirthLog) -> String {
        let waist = b.waist > 0 && a.waist > 0 ? b.waist - a.waist : 0
        let arm = b.arm > 0 && a.arm > 0 ? b.arm - a.arm : 0
        if waist <= -2, arm >= 0.5 { return "腰细了、臂围还长了，这是最想要的那种变化。" }
        if waist <= -2 { return "腰围掉了 \(String(format: "%.1f", abs(waist))) cm，继续按这个节奏。" }
        if waist >= 2 { return "腰围涨了 \(String(format: "%.1f", waist)) cm，最近热量可能超了。" }
        if arm >= 0.5 { return "臂围涨了 \(String(format: "%.1f", arm)) cm，上肢有在长。" }
        return "整体没什么变化，想推动就先把训练容量或蛋白提上去。"
    }

    private func shortDay(_ key: String) -> String {
        let p = key.split(separator: "-")
        return p.count == 3 ? "\(p[1])/\(p[2])" : key
    }

    private func spanText(from a: String, to b: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let da = f.date(from: a), let db = f.date(from: b) else { return "跨度" }
        let days = Calendar.current.dateComponents([.day], from: da, to: db).day ?? 0
        if days <= 0 { return "同一天" }
        if days < 14 { return "\(days) 天" }
        if days < 90 { return "\(days / 7) 周" }
        return "\(days / 30) 个月"
    }

    // MARK: - 饮水

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("饮水")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showWater = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(store.waterCups) / \(store.waterTarget) 杯 · \(store.waterML) ml")
                            .font(.tw(12.5, .semibold))
                            .foregroundStyle(TWColor.ink3)
                            .contentTransition(.numericText())
                        Image(systemName: "slider.horizontal.3")
                            .font(.tw(11, .bold))
                            .foregroundStyle(TWColor.blue)
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(Array(0..<store.waterTarget), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(i < store.waterCups
                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                             startPoint: .bottom, endPoint: .top))
                              : AnyShapeStyle(TWColor.glass(0.38)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay {
                            Image(systemName: "drop.fill")
                                .font(.tw(11, .semibold))
                                .foregroundStyle(i < store.waterCups ? .white : TWColor.ink3.opacity(0.6))
                        }
                }
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) { store.addWater(-1) }
                } label: {
                    Text("− 1 杯")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(TWColor.glass(0.55))
                        }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showWaterLog = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.tw(12, .bold))
                        Text("自定义")
                            .font(.tw(13, .bold))
                    }
                    .foregroundStyle(TWColor.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(TWColor.blue.opacity(0.1))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) { store.addWater() }
                } label: {
                    Text("+ 1 杯（\(store.cupSize)ml）")
                        .font(.tw(14, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                     startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 数据通路

    // MARK: - 心率

    private var heatmapCard: some View {
        TrainingHeatmap(values: trainingHeat)
    }

    /// 每次训练的总吨位，没记吨位的老记录按组数折算一下，不然整格是空的
    private var trainingHeat: [String: Double] {
        var out: [String: Double] = [:]
        for s in store.sessions {
            let v = (s.tonnage ?? 0) > 0 ? (s.tonnage ?? 0) : Double(s.sets) * 10
            out[s.date, default: 0] += v
        }
        return out
    }

    private var hrCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("心率")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if !store.hrSource.isEmpty {
                    GlassPill(text: store.hrSource, tint: TWColor.coral)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(store.measuredHR > 0 ? "\(store.measuredHR)" : "--")
                    .font(.tw(56, .heavy))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.ink3)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("HRV")
                        .font(.tw(11, .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Text(store.measuredHRV > 0 ? "\(store.measuredHRV) ms" : "--")
                        .font(.tw(18, .bold))
                        .foregroundStyle(TWColor.amber)
                }
            }

            if let at = store.measuredAt {
                Text("最近一次：" + timeText(at))
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink3)
            } else {
                Text("还没有测量记录")
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink3)
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showPulse = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.tw(14, .bold))
                        Text("指尖测 30 秒")
                            .font(.tw(14.5, .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.coral, TWColor.pink],
                                                 startPoint: .leading, endPoint: .trailing))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    manualText = ""
                    showManual = true
                } label: {
                    Text("手动")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 74)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(TWColor.glass(0.55))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 步数

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日步数")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: motionStatus, tint: TWColor.blue)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.pedometerSteps)")
                    .font(.tw(40, .heavy))
                    .foregroundStyle(TWColor.blue)
                    .contentTransition(.numericText())
                Text("步")
                    .font(.tw(13, .medium))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                if store.pedometerDistance > 0 {
                    Text(String(format: "%.2f 公里", store.pedometerDistance / 1000))
                        .font(.tw(13, .semibold))
                        .foregroundStyle(TWColor.ink2)
                }
            }

            Text("来自 iPhone 运动协处理器，不需要 HealthKit，免费签名也能读")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                loadSteps()
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Text("刷新")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(TWColor.blue.opacity(0.10))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 数据通路

    private var achievementCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showAch = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "trophy.fill")
                        .font(.tw(15, .bold))
                        .foregroundStyle(TWColor.amber)
                    Text("成就")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Text("看进度")
                        .font(.tw(11.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Image(systemName: "chevron.right")
                        .font(.tw(11, .bold))
                        .foregroundStyle(TWColor.ink3)
                }

                HStack(spacing: 10) {
                    achTile("连续", "\(store.trainingStreak) 天", TWColor.amber)
                    achTile("训练", "\(store.sessions.count) 次", TWColor.purple)
                    achTile("总容量", achTon, TWColor.mint)
                }

                Text("10 个徽章，做到就亮。全部按本机真实记录算，不写死。")
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private var achTon: String {
        let t = store.sessions.compactMap { $0.tonnage }.reduce(0, +)
        if t >= 10000 { return String(format: "%.1f t", t / 1000) }
        return String(format: "%.0f kg", t)
    }

    private func achTile(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.tw(10.5, .medium))
                .foregroundStyle(TWColor.ink3)
            Text(value)
                .font(.tw(15, .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据通路")
                .font(.tw(16, .bold))
                .foregroundStyle(TWColor.ink)

            sourceRow(
                icon: "iphone.gen3",
                title: "指尖 PPG",
                detail: "摄像头 + 闪光灯，本机物理测量",
                state: "可用",
                tint: TWColor.mint
            )
            sourceRow(
                icon: "figure.walk",
                title: "步数 / 距离",
                detail: "CoreMotion 运动协处理器",
                state: "可用",
                tint: TWColor.mint
            )
            sourceRow(
                icon: "applewatch",
                title: "手表心率直连",
                detail: "需要 com.apple.developer.healthkit",
                state: "需要付费签名",
                tint: TWColor.amber
            )
            sourceRow(
                icon: "arrow.triangle.branch",
                title: "快捷指令自动化",
                detail: "打开 App 自动灌入全部健康数据",
                state: store.watchSyncAt == nil ? "待配置" : "已连通",
                tint: store.watchSyncAt == nil ? TWColor.amber : TWColor.mint
            )

            Text("手表的数据只能经 HealthKit 或 WatchConnectivity 进入第三方 App，这两项都不在免费 Apple ID 的可签能力里。走快捷指令自动化是免费条件下唯一能拿到全量健康数据的通道，配一次之后每次打开 App 自动同步。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .twGlass()
    }

    private func sourceRow(icon: String, title: String, detail: String, state: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.tw(15, .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.ink)
                Text(detail)
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(state)
                .font(.tw(11, .semibold))
                .foregroundStyle(tint)
        }
    }

    // MARK: - 动作

    private func loadSteps() {
        guard CMPedometer.isStepCountingAvailable() else {
            motionStatus = "此设备不支持"
            return
        }

        switch CMPedometer.authorizationStatus() {
        case .authorized: motionStatus = "已授权"
        case .denied:     motionStatus = "被拒绝"
        case .restricted: motionStatus = "受限"
        default:          motionStatus = "待授权"
        }

        // 交给全局 StepLive：query 补历史 + startUpdates 持续推送，数值只增不减
        StepLive.shared.refresh()
    }

    private func timeText(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
}

struct ManualHeartSheet: View {
    @Binding var text: String
    var onOK: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 16) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 10)

                Text("手动录入心率")
                    .font(.tw(19, .heavy))
                    .foregroundStyle(TWColor.ink)

                Text("用脉搏计数（数 30 秒 × 2），或直接读手表上的数")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)

                TextField("例如 72", text: $text)
                    .keyboardType(.numberPad)
                    .font(.tw(24, .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TWColor.glass(0.6))
                    }
                    .padding(.horizontal, 26)

                Button {
                    if let v = Int(text), v >= 30, v <= 220 {
                        onOK(v)
                        dismiss()
                    }
                } label: {
                    Text("保存")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.coral, TWColor.pink],
                                                     startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)

                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct SparkLine: View {
    private let points: [CGFloat] = [0.42, 0.55, 0.38, 0.62, 0.48, 0.7, 0.52, 0.66, 0.44, 0.58, 0.5, 0.72, 0.46, 0.6, 0.40]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                for (i, v) in points.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(points.count - 1)
                    let y = h * (1 - v)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [TWColor.coral.opacity(0.85), TWColor.pink.opacity(0.65)],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
        }
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.tw(11.5, .semibold))
                        .tracking(1.0)
                        .foregroundStyle(TWColor.ink3)
                }
                TwGradientText(text: title, size: 30)
            }
            Spacer()
        }
    }
}

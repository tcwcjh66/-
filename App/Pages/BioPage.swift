import SwiftUI
import UIKit
import CoreMotion

struct BioPage: View {
    @EnvironmentObject var store: TWStore

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

    private let pedometer = CMPedometer()

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "身体", subtitle: "本机实测 · 不含模拟数据")

            hrCard
            watchSyncCard
            stepCard
            sleepCard
            bodyCard
            girthCard
            waterCard
            sourceCard
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
        .sheet(isPresented: $showWaterLog) {
            WaterLogSheet()
                .presentationDetents([.medium, .large])
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

    private var watchSyncCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showWatch = true
        } label: {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TWColor.mint)
                    Text("手表同步")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Text(store.watchSyncAt == nil ? "去配置" : "详情")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TWColor.mint)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TWColor.ink3)
                }

                if let t = store.watchSyncAt {
                    Text("上次同步 \(DateFormatter.twShort.string(from: t)) · 累计 \(store.watchSyncCount) 次")
                        .font(.system(size: 12))
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
                        .font(.system(size: 12))
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
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Text("\(title) · \(unit)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var sleepCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showSleep = true
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TWColor.purple)
                    Text("睡眠")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Text(store.lastSleep == nil ? "去记录" : "详情")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TWColor.purple)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TWColor.ink3)
                }

                if store.watchSleepMin > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "applewatch")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TWColor.mint)
                        Text("手表夜间 \(store.watchSleepMin / 60) 小时 \(store.watchSleepMin % 60) 分 · 深睡 \(store.watchDeepMin) 分")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink2)
                        Spacer(minLength: 0)
                    }
                }

                if let s = store.lastSleep {
                    HStack(spacing: 14) {
                        VStack(spacing: 1) {
                            Text("\(s.score)")
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(sleepScoreColor(s.score))
                            Text(s.scoreLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .frame(width: 84)

                        VStack(alignment: .leading, spacing: 7) {
                            Text("睡了 \(s.durationText)")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(TWColor.ink)
                            Text("深 \(s.deepMinutes) 分 · 浅 \(s.lightMinutes) 分 · 醒 \(s.awakeMinutes) 分")
                                .font(.system(size: 11.5))
                                .foregroundStyle(TWColor.ink3)
                            sleepMiniBar(s)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(TWColor.ink3)
                            .frame(width: 40, height: 40)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(TWColor.purple.opacity(0.08))
                            }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("还没有睡眠记录")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundStyle(TWColor.ink)
                            Text("睡前点开始，手机放枕边整夜记体动")
                                .font(.system(size: 11.5))
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
            Capsule().fill(Color.white.opacity(0.35))
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

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("身体数据")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: bmiText, tint: TWColor.purple)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(store.bodyWeight > 0 ? String(format: "%.1f", store.bodyWeight) : "--")
                    .font(.system(size: 42, weight: .heavy))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                Text("kg")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("腰围")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Text(store.waistCM > 0 ? "\(Int(store.waistCM)) cm" : "--")
                        .font(.system(size: 17, weight: .bold))
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
                        Text("偏瘦 18.5").font(.system(size: 9.5)).foregroundStyle(TWColor.ink3)
                        Spacer()
                        Text("正常 24").font(.system(size: 9.5)).foregroundStyle(TWColor.ink3)
                        Spacer()
                        Text("偏高 28").font(.system(size: 9.5)).foregroundStyle(TWColor.ink3)
                    }
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
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(abs(diff) < 0.3 ? TWColor.mint : TWColor.amber)
                    Text("目标 \(String(format: "%.1f", store.weightGoal)) kg")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                    Spacer()
                    Text(abs(diff) < 0.3
                         ? "已达成"
                         : (diff > 0
                            ? String(format: "还差 %.1f kg", diff)
                            : String(format: "超目标 %.1f kg", -diff)))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(abs(diff) < 0.3 ? TWColor.mint : TWColor.amber)
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
                        .font(.system(size: 14, weight: .bold))
                    Text("记录身体数据")
                        .font(.system(size: 14.5, weight: .bold))
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
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            Text(value > 0 ? String(format: "%.0f", value) : "--")
                .font(.system(size: 16, weight: .heavy))
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

    private var girthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("围度趋势")
                    .font(.system(size: 16, weight: .bold))
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
                            .font(.system(size: 13, weight: girthPick == i ? .bold : .medium))
                            .foregroundStyle(girthPick == i ? .white : TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(girthPick == i
                                          ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.purple],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                          : AnyShapeStyle(Color.white.opacity(0.42)))
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
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(18)
        .twGlass()
    }

    // MARK: - 饮水

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("饮水")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showWater = true
                } label: {
                    HStack(spacing: 4) {
                        Text("\(store.waterCups) / \(store.waterTarget) 杯 · \(store.waterML) ml")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink3)
                            .contentTransition(.numericText())
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .bold))
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
                              : AnyShapeStyle(Color.white.opacity(0.38)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .overlay {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 11, weight: .semibold))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.55))
                        }
                }
                .buttonStyle(.plain)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    showWaterLog = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 12, weight: .bold))
                        Text("自定义")
                            .font(.system(size: 13, weight: .bold))
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
                        .font(.system(size: 14, weight: .bold))
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

    private var hrCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("心率")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if !store.hrSource.isEmpty {
                    GlassPill(text: store.hrSource, tint: TWColor.coral)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(store.measuredHR > 0 ? "\(store.measuredHR)" : "--")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("HRV")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Text(store.measuredHRV > 0 ? "\(store.measuredHRV) ms" : "--")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(TWColor.amber)
                }
            }

            if let at = store.measuredAt {
                Text("最近一次：" + timeText(at))
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.ink3)
            } else {
                Text("还没有测量记录")
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.ink3)
            }

            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showPulse = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .bold))
                        Text("指尖测 30 秒")
                            .font(.system(size: 14.5, weight: .bold))
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 74)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.55))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                GlassPill(text: motionStatus, tint: TWColor.blue)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.pedometerSteps)")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(TWColor.blue)
                    .contentTransition(.numericText())
                Text("步")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                if store.pedometerDistance > 0 {
                    Text(String(format: "%.2f 公里", store.pedometerDistance / 1000))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                }
            }

            Text("来自 iPhone 运动协处理器，不需要 HealthKit，免费签名也能读")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                loadSteps()
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                Text("刷新")
                    .font(.system(size: 13, weight: .semibold))
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

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据通路")
                .font(.system(size: 16, weight: .bold))
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
                .font(.system(size: 11.5))
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text(state)
                .font(.system(size: 11, weight: .semibold))
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
        case .denied: motionStatus = "被拒绝"
        case .restricted: motionStatus = "受限"
        default: motionStatus = "待授权"
        }

        let start = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: start, to: Date()) { data, error in
            DispatchQueue.main.async {
                if error != nil {
                    motionStatus = "读取失败"
                    return
                }
                if let d = data {
                    store.pedometerSteps = d.numberOfSteps.intValue
                    if let dist = d.distance {
                        store.pedometerDistance = dist.doubleValue
                    }
                    if motionStatus == "待授权" { motionStatus = "已授权" }
                }
            }
        }
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
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)

                Text("用脉搏计数（数 30 秒 × 2），或直接读手表上的数")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)

                TextField("例如 72", text: $text)
                    .keyboardType(.numberPad)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.6))
                    }
                    .padding(.horizontal, 26)

                Button {
                    if let v = Int(text), v >= 30, v <= 220 {
                        onOK(v)
                        dismiss()
                    }
                } label: {
                    Text("保存")
                        .font(.system(size: 16, weight: .bold))
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
                        .font(.system(size: 11.5, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(TWColor.ink3)
                }
                TwGradientText(text: title, size: 30)
            }
            Spacer()
        }
    }
}

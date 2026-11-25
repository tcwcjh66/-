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

    private let pedometer = CMPedometer()

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "身体", subtitle: "本机实测 · 不含模拟数据")

            hrCard
            stepCard
            bodyCard
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
            BodySheet(w: $wText, h: $hText, waist: $waistText, goal: $goalText) { kg, height, waist, goal in
                if height > 0 { store.heightCM = height }
                if waist > 0 { store.waistCM = waist }
                if goal > 0 { store.weightGoal = goal }
                if kg > 0 { store.logWeight(kg) }
                store.persist()
            }
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
                showBody = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("记录体重 / 腰围")
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

    // MARK: - 饮水

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("饮水")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(store.waterCups) / \(store.waterTarget) 杯 · \(store.waterCups * 250) ml")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
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
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) { store.addWater() }
                } label: {
                    Text("+ 1 杯（250ml）")
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
                title: "快捷指令回传",
                detail: "twfit://hr?bpm=72&hrv=45",
                state: "需手动建一次",
                tint: TWColor.amber
            )

            Text("手表的数据只能经 HealthKit 或 WatchConnectivity 进入第三方 App，这两项都不在免费 Apple ID 的可签能力里。免费方案里最接近实时的是快捷指令定时读取健康数据再回传，延迟取决于自动化间隔。")
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

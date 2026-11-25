import SwiftUI

struct PulseView: View {
    @StateObject private var meter = PulseMeter()
    @Environment(\.dismiss) private var dismiss

    var onSave: (Int, Int) -> Void

    private var progress: Double {
        meter.duration > 0 ? min(meter.elapsed / meter.duration, 1) : 0
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.09),
                    Color(red: 0.13, green: 0.08, blue: 0.20),
                    Color(red: 0.07, green: 0.13, blue: 0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 8)

                bpmBlock

                waveCanvas
                    .frame(height: 110)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Text(meter.errorText ?? meter.quality)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(meter.errorText == nil ? TWColor.glass(0.62) : Color(red: 1.0, green: 0.55, blue: 0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 30)

                Spacer(minLength: 8)

                actionArea
            }
            .padding(.bottom, 12)
        }
        .onDisappear { meter.stop() }
    }

    private var topBar: some View {
        HStack {
            Button {
                meter.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.glass(0.85))
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(TWColor.glass(0.12))
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("指尖心率")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TWColor.glass(0.8))

            Spacer()

            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var bpmBlock: some View {
        ZStack {
            Circle()
                .stroke(TWColor.glass(0.10), lineWidth: 9)
                .frame(width: 232, height: 232)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color(red: 0.55, green: 0.92, blue: 0.78),
                                 Color(red: 0.62, green: 0.46, blue: 0.98),
                                 Color(red: 0.98, green: 0.55, blue: 0.72)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .frame(width: 232, height: 232)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                if meter.bpm > 0 {
                    Text("\(meter.bpm)")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text("--")
                        .font(.system(size: 64, weight: .heavy))
                        .foregroundStyle(TWColor.glass(0.4))
                }

                Text(meter.bpm > 0 ? "BPM" : (meter.running ? "测量中" : "未开始"))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(TWColor.glass(0.55))

                if meter.hrv > 0 {
                    Text("HRV \(meter.hrv) ms")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.55, green: 0.92, blue: 0.78).opacity(0.85))
                        .padding(.top, 2)
                }
            }
        }
    }

    private var waveCanvas: some View {
        GeometryReader { geo in
            let pts = meter.wave
            ZStack {
                if pts.count > 2 {
                    Path { p in
                        let w = geo.size.width
                        let h = geo.size.height
                        let stepX = w / CGFloat(max(pts.count - 1, 1))
                        for (i, v) in pts.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * 0.5 - CGFloat(v) * h * 0.40
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [
                            Color(red: 0.55, green: 0.92, blue: 0.78).opacity(0.9),
                            Color(red: 0.62, green: 0.46, blue: 0.98).opacity(0.9)
                        ], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                    )
                } else {
                    Capsule()
                        .fill(TWColor.glass(0.10))
                        .frame(height: 1.4)
                }
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            if meter.finished && meter.bpm > 0 {
                Button {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onSave(meter.bpm, meter.hrv)
                    dismiss()
                } label: {
                    Text("保存这次结果")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [
                                    Color(red: 0.42, green: 0.86, blue: 0.72),
                                    Color(red: 0.55, green: 0.36, blue: 0.96)
                                ], startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)

                Button("重测一次") {
                    meter.reset()
                    meter.start()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TWColor.glass(0.7))
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    if meter.running {
                        meter.stop()
                    } else {
                        meter.start()
                    }
                } label: {
                    Text(meter.running ? "停止测量" : "开始测量")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LinearGradient(colors: [
                                    Color(red: 0.55, green: 0.36, blue: 0.96),
                                    Color(red: 0.42, green: 0.62, blue: 0.98)
                                ], startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)

                Text("食指指腹轻盖后置镜头与闪光灯，别用力压，保持 30 秒不动")
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.glass(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }
}

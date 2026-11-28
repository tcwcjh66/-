import SwiftUI
import Combine
import CoreMotion

@main
struct TianCaiWeiWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHome()
        }
    }
}

struct WatchHome: View {
    @StateObject private var link = WatchLink.shared
    @State private var now = Date()
    @State private var steps = 0

    private let pedometer = CMPedometer()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var clock: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.07, blue: 0.16),
                    Color(red: 0.16, green: 0.10, blue: 0.24),
                    Color(red: 0.06, green: 0.15, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 5) {
                Text(clock)
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                HStack(spacing: 6) {
                    tile(value: link.hr > 0 ? "\(link.hr)" : "--",
                         unit: "心率",
                         tint: Color(red: 1.0, green: 0.42, blue: 0.52))
                    tile(value: "\(steps)",
                         unit: "步数",
                         tint: Color(red: 0.35, green: 0.62, blue: 1.0))
                }
                .padding(.horizontal, 6)

                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(link.day.isEmpty ? "今天还没排" : link.day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                        Text(link.active ? "已 \(link.sets) 组" : "未开练")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(link.active ? Color(red: 1.0, green: 0.55, blue: 0.35) : .white.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                    Button {
                        link.sendAddSet()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .heavy))
                            .frame(width: 34, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 1.0, green: 0.42, blue: 0.36))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
                .padding(.horizontal, 6)

                if link.waterTarget > 0 {
                    Text("水 \(link.water)/\(link.waterTarget) 杯")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(link.reachable ? Color(red: 0.20, green: 0.83, blue: 0.60) : Color.white.opacity(0.3))
                        .frame(width: 5, height: 5)
                    Text(link.reachable ? "手机已连" : (link.activated ? "等手机" : "未激活"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 2)
            }
        }
        .onReceive(tick) { now = $0 }
        .onAppear { loadSteps() }
    }

    private func tile(value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
                }
        }
    }

    private func loadSteps() {
        guard CMPedometer.isStepCountingAvailable() else { return }
        let start = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: start, to: Date()) { data, _ in
            DispatchQueue.main.async {
                if let d = data {
                    steps = d.numberOfSteps.intValue
                    WatchLink.shared.sendSteps(steps)
                }
            }
        }
    }
}

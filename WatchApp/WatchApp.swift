import SwiftUI
import Combine

@main
struct TianCaiWeiWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHome()
        }
    }
}

struct WatchHome: View {
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var clockText: String {
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
                Text(clockText)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                HStack(spacing: 12) {
                    metric(value: "46", unit: "HRV", tint: Color(red: 0.20, green: 0.83, blue: 0.60))
                    metric(value: "8,042", unit: "步数", tint: Color(red: 0.18, green: 0.42, blue: 1.0))
                }
                .padding(.horizontal, 10)

                HStack(spacing: 7) {
                    tabChip(icon: "circle.dotted", text: "表盘", on: true)
                    tabChip(icon: "heart", text: "HRV", on: false)
                    tabChip(icon: "timer", text: "训练", on: false)
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 6)
        }
        .onReceive(tick) { now = $0 }
    }

    private func metric(value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(unit)
                .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.6)
                }
        }
    }

    private func tabChip(icon: String, text: String, on: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(on ? .white : .white.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background {
            Capsule().fill(on ? Color.white.opacity(0.18) : Color.clear)
        }
    }
}

import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var store: TWStore
    @State private var tab: TWTab = .today

    var body: some View {
        ZStack(alignment: .bottom) {
            AuroraBG()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    switch tab {
                    case .today: TodayPage(onOpenFlow: {
                        withAnimation(.snappy(duration: 0.26)) { tab = .flow }
                    })
                    case .bio:   BioPage()
                    case .lib:   LibPage()
                    case .flow:  FlowPage()
                    case .diet:  DietPage()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 58)
                .padding(.bottom, 118)
            }
            .scrollBounceBehavior(.basedOnSize)

            GlassTabBar(selected: $tab)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
        }
        .background(AuroraBG())
        .ignoresSafeArea(edges: .bottom)
        .onOpenURL { url in
            handleIncoming(url)
        }
    }

    /// 快捷指令回传入口：twfit://hr?bpm=72&hrv=45
    private func handleIncoming(_ url: URL) {
        guard url.scheme == "twfit" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let raw = items.first(where: { $0.name == "bpm" })?.value,
           let bpm = Int(raw), bpm >= 30, bpm <= 220 {
            store.measuredHR = bpm
            store.hr = bpm
            store.measuredAt = Date()
            store.hrSource = "快捷指令"
        }

        if let raw = items.first(where: { $0.name == "hrv" })?.value,
           let hrv = Int(raw), hrv >= 0, hrv <= 300 {
            store.measuredHRV = hrv
            store.hrv = hrv
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy(duration: 0.28)) { tab = .bio }
    }
}

struct GlassTabBar: View {
    @Binding var selected: TWTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TWTab.allCases) { t in
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.26, extraBounce: 0.06)) {
                        selected = t
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(t.title)
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(t == selected ? TWColor.ink : TWColor.ink3)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .padding(.vertical, 8)
                    .background {
                        if t == selected {
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.78))
                                .shadow(color: TWColor.cardShadow, radius: 4, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .twGlass(radius: 29, tintAmount: 0.04)
    }
}

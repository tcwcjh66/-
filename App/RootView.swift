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
                    case .today: TodayPage()
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

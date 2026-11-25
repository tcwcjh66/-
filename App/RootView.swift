import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject var store: TWStore
    @State private var tab: TWTab = .today
    @AppStorage("tw.onboarded.v3") private var onboarded = false
    /// 手指在拖 / 惯性未停，逐帧动画据此暂停
    @State private var isScrolling = false
    @State private var scrollWork: DispatchWorkItem?

    var body: some View {
        Group {
            if onboarded {
                content
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) { onboarded = true }
                }
            }
        }
    }

    private var content: some View {
        ZStack(alignment: .bottom) {
            AuroraBG()
                .ignoresSafeArea()

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
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in markScrolling() }
            )

            GlassTabBar(selected: $tab)
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
        }
        .environment(\.twScrollPause, isScrolling)
        .ignoresSafeArea(edges: .bottom)
        .onOpenURL { url in
            handleIncoming(url)
        }
    }

    /// 拖动时暂停逐帧动画，手停下 0.45 秒后恢复（覆盖惯性减速阶段）
    private func markScrolling() {
        if !isScrolling { isScrolling = true }
        scrollWork?.cancel()
        let w = DispatchWorkItem { isScrolling = false }
        scrollWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: w)
    }

    /// 快捷指令回传入口：twfit://hr?bpm=72&hrv=45
    private func handleIncoming(_ url: URL) {
        guard url.scheme == "twfit" else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var dict: [String: String] = [:]
        for item in items {
            if let v = item.value, !v.isEmpty { dict[item.name.lowercased()] = v }
        }

        func val(_ keys: String...) -> Double? {
            for k in keys {
                if let s = dict[k], let d = Double(s) { return d }
            }
            return nil
        }

        var changed = false

        if let bpm = val("hr", "bpm"), bpm >= 25, bpm <= 230 {
            store.hr = Int(bpm)
            store.measuredHR = Int(bpm)
            store.measuredAt = Date()
            store.hrSource = "快捷指令"
            changed = true
        }
        if let hrv = val("hrv"), hrv >= 0, hrv <= 400 {
            store.hrv = Int(hrv)
            store.measuredHRV = Int(hrv)
            changed = true
        }
        if var o = val("spo2", "oxygen", "o2") {
            // 健康里的血氧是 0.98 这种小数，快捷指令有时直接给 0.98、有时给 98
            if o <= 1.5 { o = o * 100 }
            if o >= 60, o <= 100 {
                store.watchSpO2 = Int(o.rounded())
                store.watchSpO2At = Date()
                changed = true
            }
        }
        if let rhr = val("rhr", "restinghr"), rhr >= 25, rhr <= 200 {
            store.restingHR = Int(rhr)
            changed = true
        }
        if let s = val("steps"), s >= 0 {
            store.watchSteps = Int(s)
            changed = true
        }
        if let d = val("dist", "distance"), d >= 0 {
            store.pedometerDistance = d
            changed = true
        }
        if let k = val("kcal", "energy"), k >= 0 {
            store.moveKcal = k
            changed = true
        }
        if let e = val("exercise", "exerciseMin"), e >= 0 {
            store.exerciseMin = e
            changed = true
        }
        if let st = val("stand"), st >= 0 {
            store.standHours = st
            changed = true
        }
        if let sl = val("sleep"), sl > 0 {
            store.watchSleepMin = Int(sl)
            changed = true
        }
        if let dp = val("deep"), dp > 0 {
            store.watchDeepMin = Int(dp)
            changed = true
        }
        if let md = val("mind", "mindful"), md > 0 {
            store.mindfulMin = Int(md)
            store.mindfulAt = Date()
            store.mood = "calm"
            changed = true
        }

        if changed {
            store.watchSyncAt = Date()
            store.watchSyncCount += 1
            store.persist()
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.snappy(duration: 0.28)) { tab = .bio }
    }
}

struct GlassTabBar: View {
    @Binding var selected: TWTab

    var body: some View {
        if #available(iOS 26.0, *) {
            bar.glassEffect(.regular, in: .rect(cornerRadius: 29))
        } else {
            bar.twGlass(radius: 29, tintAmount: 0.04)
        }
    }

    private var bar: some View {
        HStack(spacing: 0) {
            ForEach(TWTab.allCases) { t in
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.26, extraBounce: 0.06)) {
                        selected = t
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text(t.emoji)
                            .font(.system(size: 23))
                            .frame(height: 25)
                            .scaleEffect(t == selected ? 1.08 : 1.0)
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
                                .fill(TWColor.glass(0.82))
                                .shadow(color: TWColor.cardShadow, radius: 4, y: 2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .contentShape(Rectangle())
    }
}

import SwiftUI
import UIKit
import Combine

struct RootView: View {
    @EnvironmentObject var store: TWStore
    @State private var tab: TWTab = .today
    @AppStorage("tw.onboarded.v3") private var onboarded = false
    /// 手指在拖 / 惯性未停，逐帧动画据此暂停
    @State private var isScrolling = false
    @State private var scrollWork: DispatchWorkItem?
    @Environment(\.scenePhase) private var scenePhase
    /// 应用锁：开启后切后台就上锁，回来先过 Face ID
    @State private var locked = false
    @State private var unlocking = false

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
        // 组件格子、长按图标、系统深链都从这里进来
        .onReceive(NotificationCenter.default.publisher(for: .twShortcut)) { note in
            go(to: (note.object as? String) ?? "")
        }
        .overlay {
            if store.lockEnabled && locked { lockScreen }
        }
        .animation(.easeInOut(duration: 0.22), value: locked)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, store.lockEnabled { locked = true }
        }
        .onAppear {
            if store.lockEnabled { locked = true; askUnlock() }
        }
    }

    /// 隐私锁：只挡界面，不动数据
    private var lockScreen: some View {
        ZStack {
            AuroraBG().ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.fill")
                    .font(.tw(30, .bold))
                    .foregroundStyle(TWColor.purple)
                    .frame(width: 76, height: 76)
                    .background { Circle().fill(TWColor.purple.opacity(0.12)) }
                Text("Persist 已锁")
                    .font(.tw(20, .heavy))
                    .foregroundStyle(TWColor.ink)
                Text(store.lockEnabled ? "训练、饮食、身体数据都在这儿，先验证一下" : "")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                Button {
                    askUnlock()
                } label: {
                    Text(unlocking ? "验证中…" : "用 Face ID 解锁")
                        .font(.tw(15, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 13)
                        .background {
                            Capsule().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                          startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)
                .disabled(unlocking)
            }
        }
        .transition(.opacity)
        .zIndex(10)
    }

    private func askUnlock() {
        guard !unlocking else { return }
        unlocking = true
        TWLock.unlock { ok in
            unlocking = false
            if ok { locked = false }
        }
    }

    /// 一处收口：深链、快捷动作都走这里，省得每个入口各写一遍
    private func go(to key: String) {
        switch key {
        case "water":
            store.addWater(1)
            withAnimation(.snappy(duration: 0.26)) { tab = .diet }
        case "meal":
            withAnimation(.snappy(duration: 0.26)) { tab = .diet }
        case "train":
            withAnimation(.snappy(duration: 0.26)) { tab = .flow }
        case "weight":
            withAnimation(.snappy(duration: 0.26)) { tab = .bio }
        case "tw.shortcut.water":
            store.addWater(1)
            withAnimation(.snappy(duration: 0.26)) { tab = .diet }
        case "tw.shortcut.train":
            withAnimation(.snappy(duration: 0.26)) { tab = .flow }
        case "tw.shortcut.weight":
            withAnimation(.snappy(duration: 0.26)) { tab = .bio }
        default:
            // 未知 host（比如快捷指令回传）不抢导航，留在当前页
            break
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

            if let u = store.undo {
                undoBar(u)
            }
        }
        .environment(\.twScrollPause, isScrolling)
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .twDeepLink)) { note in
            guard let cmd = note.object as? String else { return }
            withAnimation(.snappy(duration: 0.24)) {
                if cmd.hasPrefix("train") { tab = .flow }
                else if cmd.hasPrefix("diet") { tab = .diet }
                else if cmd.hasPrefix("bio") { tab = .bio }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .twSpotlight)) { note in
            guard let id = note.object as? String else { return }
            if id.hasPrefix("plan:") {
                let name = String(id.dropFirst("plan:".count))
                if let i = store.allPlans.firstIndex(where: { $0.name == name }) {
                    store.setPlan(i)
                }
            }
            withAnimation(.snappy(duration: 0.22)) {
                tab = id.hasPrefix("food:") ? .diet : .flow
            }
        }
        .onOpenURL { url in
            // 先让快捷指令回传（心率、睡眠）吃掉自己的参数，再交给页面路由
            handleIncoming(url)
            go(to: url.host ?? "")
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

        // 统一深链：twfit://train?start=1 / diet?photo=1 / bio?weight=1 / plan?name=...
        func post(_ s: String) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                NotificationCenter.default.post(name: .twDeepLink, object: s)
            }
        }
        let host = url.host ?? (url.path.hasPrefix("/") ? String(url.path.dropFirst()) : url.path)

        if host == "train" || dict["open"] == "train" {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.snappy(duration: 0.26)) { tab = .flow }
            if dict["start"] == "1" { post("train:start") }
            if let m = dict["move"], !m.isEmpty { post("train:move:\(m)") }
            return
        }
        if host == "diet" || dict["open"] == "diet" {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.snappy(duration: 0.26)) { tab = .diet }
            if dict["photo"] == "1" { post("diet:photo") }
            return
        }
        if host == "bio" || dict["open"] == "bio" {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.snappy(duration: 0.26)) { tab = .bio }
            if dict["weight"] == "1" { post("bio:weight") }
            return
        }
        if host == "plan" {
            if let name = dict["name"],
               let i = store.allPlans.firstIndex(where: { $0.name == name }) {
                store.setPlan(i)
            }
            withAnimation(.snappy(duration: 0.26)) { tab = .flow }
            return
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

extension RootView {
    /// 删除后的 6 秒反悔条，浮在底栏上方
    fileprivate func undoBar(_ u: TWUndoAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.tw(12, .bold))
                .foregroundStyle(.white.opacity(0.8))
            Text(u.text)
                .font(.tw(12.5, .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button {
                store.runUndo()
            } label: {
                Text("撤销")
                    .font(.tw(12.5, .heavy))
                    .foregroundStyle(TWColor.mint)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(.white.opacity(0.16)) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background { Capsule().fill(.black.opacity(0.68)) }
        .padding(.horizontal, 20)
        .padding(.bottom, 88)
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                            .font(.tw(23))
                            .frame(height: 25)
                            .scaleEffect(t == selected ? 1.08 : 1.0)
                        Text(t.title)
                            .font(.tw(12.5, .semibold))
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

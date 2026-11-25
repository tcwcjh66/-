import SwiftUI
import Combine

@main
struct TianCaiWeiApp: App {
    @StateObject private var store = TWStore()
    @Environment(\.scenePhase) private var scenePhase
    /// 前台每 5 分钟把当下数值写进今天这一格，这样没训练的日子图里也有点
    private let ticker = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(TWColor.purple)
                .onAppear {
                    PhoneLink.shared.store = store
                    PhoneLink.shared.pushToWatch()
                    TWNotify.reschedule()
                    // 免费签名 7 天，第 5 天提醒重装；中途重签过会自动重算
                    let install = TWSideload.touch()
                    TWNotify.scheduleExpiry(installAt: install)
                    StepLive.shared.bind(store)
                    StepLive.shared.start()
                    store.rollIfNewDay()
                    store.upsertToday()
                }
                .onReceive(ticker) { _ in
                    guard scenePhase == .active else { return }
                    store.upsertToday()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 回到前台：补一次历史 + 确保实时推送在跑
                    if phase == .active {
                        store.rollIfNewDay()
                        store.upsertToday()
                        StepLive.shared.start()
                        StepLive.shared.refresh()
                    }
                    else if phase == .background {
                        // 走之前把这天的最终步数落盘，否则切后台后的步数就丢了
                        store.upsertToday()
                        StepLive.shared.stop()
                    }
                }
        }
    }
}

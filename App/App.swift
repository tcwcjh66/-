import SwiftUI

@main
struct TianCaiWeiApp: App {
    @StateObject private var store = TWStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(TWColor.purple)
                .onAppear {
                    PhoneLink.shared.store = store
                    PhoneLink.shared.pushToWatch()
                    TWNotify.reschedule()
                    StepLive.shared.bind(store)
                    StepLive.shared.start()
                    store.rollIfNewDay()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 回到前台：补一次历史 + 确保实时推送在跑
                    if phase == .active {
                        store.rollIfNewDay()
                        StepLive.shared.start()
                        StepLive.shared.refresh()
                    }
                    else if phase == .background { StepLive.shared.stop() }
                }
        }
    }
}

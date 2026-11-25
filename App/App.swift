import SwiftUI

@main
struct TianCaiWeiApp: App {
    @StateObject private var store = TWStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(TWColor.purple)
                .onAppear {
                    PhoneLink.shared.store = store
                    PhoneLink.shared.pushToWatch()
                    TWNotify.reschedule()
                }
        }
    }
}

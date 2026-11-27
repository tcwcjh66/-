import UIKit

extension Notification.Name {
    /// 长按图标点快捷动作时广播出去，RootView 收到后切页
    static let twShortcut = Notification.Name("tw.shortcut")
}

/// SwiftUI 生命周期拿不到 shortcut 回调，挂一个轻量 delegate 专门接这个。
final class TWAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 冷启动时 RootView 还没订阅，稍等一下再广播
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                NotificationCenter.default.post(name: .twShortcut, object: item.type)
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        NotificationCenter.default.post(name: .twShortcut, object: shortcutItem.type)
        completionHandler(true)
    }
}

import UIKit
import UserNotifications
import CoreSpotlight

extension Notification.Name {
    /// 长按图标点快捷动作时广播出去，RootView 收到后切页
    static let twShortcut = Notification.Name("tw.shortcut")
    /// 从系统搜索点进来（Spotlight 命中动作或食物）
    static let twSpotlight = Notification.Name("tw.spotlight")
}

/// SwiftUI 生命周期拿不到 shortcut 和通知回调，挂一个轻量 delegate 专门接这两件事。
final class TWAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        TWNotify.registerCategories()

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

    /// 系统搜索点进来：move:xxx → 训练页，food:xxx → 饮食页
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == CSSearchableItemActionType,
              let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String else {
            return false
        }
        NotificationCenter.default.post(name: .twSpotlight, object: id)
        return true
    }
}

extension TWAppDelegate: UNUserNotificationCenterDelegate {
    /// 前台也把横幅放出来，否则训练中根本看不到提醒
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    /// 锁屏按钮：喝水直接记账，20 分钟后重弹；训练可以今天跳过或推明天
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "TW_WATER_DONE":
            Task { @MainActor in TWStore.shared.addWater(1) }

        case "TW_WATER_SNOOZE":
            let c = UNMutableNotificationContent()
            c.title = "该喝水了"
            c.body = "刚才推迟的那一杯，现在补上。"
            c.sound = .default
            c.categoryIdentifier = TWNotify.waterCategory
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 20 * 60, repeats: false)
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "tw.notif.req.water.snooze", content: c, trigger: trigger))

        case "TW_TRAIN_SKIP", "TW_TRAIN_TOMORROW":
            UserDefaults.standard.set(DateFormatter.twDay.string(from: Date()),
                                      forKey: "tw.trainSkipDay.v1")

        default:
            break
        }
        completionHandler()
    }
}

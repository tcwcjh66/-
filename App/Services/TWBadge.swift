import UIKit
import UserNotifications

/// 桌面图标上的小红点：今天还差几杯水。
/// 走 UNUserNotificationCenter 的角标接口（iOS 16+），没授权就静默不动。
enum TWBadge {
    private static let key = "tw.badge.on.v1"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// 差 0 杯就把角标清掉
    static func refresh(left: Int) {
        guard isOn else {
            clear()
            return
        }
        let c = UNUserNotificationCenter.current()
        c.getNotificationSettings { s in
            let ok = s.authorizationStatus == .authorized
                || s.authorizationStatus == .provisional
                || s.authorizationStatus == .ephemeral
            c.setBadgeCount(ok ? max(0, left) : 0) { _ in }
        }
    }

    static func clear() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
}

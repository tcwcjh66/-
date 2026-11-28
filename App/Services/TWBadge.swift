import UIKit
import UserNotifications

/// 桌面图标上的小红点：今天还差几杯水。
/// 角标要通知权限，没授权就什么都不做，不报错。
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
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let ok = s.authorizationStatus == .authorized
                || s.authorizationStatus == .provisional
                || s.authorizationStatus == .ephemeral
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconItemNumber = ok ? max(0, left) : 0
            }
        }
    }

    static func clear() {
        UIApplication.shared.applicationIconItemNumber = 0
    }
}

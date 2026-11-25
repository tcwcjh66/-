import Foundation
import UserNotifications

/// 本地提醒：喝水 / 训练 / 称重 / 睡前记录。
/// 全部用 UNCalendarNotificationTrigger 每天重复，不联网、不需要任何 entitlement。
enum TWNotify {
    enum Kind: String, CaseIterable, Identifiable {
        case water, train, weigh, sleep

        var id: String { rawValue }

        var label: String {
            switch self {
            case .water: return "喝水"
            case .train: return "训练"
            case .weigh: return "称体重"
            case .sleep: return "睡前记录"
            }
        }

        var icon: String {
            switch self {
            case .water: return "drop.fill"
            case .train: return "figure.strengthtraining.traditional"
            case .weigh: return "scalemass.fill"
            case .sleep: return "moon.zzz.fill"
            }
        }

        var detail: String {
            switch self {
            case .water: return "每天 10:00 · 14:00 · 16:30 · 20:00"
            case .train: return "每天 19:00"
            case .weigh: return "每天 07:30"
            case .sleep: return "每天 22:30"
            }
        }

        var body: String {
            switch self {
            case .water: return "端起杯子喝几口。今天的水还差多少？"
            case .train: return "15 分钟也能补一组，练完记得点结束。"
            case .weigh: return "空腹上秤，记一笔体重，趋势才有意义。"
            case .sleep: return "记下今晚的睡眠，明天能看到恢复情况。"
            }
        }
    }

    private static func key(_ k: Kind) -> String { "tw.notif." + k.rawValue }

    static func isOn(_ k: Kind) -> Bool {
        UserDefaults.standard.bool(forKey: key(k))
    }

    static func set(_ k: Kind, _ on: Bool) {
        UserDefaults.standard.set(on, forKey: key(k))
    }

    static func anyOn() -> Bool {
        Kind.allCases.contains { isOn($0) }
    }

    /// 申请通知权限；已拒绝就返回 false，界面据此提示去系统设置里打开。
    @discardableResult
    static func requestPermission() async -> Bool {
        let c = UNUserNotificationCenter.current()
        let settings = await c.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await c.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func denied() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .denied
    }

    /// 按当前开关重排全部提醒。改开关后调一次，App 启动也调一次。
    static func reschedule() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: allIDs())
        guard anyOn() else { return }

        if isOn(.water) {
            for (i, hm) in [(10, 0), (14, 0), (16, 30), (20, 0)].enumerated() {
                add(id: "water-\(i)", kind: .water, hour: hm.0, minute: hm.1)
            }
        }
        if isOn(.train) { add(id: "train", kind: .train, hour: 19, minute: 0) }
        if isOn(.weigh) { add(id: "weigh", kind: .weigh, hour: 7, minute: 30) }
        if isOn(.sleep) { add(id: "sleep", kind: .sleep, hour: 22, minute: 30) }
    }

    private static func add(id: String, kind: Kind, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = kind.label
        content.body = kind.body
        content.sound = .default
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "tw.notif.req." + id, content: content, trigger: trigger)
        )
    }

    private static func allIDs() -> [String] {
        var ids: [String] = []
        for i in 0..<4 { ids.append("tw.notif.req.water-\(i)") }
        ids += ["tw.notif.req.train", "tw.notif.req.weigh", "tw.notif.req.sleep"]
        return ids
    }
}

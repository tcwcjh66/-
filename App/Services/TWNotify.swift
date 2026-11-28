import Foundation
import UserNotifications
import AudioToolbox

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
    /// 训练进行中：喝水、称重这类定时提醒先撤掉，别在组间轰炸
    static func suspendForTraining() {
        let c = UNUserNotificationCenter.current()
        let keep = Set(restIDs)
        let ids = allIDs().filter { !keep.contains($0) }
        guard !ids.isEmpty else { return }
        c.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// 练完把撤掉的提醒按原样排回来
    static func resumeAfterTraining() {
        reschedule()
    }

    static func reschedule() {
        registerCategories()
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

    // MARK: - 锁屏按钮

    static let waterCategory = "TW_WATER"
    static let trainCategory = "TW_TRAIN"
    static let restCategory = "TW_REST"
    private static var restIDs: [String] { [restID] }

    /// 注册带按钮的通知分类，锁屏上能直接处理，不用先解锁
    static func registerCategories() {
        let drank = UNNotificationAction(identifier: "TW_WATER_DONE", title: "已喝一杯",
                                         options: [.authenticationRequired])
        let later = UNNotificationAction(identifier: "TW_WATER_SNOOZE", title: "20 分钟后", options: [])
        let water = UNNotificationCategory(identifier: waterCategory,
                                           actions: [drank, later],
                                           intentIdentifiers: [], options: [])
        let skip = UNNotificationAction(identifier: "TW_TRAIN_SKIP", title: "今天不练", options: [])
        let tomorrow = UNNotificationAction(identifier: "TW_TRAIN_TOMORROW", title: "推迟到明天", options: [])
        let start = UNNotificationAction(identifier: "TW_TRAIN_START", title: "现在开始", options: [.foreground])
        let train = UNNotificationCategory(identifier: trainCategory,
                                           actions: [start, skip, tomorrow],
                                           intentIdentifiers: [], options: [])
        let again = UNNotificationAction(identifier: "TW_REST_AGAIN", title: "再歇 30 秒", options: [])
        let next = UNNotificationAction(identifier: "TW_REST_NEXT", title: "开始下一组", options: [.foreground])
        let rest = UNNotificationCategory(identifier: restCategory,
                                          actions: [again, next], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([water, train, rest])
    }

    private static func add(id: String, kind: Kind, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = kind.label
        content.body = kind.body
        content.sound = .default
        if kind == .water { content.categoryIdentifier = waterCategory }
        if kind == .train { content.categoryIdentifier = trainCategory }
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

    // MARK: - 备份提醒

    private static let backupID = "tw.notif.req.backup"
    private static let nudgeKey = "tw.backupNudged.v1"

    /// 超过 14 天没导出，明天 9:00 提醒一次；7 天内不重复骚扰。
    static func scheduleBackup(lastExport: Date?, hasData: Bool) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [backupID])
        guard hasData else { return }

        let days: Int
        if let d = lastExport {
            days = Int(floor(max(0, Date().timeIntervalSince(d)) / 86400))
        } else {
            days = 999
        }
        guard days >= 14 else { return }

        let nudged = UserDefaults.standard.double(forKey: nudgeKey)
        if nudged > 0, Date().timeIntervalSince1970 - nudged < 7 * 86400 { return }

        let cal = Calendar.current
        var at = cal.dateComponents([.year, .month, .day], from: Date())
        at.hour = 9
        at.minute = 0
        guard let today9 = cal.date(from: at),
              let fire = cal.date(byAdding: .day, value: 1, to: today9) else { return }

        let content = UNMutableNotificationContent()
        content.title = "该备份了"
        content.body = days == 999
            ? "还没导出过。设置 → 数据 → 导出全部数据，存一份 JSON 到「文件」，重装时能一键恢复。"
            : "上次导出是 \(days) 天前。导一份 JSON 到「文件」，万一重装失败也捡得回来。"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(60, fire.timeIntervalSinceNow), repeats: false)
        c.add(UNNotificationRequest(identifier: backupID, content: content, trigger: trigger))
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: nudgeKey)
    }

    static func cancelBackup() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [backupID])
    }

    // MARK: - 签名到期

    private static let expiryID = "tw.notif.req.expiry"

    /// 第 5 天 9:00 推一次「该重装了」。一次性通知，不重复。
    static func scheduleExpiry(installAt: Date) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [expiryID])
        let cal = Calendar.current
        var day = cal.dateComponents([.year, .month, .day], from: installAt)
        day.hour = 0
        day.minute = 0
        guard let base = cal.date(from: day),
              let fire = cal.date(byAdding: .day, value: 5, to: base) else { return }
        var at = cal.dateComponents([.year, .month, .day], from: fire)
        at.hour = 9
        at.minute = 0
        guard let fireDate = cal.date(from: at), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "免费签名还剩 2 天"
        content.body = "这次安装到第 5 天了。连数据线用 Sideloadly 重装一遍就行，记录都在，不会丢。"
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: at, repeats: false)
        c.add(UNNotificationRequest(identifier: expiryID, content: content, trigger: trigger))
    }

    static func cancelExpiry() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [expiryID])
    }

    // MARK: - 智能提醒（按真实节奏重排，每次打开 App 刷一遍）

    private static let smartPlanPrefix = "tw.notif.req.smart.plan."
    private static let smartGapID = "tw.notif.req.smart.gap"
    private static let smartWeekID = "tw.notif.req.smart.week"

    /// 训练日提前两小时、断练三天、周日还差几次。
    /// 这三条都跟着真实数据走，不用用户再手动设一遍。
    static func rescheduleSmart(planWeekdays: Set<Int>,
                                gapDays: Int,
                                weeklyDone: Int,
                                weeklyGoal: Int,
                                trainHour: Int = 19,
                                hasData: Bool) {
        let c = UNUserNotificationCenter.current()
        var old: [String] = []
        for w in 1...7 { old.append(smartPlanPrefix + "\(w)") }
        old += [smartGapID, smartWeekID]
        c.removePendingNotificationRequests(withIdentifiers: old)

        guard hasData else { return }

        // 训练日：提前两小时
        var fireHour = trainHour - 2
        if fireHour < 0 { fireHour += 24 }
        for w in planWeekdays {
            let content = UNMutableNotificationContent()
            content.title = "今天排了训练"
            content.body = "两小时后开始（\(trainHour):00）。先把动作过一遍，组间别拖太长。"
            content.sound = .default
            var comps = DateComponents()
            comps.weekday = w
            comps.hour = fireHour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            c.add(UNNotificationRequest(identifier: smartPlanPrefix + "\(w)",
                                        content: content, trigger: trigger))
        }

        // 断练：明天 19:30 一次性提醒
        if gapDays >= 3 && gapDays < 999 {
            let content = UNMutableNotificationContent()
            content.title = "已经 \(gapDays) 天没练"
            content.body = "哪怕二十分钟，两组深蹲加一组俯卧撑也算续上。"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: secondsUntilTomorrow(hour: 19, minute: 30), repeats: false)
            c.add(UNNotificationRequest(identifier: smartGapID, content: content, trigger: trigger))
        }

        // 周日 18:00 提醒本周还差几次（已达标就不排）
        if weeklyDone < weeklyGoal {
            let content = UNMutableNotificationContent()
            content.title = "本周还差 \(weeklyGoal - weeklyDone) 次"
            content.body = "今天是这周最后一天，补一次这周就完整了。"
            content.sound = .default
            var comps = DateComponents()
            comps.weekday = 1
            comps.hour = 18
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            c.add(UNNotificationRequest(identifier: smartWeekID, content: content, trigger: trigger))
        }
    }

    private static func secondsUntilTomorrow(hour: Int, minute: Int) -> TimeInterval {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return 3600 }
        var comps = cal.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = minute
        guard let at = cal.date(from: comps) else { return 3600 }
        return max(60, at.timeIntervalSinceNow)
    }

    // MARK: - 组间休息

    private static let restID = "tw.notif.req.rest"

    /// 开始休息时约一条一次性通知：锁屏、切后台、App 被杀都能响。
    static func scheduleRest(after sec: Int, move: String) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: [restID])
        guard sec > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "休息结束"
        content.body = move.isEmpty ? "该下一组了。" : "\(move) 的休息结束了，该下一组。"
        content.sound = .default
        content.categoryIdentifier = restCategory
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(sec)), repeats: false)
        c.add(UNNotificationRequest(identifier: restID, content: content, trigger: trigger))
    }

    static func cancelRest() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [restID])
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [restID])
    }

    /// App 在前台时系统不弹横幅，自己响一声 + 震两下。
    static func playRestAlert() {
        AudioServicesPlaySystemSound(1005)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

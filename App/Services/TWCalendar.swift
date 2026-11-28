import Foundation
import EventKit

/// 练完在系统日历留一条：哪天、什么方案、几组、多少吨位。
/// 免费签名可以写日历（只需要用户点一次允许），不需要额外 entitlement。
enum TWCalendar {
    private static let key = "tw.calendar.on.v1"
    private static let store = EKEventStore()

    /// 开关，默认关——写日历要先问用户一次，别上来就弹
    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func requestAccess() async -> Bool {
        guard isOn else { return false }
        if #available(iOS 17.0, *) {
            return (try? await store.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            return (try? await store.requestAccess(to: .event)) ?? false
        }
    }

    /// 结算时调用。同一时间段已有 Persist 的事件就更新，不重复写。
    static func log(plan: String, day: String, sets: Int, minutes: Int, tonnage: Double) {
        guard isOn, sets > 0, minutes >= 1 else { return }
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .authorized || status == .writeOnly else { return }

        let cal = Calendar.current
        let end = Date()
        let start = cal.date(byAdding: .minute, value: -minutes, to: end) ?? end

        let e = EKEvent(eventStore: store)
        e.calendar = store.defaultCalendarForNewEvents
        e.title = "训练 · \(day.isEmpty ? plan : day)"
        var lines = ["\(sets) 组 · \(minutes) 分钟"]
        if tonnage > 0 { lines.append("总量 \(Int(tonnage)) kg") }
        if !plan.isEmpty { lines.append(plan) }
        e.notes = lines.joined(separator: "\n")
        e.startDate = start
        e.endDate = end
        e.url = URL(string: "twfit://train")
        try? store.save(e, span: .thisEvent)
    }
}

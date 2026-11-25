import Foundation

/// 免费签名只有 7 天。记一下这次安装是什么时候签的，
/// 好在第 5 天提醒重装，别等某天早上打开直接闪退。
enum TWSideload {
    private static let key = "tw.installAt.v1"
    /// 超过这个天数还能启动，说明中间重签过一次（UserDefaults 跟着数据留着，时间戳是旧的）
    private static let staleDays: Double = 7.2

    static var installAt: Date {
        let t = UserDefaults.standard.double(forKey: key)
        return t > 0 ? Date(timeIntervalSince1970: t) : Date()
    }

    /// 每次启动调一次。返回本次签名周期的起点。
    @discardableResult
    static func touch() -> Date {
        let t = UserDefaults.standard.double(forKey: key)
        let now = Date()
        if t <= 0 {
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key)
            return now
        }
        let old = Date(timeIntervalSince1970: t)
        if now.timeIntervalSince(old) > staleDays * 86400 {
            // 早就过了 7 天还开着 → 中途重装过，周期重算
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key)
            return now
        }
        return old
    }

    /// 手动重置（设置里点「我刚重装过」）
    @discardableResult
    static func reset() -> Date {
        let now = Date()
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: key)
        return now
    }

    static var daysUsed: Int {
        Int(floor(max(0, Date().timeIntervalSince(installAt)) / 86400))
    }

    static var daysLeft: Int {
        max(0, 7 - daysUsed)
    }

    static var dayText: String {
        "第 \(daysUsed + 1) 天 · 约剩 \(daysLeft) 天"
    }
}

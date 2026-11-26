import Foundation

/// 本机环形日志：只留最近 300 条，出问题能看见发生过什么。
/// 不联网、不上传，只存在 UserDefaults 里，体积很小。
enum TWLog {
    private static let key = "tw.log.v1"
    private static let limit = 300
    private static let lock = NSLock()

    static func add(_ tag: String, _ msg: String) {
        lock.lock()
        defer { lock.unlock() }
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        list.append("\(f.string(from: Date())) [\(tag)] \(msg)")
        if list.count > limit {
            list.removeFirst(list.count - limit)
        }
        UserDefaults.standard.set(list, forKey: key)
    }

    static var recent: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static var text: String {
        let l = recent
        return l.isEmpty ? "还没有日志。" : l.joined(separator: "\n")
    }

    static func clear() {
        lock.lock()
        defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: key)
    }
}

import Foundation

/// 自动备份：一天一次，把整份 JSON 落到 Documents/twbackup/，只留最近 3 份。
/// UserDefaults 由系统统一管，万一被清理或损坏，靠这里捡回历史。
enum TWBackup {
    private static let q = DispatchQueue(label: "tw.backup", qos: .utility)
    private static let dayKey = "tw.backup.lastDay.v1"

    static func dir() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("twbackup", isDirectory: true)
    }

    /// build 只在真的要备份那天才会执行，平时不做多余的序列化
    static func maybeAutoBackup(build: @escaping () -> String,
                                done: @escaping (String?) -> Void) {
        let today = DateFormatter.twDay.string(from: Date())
        if UserDefaults.standard.string(forKey: dayKey) == today { return }
        UserDefaults.standard.set(today, forKey: dayKey)
        let text = build()

        q.async {
            var err: String? = nil
            do {
                let d = dir()
                try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                let f = d.appendingPathComponent("tw-\(today).json")
                try text.data(using: .utf8)?.write(to: f, options: .atomic)
                prune()
            } catch {
                err = "自动备份没写成：\(error.localizedDescription)"
            }
            DispatchQueue.main.async { done(err) }
        }
    }

    /// 导入前的一次性快照：名字带 before-import，与日常自动备份区分开。
    /// 恢复错了还能拿它回滚。
    static func writeNow(build: String) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "tw-before-import-\(f.string(from: Date())).json"
        q.async {
            do {
                let d = dir()
                try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
                try build.data(using: .utf8)?.write(to: d.appendingPathComponent(name), options: .atomic)
                TWLog.add("backup", "导入前快照 → \(name)")
            } catch {
                TWLog.add("backup", "导入前快照失败：\(error.localizedDescription)")
            }
        }
    }

    private static func prune() {
        guard let fs = try? FileManager.default.contentsOfDirectory(
            at: dir(),
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }

        let sorted = fs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }
        for f in sorted.dropFirst(5) {
            try? FileManager.default.removeItem(at: f)
        }
    }
}

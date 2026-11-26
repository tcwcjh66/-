import Foundation

/// Application Support 下的分文件存储。
///
/// 大数组不该塞 UserDefaults：那玩意儿每次 set 都要整块序列化，
/// 几百条饮食记录之后，改一条就要在主线程重编码全部。
/// 这里一类型一个文件、原子写，坏一个不会连带全部。
enum TWFiles {
    private static let queue = DispatchQueue(label: "tw.files.io", qos: .utility)

    static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let d = base.appendingPathComponent("twdata", isDirectory: true)
        if !FileManager.default.fileExists(atPath: d.path) {
            try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        }
        return d
    }

    static func url(_ name: String) -> URL {
        dir.appendingPathComponent(name)
    }

    @discardableResult
    static func write<T: Encodable>(_ value: T, name: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            TWLog.add("files", "编码 \(name) 失败")
            return false
        }
        do {
            try data.write(to: url(name), options: .atomic)
            return true
        } catch {
            TWLog.add("files", "写 \(name) 失败：\(error.localizedDescription)")
            return false
        }
    }

    /// 持久化不占主线程：值先捕获成快照，扔到串行队列里写
    static func writeAsync<T: Encodable>(_ value: T, name: String) {
        queue.async {
            _ = write(value, name: name)
        }
    }

    static func read<T: Decodable>(_ name: String, as: T.Type) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            TWLog.add("files", "读 \(name) 失败：\(error.localizedDescription)")
            return nil
        }
    }

    static func removeAll() {
        queue.sync {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)) ?? []
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }
}

import Foundation

/// 闪退留痕：异常和常见的几个致命信号都写一个标记文件，下次启动记进日志。
/// 免费签名下没法看崩溃后台，这个文件就是唯一的现场。
enum TWCrashGuard {
    private static var pathC: UnsafeMutablePointer<CChar>?

    static var markerURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tw.lastcrash")
    }

    static func install() {
        pathC = strdup(markerURL.path)
        NSSetUncaughtExceptionHandler { ex in
            let body = """
            \(Date())
            \(ex.name.rawValue)
            \(ex.reason ?? "")
            \(ex.callStackSymbols.prefix(24).joined(separator: "\n"))
            """
            try? body.write(to: TWCrashGuard.markerURL, atomically: true, encoding: .utf8)
        }

        // 信号处理里只能用 async-signal-safe 的 open/write/close
        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
            signal(sig) { s in
                if let p = TWCrashGuard.pathC {
                    let fd = open(p, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
                    if fd >= 0 {
                        let msg = "signal \(s)\n"
                        _ = msg.withCString { write(fd, $0, strlen($0)) }
                        close(fd)
                    }
                }
                exit(s)
            }
        }
    }

    /// 启动时调一次：有标记就记日志、留时间戳，然后删掉，避免下次误报
    static func checkLastCrash() {
        guard let text = try? String(contentsOf: markerURL, encoding: .utf8), !text.isEmpty else { return }
        try? FileManager.default.removeItem(at: markerURL)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "tw.lastCrashAt.v1")
        TWLog.add("crash", "上次异常退出 · " + text.replacingOccurrences(of: "\n", with: " | "))
    }
}

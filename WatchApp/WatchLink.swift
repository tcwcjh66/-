import Foundation
import WatchConnectivity

/// 手表侧：接收手机推来的心率，回传自己的步数。不依赖 HealthKit。
final class WatchLink: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchLink()

    @Published var hr = 0
    @Published var hrv = 0
    @Published var phoneSteps = 0
    @Published var activated = false
    @Published var reachable = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSteps(_ steps: Int) {
        let s = WCSession.default
        guard s.activationState == .activated else { return }
        let p: [String: Any] = ["watchSteps": steps, "at": Date().timeIntervalSince1970]
        try? s.updateApplicationContext(p)
        if s.isReachable {
            s.sendMessage(p, replyHandler: nil) { _ in }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.activated = activationState == .activated
            self.reachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.reachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    private func apply(_ d: [String: Any]) {
        DispatchQueue.main.async {
            if let v = d["hr"] as? Int { self.hr = v }
            if let v = d["hrv"] as? Int { self.hrv = v }
            if let v = d["steps"] as? Int { self.phoneSteps = v }
        }
    }
}

import Foundation
import WatchConnectivity

/// 手表侧：接收手机推来的心率，回传自己的步数。不依赖 HealthKit。
final class WatchLink: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchLink()

    @Published var hr = 0
    @Published var hrv = 0
    @Published var phoneSteps = 0
    @Published var plan = ""
    @Published var day = ""
    @Published var sets = 0
    @Published var active = false
    @Published var water = 0
    @Published var waterTarget = 0
    @Published var activated = false
    @Published var reachable = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// 训练中抬手点一下，手机补记一组
    func sendAddSet() {
        let s = WCSession.default
        guard s.activationState == .activated else { return }
        let p: [String: Any] = ["addSet": 1, "at": Date().timeIntervalSince1970]
        if s.isReachable {
            s.sendMessage(p, replyHandler: nil) { _ in }
        }
        try? s.updateApplicationContext(["addSet": 1, "at": Date().timeIntervalSince1970])
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
            if let v = d["plan"] as? String { self.plan = v }
            if let v = d["day"] as? String { self.day = v }
            if let v = d["sets"] as? Int { self.sets = v }
            if let v = d["active"] as? Int { self.active = v > 0 }
            if let v = d["water"] as? Int { self.water = v }
            if let v = d["waterTarget"] as? Int { self.waterTarget = v }
        }
    }
}

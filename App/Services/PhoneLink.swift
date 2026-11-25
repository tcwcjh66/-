import Foundation
import WatchConnectivity

/// iPhone 侧：与手表双向对讲。不依赖 HealthKit。
final class PhoneLink: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneLink()

    @Published var paired = false
    @Published var installed = false
    @Published var reachable = false
    @Published var activated = false

    weak var store: TWStore?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func refresh() {
        let s = WCSession.default
        DispatchQueue.main.async {
            self.activated = s.activationState == .activated
            self.paired = s.isPaired
            self.installed = s.isWatchAppInstalled
            self.reachable = s.isReachable
        }
    }

    /// 把手机测到的心率推给手表
    func pushToWatch() {
        guard let store else { return }
        let s = WCSession.default
        guard s.activationState == .activated else { return }

        let payload: [String: Any] = [
            "hr": store.measuredHR,
            "hrv": store.measuredHRV,
            "steps": store.pedometerSteps,
            "at": Date().timeIntervalSince1970
        ]

        try? s.updateApplicationContext(payload)
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { _ in }
        }
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        refresh()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        refresh()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        refresh()
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    private func apply(_ d: [String: Any]) {
        DispatchQueue.main.async {
            if let v = d["watchSteps"] as? Int, v > 0 {
                self.store?.watchSteps = v
            }
        }
    }
}

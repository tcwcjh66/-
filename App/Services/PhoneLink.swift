import Foundation
import WatchConnectivity
import UIKit

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

        let plans = store.allPlans
        let pi = min(max(store.planPick, 0), max(plans.count - 1, 0))
        let tpl = plans[pi]
        let di = min(max(store.dayPick, 0), max(tpl.days.count - 1, 0))
        let day = tpl.days[di]

        let payload: [String: Any] = [
            "hr": store.measuredHR,
            "hrv": store.measuredHRV,
            "steps": store.pedometerSteps,
            "plan": tpl.name,
            "day": day.title,
            "sets": store.sessionSets,
            "active": store.sessionStart == nil ? 0 : 1,
            "water": store.waterCups,
            "waterTarget": store.waterTarget,
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
            if let add = d["addSet"] as? Int, add > 0 {
                self.addSetFromWatch()
            }
        }
    }

    /// 手表点「+1 组」：按当前动作的上一次重量/次数补一组，没开练就直接开
    private func addSetFromWatch() {
        guard let s = store else { return }
        let plans = s.allPlans
        let pi = min(max(s.planPick, 0), max(plans.count - 1, 0))
        let tpl = plans[pi]
        let di = min(max(s.dayPick, 0), max(tpl.days.count - 1, 0))
        let moves = tpl.days[di].items.map(\.name)
        if s.sessionStart == nil { s.startSession(moves: moves) }
        let name = s.sessionMoves.first ?? moves.first ?? "训练"
        let last = s.lastRecord(move: name)
        s.addSet(weight: last?.weight ?? 20, reps: last?.reps ?? 8,
                 move: name, rir: last?.rir ?? 2)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        pushToWatch()
    }
}

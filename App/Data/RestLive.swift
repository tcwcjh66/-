import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// 训练实况：训练一进来就挂一张卡，休息时在同一张卡上切成倒计时。
/// 全程本地起停，不依赖推送服务，也不需要任何 entitlement。
enum TWRestLive {
    /// 当前有没有在跑，避免重复起
    private(set) static var running = false

    private static var active: Activity<TWRestAttributes>? {
        Activity<TWRestAttributes>.activities.first
    }

    /// 训练开始：「训练中 · 第 1 组」的常驻卡
    static func begin(plan: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard active == nil else { return }
        let state = TWRestAttributes.ContentState(endAt: Date(), total: 0,
                                                  phase: "training", setNo: 1)
        do {
            _ = try Activity.request(
                attributes: TWRestAttributes(plan: plan),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            running = true
        } catch {
            running = false
        }
    }

    /// 记完一组：把卡上的组号往前推，不打断正在走的休息
    static func setProgress(_ setNo: Int, done: Int = 0, total: Int = 0) {
        guard running, let a = active else { return }
        let state = TWRestAttributes.ContentState(endAt: Date(), total: 0,
                                                  phase: "training", setNo: setNo,
                                                  planDone: done, planTotal: total)
        Task { await a.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// 组间休息：优先复用已有的训练卡，没有就新建一张
    static func start(seconds: Int, move: String, next: String, setNo: Int = 0,
                      done: Int = 0, total: Int = 0) {
        guard seconds > 0 else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = TWRestAttributes.ContentState(
            endAt: Date().addingTimeInterval(Double(seconds)),
            total: seconds, phase: "rest", setNo: setNo, move: move, next: next,
            planDone: done, planTotal: total
        )
        let content = ActivityContent(state: state, staleDate: state.endAt)

        if let a = active {
            running = true
            Task { await a.update(content) }
            return
        }
        do {
            _ = try Activity.request(attributes: TWRestAttributes(plan: ""),
                                     content: content, pushType: nil)
            running = true
        } catch {
            running = false
        }
    }

    static func endAll() {
        running = false
        Task {
            for a in Activity<TWRestAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif

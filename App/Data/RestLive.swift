import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// 组间休息的实况活动：锁屏和灵动岛显示倒计时，不用解锁看手机。
/// 全程本地起停，不依赖推送服务，也不需要任何 entitlement。
enum TWRestLive {
    /// 当前有没有在跑，避免重复起
    private(set) static var running = false

    static func start(seconds: Int, move: String, next: String) {
        guard seconds > 0 else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()
        let state = TWRestAttributes.ContentState(
            endAt: Date().addingTimeInterval(Double(seconds)),
            total: seconds
        )
        let content = ActivityContent(state: state, staleDate: state.endAt)
        do {
            _ = try Activity.request(
                attributes: TWRestAttributes(move: move, next: next),
                content: content,
                pushType: nil
            )
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

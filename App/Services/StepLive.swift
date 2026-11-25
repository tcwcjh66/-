import Foundation
import CoreMotion
import Combine

/// 实时计步。
///
/// 之前只在页面出现时 query 一次：query 拿的是系统缓存的当时快照，
/// 手动刷新时经常返回同一个旧数字，看起来"点了没反应"。
/// 现在改成两条路：query 补齐今日累计 + startUpdates 持续接收系统推送，
/// 步数一变就写回 Store，全局实时。
final class StepLive: ObservableObject {
    static let shared = StepLive()

    private let pedometer = CMPedometer()
    private var liveRunning = false

    /// 给界面看的采集状态
    @Published private(set) var status: String = "未启动"
    @Published private(set) var lastUpdate: Date? = nil

    // 写回节流：Store 一变，五个页面的 body 全都要重算。
    // 走 8 步（约 6 秒）或过了 15 秒才写一次，视觉上还是实时，重绘少九成。
    private var lastWrittenSteps = 0
    private var lastWriteAt = Date.distantPast
    private var lastStatusAt = Date.distantPast

    weak var store: TWStore?

    private init() {}

    func bind(_ s: TWStore) { store = s }

    private var todayStart: Date { Calendar.current.startOfDay(for: Date()) }

    /// 启动：先 query 补齐历史，再挂上实时推送
    func start() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = "此设备不支持计步"
            return
        }

        let auth = CMPedometer.authorizationStatus()
        if auth == .denied || auth == .restricted {
            status = auth == .denied ? "运动权限被拒绝" : "运动权限受限"
            return
        }

        queryOnce(reason: "启动补齐") { [weak self] in
            self?.startUpdates()
        }
    }

    /// 手动刷新：强制重查一次，并保证实时推送仍然在跑
    func refresh() {
        guard CMPedometer.isStepCountingAvailable() else {
            status = "此设备不支持计步"
            return
        }
        status = "正在读取…"
        queryOnce(reason: "手动刷新") { [weak self] in
            self?.startUpdates()
        }
    }

    /// 切后台时停掉，省电
    func stop() {
        pedometer.stopUpdates()
        liveRunning = false
    }

    // MARK: - 内部

    private func queryOnce(reason: String, done: @escaping () -> Void) {
        let start = todayStart
        pedometer.queryPedometerData(from: start, to: Date()) { [weak self] data, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let d = data {
                    // 只增不减：iOS 偶尔返回缓存旧值，倒退会让用户以为刷新失败
                    let steps = d.numberOfSteps.intValue
                    let current = self.store?.pedometerSteps ?? 0
                    if steps > current {
                        self.store?.pedometerSteps = steps
                        self.lastWrittenSteps = steps
                        self.lastWriteAt = Date()
                    } else if steps < current {
                        // 保持较大值，避免"刷新后数字变小"
                        self.store?.pedometerSteps = current
                    }
                    if let dist = d.distance {
                        let m = dist.doubleValue
                        if m > (self.store?.pedometerDistance ?? 0) {
                            self.store?.pedometerDistance = m
                        }
                    }
                    self.status = "已更新 \(steps) 步"
                    self.lastUpdate = Date()
                } else {
                    self.status = error == nil ? "暂无步数数据" : "读取失败，稍后再试"
                }
                done()
            }
        }
    }

    private func startUpdates() {
        guard !liveRunning else { return }
        guard CMPedometer.isStepCountingAvailable() else { return }
        liveRunning = true
        let start = todayStart

        pedometer.startUpdates(from: start) { [weak self] data, _ in
            guard let d = data else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                let steps = d.numberOfSteps.intValue
                let now = Date()

                let moved = steps - self.lastWrittenSteps >= 8
                let stale = now.timeIntervalSince(self.lastWriteAt) >= 15
                if steps > (self.store?.pedometerSteps ?? 0), moved || stale {
                    self.store?.pedometerSteps = steps
                    self.lastWrittenSteps = steps
                    self.lastWriteAt = now
                    if let dist = d.distance, dist.doubleValue > (self.store?.pedometerDistance ?? 0) {
                        self.store?.pedometerDistance = dist.doubleValue
                    }
                }

                // 状态文案也别每秒刷，15 秒一次够看
                if now.timeIntervalSince(self.lastStatusAt) >= 15 {
                    self.status = "实时同步中 · \(steps) 步"
                    self.lastUpdate = now
                    self.lastStatusAt = now
                }
            }
        }
    }
}

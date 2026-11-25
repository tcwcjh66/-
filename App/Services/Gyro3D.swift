import Foundation
import CoreMotion

/// 陀螺仪倾角源：给立绘做真实视差。
/// 设备倾斜 → 立绘绕 Y/X 轴微转 + 位移，形成"有厚度"的立体感。
final class Gyro3D: ObservableObject {
    @Published var roll: Double = 0      // 左右倾斜 -1…1（弧度归一化）
    @Published var pitch: Double = 0     // 前后倾斜
    @Published var active = false
    /// 倾斜角速度（归一化后放大），用于运动拖影
    @Published var rollSpeed: Double = 0

    private let mm = CMMotionManager()
    private let queue = OperationQueue()

    func start() {
        guard mm.isDeviceMotionAvailable, !mm.isDeviceMotionActive else { return }
        // 陀螺仪物理上限一般 100Hz，设 120 让它跑满
        mm.deviceMotionUpdateInterval = 1.0 / 120.0
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive

        mm.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            // roll 范围约 ±π/2，pitch ±π/2；做软限幅并低通滤波，避免抖动
            let rawRoll = max(-1.0, min(1.0, m.attitude.roll / 1.2))
            let rawPitch = max(-1.0, min(1.0, m.attitude.pitch / 1.2))
            DispatchQueue.main.async {
                // 一阶低通：0.18 系数，稳但不迟钝
                let prev = self.roll
                self.roll = self.roll * 0.82 + rawRoll * 0.18
                self.pitch = self.pitch * 0.82 + rawPitch * 0.18
                self.rollSpeed = (self.roll - prev) * 9.0
                self.active = true
            }
        }
    }

    func stop() {
        guard mm.isDeviceMotionActive else { return }
        mm.stopDeviceMotionUpdates()
        active = false
    }

    deinit {
        if mm.isDeviceMotionActive { mm.stopDeviceMotionUpdates() }
    }
}

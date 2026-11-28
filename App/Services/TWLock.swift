import Foundation
import LocalAuthentication

/// Face ID / 设备密码应用锁。免费签名可用，不需要任何 entitlement，
/// 只在 Info.plist 里写一句 NSFaceIDUsageDescription。
enum TWLock {
    /// 设备支不支持（没 Face ID 的老机器会退回设备密码）
    static var canUse: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    static func unlock(reason: String = "解锁 Persist，查看你的训练和身体数据",
                       done: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "用设备密码"
        ctx.localizedCancelTitle = "先不看"
        var err: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) else {
            DispatchQueue.main.async { done(false) }
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }
}

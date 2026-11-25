import Foundation
import CoreMotion
import AVFoundation
import UIKit

/// 睡眠监测：用 iPhone 加速度计做体动记录（actigraphy）。
/// 原理是业界常用的体动推断法：整夜采集加速度能量，按 30 秒一个 epoch 量化，
/// 静止段视为睡眠、密集活动段视为清醒，连续长静止段判为深睡。
/// 不依赖 HealthKit，也不依赖手表，纯本机传感器真实采集。
final class SleepTracker: NSObject, ObservableObject {

    @Published var recording = false
    @Published var elapsed: TimeInterval = 0
    @Published var liveAct: Double = 0          // 0...100，当前体动强度
    @Published var epochCount = 0

    private let motion = CMMotionManager()
    private var startDate: Date?
    private var bag: [Double] = []              // 当前 epoch 内的瞬时能量累加
    private var acts: [Double] = []             // 已完成的 epoch
    private var samples = 0                     // 本 epoch 已采样本数，后台 Timer 不可靠，用计数收敛
    private var uiTimer: Timer?
    private var player: AVAudioPlayer?

    static let epochSeconds: Double = 30

    // MARK: - 开始 / 结束

    func start() {
        guard !recording else { return }
        guard motion.isAccelerometerAvailable else { return }

        acts.removeAll()
        bag.removeAll()
        elapsed = 0
        liveAct = 0
        epochCount = 0
        startDate = Date()
        recording = true

        startSilentAudio()
        UIApplication.shared.isIdleTimerDisabled = true

        motion.accelerometerUpdateInterval = 0.05      // 20 Hz
        motion.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.acceleration else { return }
            // 信号幅值面积，去掉重力偏置后的合向量
            let mag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
            self.bag.append(mag)
            self.samples += 1
            // 实时预览：最近 20 个样本的均值换算到 0-100
            let tail = self.bag.suffix(20)
            let avg = tail.reduce(0, +) / Double(tail.count)
            self.liveAct = min(100, avg * 900)
            // 每满一个 epoch 的样本量就归档一次，不依赖 Timer（进后台后 Timer 会停）
            if Double(self.samples) >= Self.epochSeconds / self.motion.accelerometerUpdateInterval {
                self.samples = 0
                self.closeEpoch()
            }
        }

        uiTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let s = self.startDate else { return }
            self.elapsed = Date().timeIntervalSince(s)
        }
    }

    @discardableResult
    func stop() -> (start: Date, end: Date, acts: [Double])? {
        guard recording, let s = startDate else { return nil }
        closeEpoch()

        motion.stopAccelerometerUpdates()
        uiTimer?.invalidate(); uiTimer = nil
        player?.stop(); player = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        UIApplication.shared.isIdleTimerDisabled = false

        recording = false
        let e = Date()
        let result = (start: s, end: e, acts: acts)
        startDate = nil
        return result
    }

    /// 放弃本次记录，不保存
    func cancel() {
        _ = stop()
        acts.removeAll()
        bag.removeAll()
        elapsed = 0
        epochCount = 0
    }

    // MARK: - epoch 归档

    private func closeEpoch() {
        guard recording else { return }
        // 不足 15 秒的碎片不单独算一段，避免结束时把时长虚增
        guard bag.count >= 300 else { bag.removeAll(keepingCapacity: true); return }
        let avg = bag.reduce(0, +) / Double(bag.count)
        // 归一：静止时 mag 约 0.001-0.01，翻身时 0.1-0.5
        let v = min(100, avg * 900)
        acts.append(v)
        epochCount = acts.count
        bag.removeAll(keepingCapacity: true)
    }

    // MARK: - 后台保活（静音音频循环，配合 UIBackgroundModes: audio）

    private func startSilentAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let data = Self.silentWAV(seconds: 30)
        guard let p = try? AVAudioPlayer(data: data) else { return }
        p.numberOfLoops = -1
        p.volume = 0
        p.prepareToPlay()
        p.play()
        player = p
    }

    /// 生成一段全零 PCM 的 wav，用来让 App 在锁屏后保持后台运行。
    private static func silentWAV(seconds: Double) -> Data {
        let sr: UInt32 = 8000
        let channels: UInt16 = 1
        let bits: UInt16 = 16
        let frames = UInt32(Double(sr) * seconds)
        let dataBytes = frames * UInt32(channels) * UInt32(bits / 8)

        var d = Data()
        func put(_ s: String) { d.append(s.data(using: .ascii)!) }
        func u32(_ v: UInt32) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; d.append(Data(bytes: &x, count: 2)) }

        put("RIFF"); u32(36 + dataBytes); put("WAVE")
        put("fmt "); u32(16); u16(1); u16(channels); u32(sr)
        u32(sr * UInt32(channels) * UInt32(bits / 8)); u16(channels * bits / 8); u16(bits)
        put("data"); u32(dataBytes)
        d.append(Data(count: Int(dataBytes)))
        return d
    }
}

import Foundation
import AVFoundation
import QuartzCore

/// 指尖 PPG 心率测量。
///
/// 原理：后置摄像头 + 闪光灯常亮，食指指腹盖住镜头，血液随心脏搏动改变指尖透光率，
/// 每帧取画面中心区域的平均红色通道值，就得到一条随心跳起伏的光体积描记曲线。
/// 去趋势后做峰值检测，相邻峰的时间差即 RR 间期，60 / 平均RR 就是心率，
/// RR 间期的均方根差即 RMSSD，可直接当 HRV 用。
///
/// 不依赖 HealthKit，不需要付费开发者签名，纯本机物理测量。
final class PulseMeter: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var bpm: Int = 0
    @Published var hrv: Int = 0
    @Published var quality: String = "等待信号"
    @Published var elapsed: Double = 0
    @Published var wave: [Double] = []
    @Published var running: Bool = false
    @Published var finished: Bool = false
    @Published var errorText: String?

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "tw.pulse.queue")
    private var raw: [(t: Double, v: Double)] = []
    private var startAt: Double = 0
    private var frameTick = 0
    private var uiTimer: Timer?
    private var configured = false

    let duration: Double = 30

    // MARK: - 控制

    func start() {
        guard !running else { return }
        errorText = nil
        finished = false
        raw.removeAll()
        wave.removeAll()
        bpm = 0
        hrv = 0
        quality = "把指腹盖住镜头"
        elapsed = 0

        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured {
                self.configure()
            } else {
                self.resume()
            }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.session.stopRunning()
            self.torch(false)
            DispatchQueue.main.async {
                self.running = false
                self.stopTimer()
            }
        }
    }

    func reset() {
        raw.removeAll()
        wave.removeAll()
        bpm = 0
        hrv = 0
        elapsed = 0
        finished = false
        quality = "把指腹盖住镜头"
    }

    // MARK: - 设备

    private func configure() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            publishError("没有可用的后置摄像头")
            return
        }
        do {
            session.beginConfiguration()
            if session.canSetSessionPreset(.low) {
                session.sessionPreset = .low
            }

            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            session.commitConfiguration()

            try device.lockForConfiguration()
            if device.isExposureModeSupported(.locked) { device.exposureMode = .locked }
            if device.isWhiteBalanceModeSupported(.locked) { device.whiteBalanceMode = .locked }
            device.unlockForConfiguration()

            configured = true
            resume()
        } catch {
            publishError("摄像头启动失败：\(error.localizedDescription)")
        }
    }

    private func resume() {
        guard !session.isRunning else { return }
        session.startRunning()
        torch(true)
        startAt = CACurrentMediaTime()
        raw.removeAll()
        wave.removeAll()
        frameTick = 0
        DispatchQueue.main.async {
            self.running = true
            self.finished = false
            self.startTimer()
        }
    }

    private func torch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else { return }
        try? device.lockForConfiguration()
        if on && device.isTorchModeSupported(.on) {
            try? device.setTorchModeOn(level: 0.9)
        } else if device.isTorchModeSupported(.off) {
            device.torchMode = .off
        }
        device.unlockForConfiguration()
    }

    // MARK: - 采样

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        CVPixelBufferLockBaseAddress(pb, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pb) else { return }

        let w = CVPixelBufferGetWidth(pb)
        let h = CVPixelBufferGetHeight(pb)
        let bpr = CVPixelBufferGetBytesPerRow(pb)
        let buf = base.assumingMemoryBound(to: UInt8.self)

        let cx = w / 2
        let cy = h / 2
        let rad = max(6, min(w, h) / 7)

        var sum: Double = 0
        var n = 0
        var y = cy - rad
        while y < cy + rad {
            var x = cx - rad
            while x < cx + rad {
                let i = y * bpr + x * 4
                sum += Double(buf[i + 2])
                n += 1
                x += 4
            }
            y += 4
        }
        guard n > 0 else { return }

        let t = CACurrentMediaTime()
        raw.append((t, sum / Double(n)))
        if raw.count > 1400 {
            raw.removeFirst(500)
        }

        frameTick += 1
        if frameTick % 10 == 0 {
            evaluate()
        }
    }

    // MARK: - 解算

    private func evaluate() {
        let result = solve()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.wave = result.wave
            self.quality = result.note
            if let b = result.bpm { self.bpm = b }
            if let r = result.hrv { self.hrv = r }
        }
    }

    private struct Solution {
        var wave: [Double]
        var bpm: Int?
        var hrv: Int?
        var note: String
    }

    private func solve() -> Solution {
        let n = raw.count
        guard n > 140 else { return Solution(wave: [], bpm: nil, hrv: nil, note: "把指腹盖稳一点") }

        let tEnd = raw[n - 1].t
        let recent = raw.filter { $0.t > tEnd - 12 }
        guard recent.count > 120 else {
            return Solution(wave: [], bpm: nil, hrv: nil, note: "正在采集")
        }

        let vals = recent.map { $0.v }
        let mean = vals.reduce(0, +) / Double(vals.count)
        let centered = vals.map { $0 - mean }

        let amp = max(centered.map { abs($0) }.max() ?? 1.0, 0.4)
        let shown = Array(centered.suffix(110)).map { $0 / amp }

        // 峰值：比左右各两帧都高，且高于本段主振幅的 30%
        var peaks: [Double] = []
        var i = 2
        while i < recent.count - 2 {
            let v = centered[i]
            if v > centered[i - 1], v > centered[i - 2],
               v > centered[i + 1], v > centered[i + 2],
               v > amp * 0.28 {
                peaks.append(recent[i].t)
                i += 2
            } else {
                i += 1
            }
        }

        guard peaks.count >= 3 else {
            return Solution(wave: shown, bpm: nil, hrv: nil, note: "信号偏弱，手指压紧一点")
        }

        var rr: [Double] = []
        for k in 1..<peaks.count {
            let d = peaks[k] - peaks[k - 1]
            if d > 0.30 && d < 1.60 { rr.append(d) }
        }
        guard rr.count >= 2 else {
            return Solution(wave: shown, bpm: nil, hrv: nil, note: "还在找节拍")
        }

        let meanRR = rr.reduce(0, +) / Double(rr.count)
        let bpm = Int(60.0 / meanRR)
        guard bpm >= 40 && bpm <= 200 else {
            return Solution(wave: shown, bpm: nil, hrv: nil, note: "读数不稳，重测一次")
        }

        var sq = 0.0
        for k in 1..<rr.count {
            let d = rr[k] - rr[k - 1]
            sq += d * d
        }
        let rmssd = rr.count > 1 ? sqrt(sq / Double(rr.count - 1)) : 0
        let hrv = Int(rmssd * 1000)

        // 质量：RR 的变异不能过大，过大多半是峰检错了
        let cv = rmssd / meanRR
        let note: String
        if cv < 0.08 {
            note = "信号稳定"
        } else if cv < 0.16 {
            note = "信号良好"
        } else {
            note = "有轻微抖动"
        }

        return Solution(wave: shown, bpm: bpm, hrv: max(hrv, 0), note: note)
    }

    // MARK: - 计时

    private func startTimer() {
        stopTimer()
        uiTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.running else { return }
            let e = min(self.duration, CACurrentMediaTime() - self.startAt)
            self.elapsed = e
            if e >= self.duration {
                self.finished = true
                self.stop()
            }
        }
    }

    private func stopTimer() {
        uiTimer?.invalidate()
        uiTimer = nil
    }

    private func publishError(_ text: String) {
        DispatchQueue.main.async {
            self.errorText = text
            self.running = false
        }
    }
}

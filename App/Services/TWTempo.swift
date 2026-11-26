import AVFoundation

/// 训练节拍器：3 秒下放、1 秒停、2 秒推起。
/// 自己合成两段很短的 WAV 音，走 .playback 会话，手机拨到静音也能响。
enum TWTempo {
    private static let key = "tw.tempo.on.v1"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    private static var low: AVAudioPlayer?
    private static var high: AVAudioPlayer?
    private static var ready = false
    private static var sessionReady = false

    /// 16bit 单声道 PCM 的 WAV，很短，只在拍点上响一下
    private static func makeWav(freq: Double, dur: Double = 0.07) -> Data {
        let sr = 44100
        let n = Int(Double(sr) * dur)
        var out = Data()
        func u32(_ v: UInt32) {
            var x = v
            withUnsafeBytes(of: &x) { out.append(contentsOf: $0) }
        }
        func u16(_ v: UInt16) {
            var x = v
            withUnsafeBytes(of: &x) { out.append(contentsOf: $0) }
        }
        out.append(contentsOf: Array("RIFF".utf8))
        u32(UInt32(36 + n * 2))
        out.append(contentsOf: Array("WAVE".utf8))
        out.append(contentsOf: Array("fmt ".utf8))
        u32(16)
        u16(1)
        u16(1)
        u32(UInt32(sr))
        u32(UInt32(sr * 2))
        u16(2)
        u16(16)
        out.append(contentsOf: Array("data".utf8))
        u32(UInt32(n * 2))
        for i in 0..<n {
            let t = Double(i) / Double(sr)
            // 两头淡出，避免爆音
            let env = sin(Double.pi * Double(i) / Double(n))
            let v = sin(2 * Double.pi * freq * t) * env
            u16(UInt16(clamping: Int(v * 11000 + 32768)))
        }
        return out
    }

    private static func prepare() {
        guard !ready else { return }
        ready = true
        let dir = FileManager.default.temporaryDirectory
        let lo = dir.appendingPathComponent("twbeat-low.wav")
        let hi = dir.appendingPathComponent("twbeat-high.wav")
        try? makeWav(freq: 620).write(to: lo)
        try? makeWav(freq: 1060).write(to: hi)
        low = try? AVAudioPlayer(contentsOf: lo)
        high = try? AVAudioPlayer(contentsOf: hi)
        low?.volume = 0.55
        high?.volume = 0.78
        low?.prepareToPlay()
        high?.prepareToPlay()
    }

    private static func activateSession() {
        guard !sessionReady else { return }
        sessionReady = true
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
    }

    /// hi = true 是推起那一拍；低音是下放那一拍
    static func beat(hi: Bool) {
        guard isOn else { return }
        prepare()
        activateSession()
        let p = hi ? high : low
        p?.currentTime = 0
        p?.play()
    }
}

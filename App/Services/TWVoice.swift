import AVFoundation

/// 训练时的语音播报：休息结束、下一组该练什么。
/// 用 .playback 会话，手机静音键拨到静音也能出声——训练时手上有汗，没人去拨开关。
enum TWVoice {
    private static let synth = AVSpeechSynthesizer()
    private static let key = "tw.voice.on.v1"
    private static let tenKey = "tw.voice.ten.v1"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    /// 剩 10 秒时提醒一句，默认开
    static var countdownOn: Bool {
        get { UserDefaults.standard.object(forKey: tenKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: tenKey) }
    }

    private static var tenSaid = false

    /// 开始新一轮休息时清掉「已提示过」
    static func resetCountdown() { tenSaid = false }

    /// 倒计时每秒调一次，到 10 秒提示
    static func tick(_ remain: Int) {
        guard countdownOn, remain == 10, !tenSaid else { return }
        tenSaid = true
        speak("还有 10 秒")
    }

    static func speak(_ text: String) {
        guard isOn, !text.isEmpty else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)

        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = 0.47
        u.pitchMultiplier = 0.96
        u.preUtteranceDelay = 0.05
        synth.speak(u)
    }

    /// 休息开始的提醒，短一句，不吵
    static func announceRest(_ sec: Int, move: String) {
        speak("休息 \(sec) 秒")
    }

    static func announceNext(_ next: String) {
        if next.isEmpty {
            speak("休息结束，继续下一组")
        } else {
            speak("休息结束，下一个，\(next)")
        }
    }
}

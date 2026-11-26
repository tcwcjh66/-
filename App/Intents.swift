import AppIntents
import Foundation

// MARK: - 记水

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "记一杯水"
    static var description: IntentDescription = IntentDescription("给今天加一杯水，默认 250 毫升。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "杯数")
    var cups: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let left = await MainActor.run { () -> Int in
            let s = TWStore.shared
            s.addWater(cups)
            return s.waterTarget - s.waterCups
        }
        if left > 0 {
            return .result(dialog: "记下了，还差 \(left) 杯到今天的量。")
        }
        return .result(dialog: "记下了，今天的量已经够了。")
    }
}

// MARK: - 记体重

struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "记录体重"
    static var description: IntentDescription = IntentDescription("把今天的体重记进去，单位公斤。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "公斤")
    var kg: Double

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ok = await MainActor.run { () -> Bool in
            guard kg > 20, kg < 300 else { return false }
            TWStore.shared.logWeight(kg)
            return true
        }
        guard ok else {
            return .result(dialog: "体重得在 20 到 300 公斤之间，这次没记。")
        }
        let one = String(format: "%.1f", kg)
        return .result(dialog: "记下了，今天 \(one) 公斤。")
    }
}

// MARK: - 查今天

struct TodayStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "今天走多少步"
    static var description: IntentDescription = IntentDescription("读出今天已经记下的步数和活动能量。")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let info = await MainActor.run { () -> (Int, Int) in
            let s = TWStore.shared
            return (s.stepsForDisplay, Int(s.moveKcal))
        }
        return .result(dialog: "今天 \(info.0) 步，活动 \(info.1) 千卡。")
    }
}

// MARK: - Siri 短语

struct TWAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "给\(.applicationName)记一杯水",
                "用\(.applicationName)喝水打卡"
            ],
            shortTitle: "记一杯水",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: TodayStepsIntent(),
            phrases: ["\(.applicationName)今天走多少步"],
            shortTitle: "今天多少步",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: LogWeightIntent(),
            phrases: ["用\(.applicationName)记体重"],
            shortTitle: "记体重",
            systemImageName: "scalemass.fill"
        )
    }
}

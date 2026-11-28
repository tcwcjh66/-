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

// MARK: - 记一组

/// 训练中手上有汗、戴着护腕，说一句就记下来，不用解锁点屏幕。
struct LogSetIntent: AppIntent {
    static var title: LocalizedStringResource = "记一组"
    static var description: IntentDescription = IntentDescription("训练时记一组：说重量和次数，动作不说就记当前第一个。")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "动作", description: "比如卧推；不填就记当前训练的第一个动作")
    var move: String?

    @Parameter(title: "重量（公斤）")
    var kg: Double

    @Parameter(title: "次数")
    var reps: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard kg > 0, reps > 0, reps <= 60 else {
            return .result(dialog: "重量和次数得是正数，次数别超过 60，这次没记。")
        }
        let r = await MainActor.run { () -> (String, Int, Bool) in
            let s = TWStore.shared
            let name = (move?.isEmpty == false ? move! : (s.sessionMoves.first ?? "训练"))
            if s.sessionStart == nil {
                s.startSession(moves: name == "训练" ? [] : [name])
            }
            let old = s.prBest[name] ?? 0
            s.addSet(weight: kg, reps: reps, move: name, rir: 2)
            let newPR = (s.prBest[name] ?? 0) > old + 0.01
            return (name, s.sessionSets, newPR)
        }
        let prText = r.2 ? "，这把破纪录了" : ""
        return .result(dialog: "\(r.0) 记下第 \(r.1) 组：\(kg) 公斤 \(reps) 次\(prText)。")
    }
}

// MARK: - 开始训练

struct StartTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始训练"
    static var description: IntentDescription = IntentDescription("按当前方案的今天这一练，直接开一场训练。")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let r = await MainActor.run { () -> (String, String, Int) in
            let s = TWStore.shared
            let plans = s.allPlans
            let pi = min(max(s.planPick, 0), max(plans.count - 1, 0))
            let tpl = plans[pi]
            let di = min(max(s.dayPick, 0), max(tpl.days.count - 1, 0))
            let d = tpl.days[di]
            s.startSession(moves: d.items.map(\.name))
            return (tpl.name, d.title, d.items.count)
        }
        return .result(dialog: "开始 \(r.0) · \(r.1)，\(r.2) 个动作。练完一组跟我说「记一组」。")
    }
}

// MARK: - 今天练什么

struct TodayTrainingIntent: AppIntent {
    static var title: LocalizedStringResource = "今天练什么"
    static var description: IntentDescription = IntentDescription("读出今天排的训练日和动作，不用打开 App。")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let r = await MainActor.run { () -> (String, String, String) in
            let s = TWStore.shared
            let plans = s.allPlans
            let pi = min(max(s.planPick, 0), max(plans.count - 1, 0))
            let tpl = plans[pi]
            let di = min(max(s.dayPick, 0), max(tpl.days.count - 1, 0))
            let d = tpl.days[di]
            let moves = d.items.prefix(4).map { $0.name }.joined(separator: "、")
            let rest: String
            if let train = s.todayIsTrainingDay {
                rest = train ? "今天排了训练。" : "今天排的是休息日，想练也能直接开始。"
            } else {
                rest = ""
            }
            return (tpl.name, d.title, rest + "今天：\(moves)。")
        }
        return .result(dialog: "\(r.0) · \(r.1)。\(r.2)")
    }
}

// MARK: - 查训练进度

struct TrainingProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "训练进度"
    static var description: IntentDescription = IntentDescription("读出今天做了几组、这周练了几次，不用打开 App。")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let r = await MainActor.run { () -> (Int, Int, Int) in
            let s = TWStore.shared
            let cutoff = DateFormatter.twDay.string(from: Date().addingTimeInterval(-6 * 86400))
            let week = s.sessions.filter { $0.date >= cutoff }
            return (s.sessionSets, week.count, week.reduce(0) { $0 + $1.sets })
        }
        if r.0 == 0 && r.1 == 0 {
            return .result(dialog: "今天还没记组，这周也还没开练。说一句「开始训练」就能开一场。")
        }
        return .result(dialog: "今天已记 \(r.0) 组；这周练了 \(r.1) 次，共 \(r.2) 组。")
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
        AppShortcut(
            intent: LogSetIntent(),
            phrases: ["给\(.applicationName)记一组", "\(.applicationName)记一组"],
            shortTitle: "记一组",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: StartTrainingIntent(),
            phrases: ["用\(.applicationName)开始训练", "\(.applicationName)开练"],
            shortTitle: "开始训练",
            systemImageName: "play.circle.fill"
        )
        AppShortcut(
            intent: TodayTrainingIntent(),
            phrases: ["\(.applicationName)今天练什么"],
            shortTitle: "今天练什么",
            systemImageName: "figure.strengthtraining.traditional"
        )
        AppShortcut(
            intent: TrainingProgressIntent(),
            phrases: [
                "\(.applicationName)今天练了几组",
                "\(.applicationName)这周练了几次",
                "\(.applicationName)训练进度"
            ],
            shortTitle: "训练进度",
            systemImageName: "chart.bar.fill"
        )
    }
}

import SwiftUI
import Combine
import UIKit

enum TWTab: String, CaseIterable, Identifiable {
    // 顺序即底栏顺序：今天 → 训练 → 饮食 → 身体 → 动作库
    case today, flow, diet, bio, lib

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .flow:  return "训练"
        case .diet:  return "饮食"
        case .bio:   return "身体"
        case .lib:   return "动作库"
        }
    }

    /// 底栏用的彩色 emoji 图案
    var emoji: String {
        switch self {
        case .today: return "🏠"
        case .flow:  return "🏋️"
        case .diet:  return "🥗"
        case .bio:   return "❤️"
        case .lib:   return "📚"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "circle.dotted"
        case .flow:  return "timer"
        case .diet:  return "fork.knife"
        case .bio:   return "heart"
        case .lib:   return "figure.strengthtraining.traditional"
        }
    }
}

struct MealEntry: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carb: Double
    var fat: Double
    var veg: Double
    var slot: String? = nil
    var time: Date? = nil
}

struct WeightLog: Codable, Identifiable, Hashable {
    var id: String   // yyyy-MM-dd
    var kg: Double
}

struct CustomFood: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var kcalPer100: Double
    var proteinPer100: Double
    var carbPer100: Double
    var fatPer100: Double
}

/// 一组的明细：哪个动作、多重、几次。有了它才能算出“上次 20kg×8 → 这次该加多少”。
/// 扫过的条码记在本机：下次再扫同一个码，不联网也能立刻出营养。
/// Open Food Facts 对国产包装覆盖很差，这里补的是「你自己扫出来的库」。
struct BarcodeNote: Codable, Identifiable, Hashable {
    var id: String { code }
    var code: String
    var name: String
    var brand: String = ""
    var kcal100: Double
    var protein100: Double
    var carb100: Double
    var fat100: Double
    var servingGrams: Double = 100
    var fromWeb: Bool = false
    var at: Date = Date()
}

struct SetRecord: Codable, Hashable {
    var move: String
    var weight: Double
    var reps: Int
    var date: String   // yyyy-MM-dd
    /// 这组做完还剩几次余力（RIR）。0 = 力竭，2 = 还留两次，3+ = 偏轻。
    /// 只看次数做满没，会误判「其实还有三下没做完」的重量；老记录没有这个字段。
    var rir: Int? = nil
}

/// 一次没结算的训练快照：App 被杀或误退，重进还能接上。
struct TWPendingSession: Codable {
    var start: Date
    var sets: Int
    var tonnage: Double
    var records: [SetRecord]
}

/// 某动作某天的最好 e1RM（Epley 估算），用来画力量曲线。
struct E1RMPoint: Identifiable, Hashable {
    var id: String { date }
    var date: String      // yyyy-MM-dd
    var kg: Double        // 估算的 1RM
    var reps: Int
    var weight: Double
}

/// 一条体检发现。count 是受影响的记录数，kind 决定能不能一键清
struct TWDataIssue: Identifiable {
    var id = UUID()
    var title: String
    var detail: String
    var count: Int
    var kind: String
}

struct SessionLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: String        // yyyy-MM-dd
    var plan: String
    var day: String
    var moves: Int
    var sets: Int
    var minutes: Int
    var moveNames: [String]? = nil
    var tonnage: Double? = nil
    /// 4.0 之后才有：每组的动作/重量/次数。老记录为 nil，渐进建议会跳过它们。
    var records: [SetRecord]? = nil
}

struct GirthLog: Codable, Identifiable, Hashable {
    var id: String          // yyyy-MM-dd
    var waist: Double
    var chest: Double
    var arm: Double
    var thigh: Double
    var hip: Double
}

/// 百分比强度：按最好 e1RM 换算出来的「该用多重、做几次」
struct TWPctRow: Identifiable, Hashable {
    var id: Int { pct }
    let pct: Int
    let kg: Double
    let reps: Int
}

/// 一个卡住的动作：最好成绩停在哪天，现在多重
struct TWStallInfo: Identifiable, Hashable {
    var id: String { move }
    let move: String
    let days: Int
    let best: Double
    let last: Double
}

/// 一条可以撤销的删除：text 是提示语，run 是恢复动作
struct TWUndoAction: Identifiable {
    let id = UUID()
    let text: String
    let run: () -> Void
}

/// 训练时该用多重：kg + 次数 + 一句话理由
struct WeightSuggestion {
    let kg: Double
    let reps: Int
    let note: String
}

/// 一晚睡眠记录：acts 是每 30 秒一个的体动强度（0-100），报告全部由此现算。
struct SleepLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: String        // yyyy-MM-dd（入睡那天）
    var start: Date
    var end: Date
    var acts: [Double]
}

extension SleepLog {
    var totalEpochs: Int { acts.count }
    var durationMinutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    /// 清醒阈值：取体动分布 65 分位以上 1.4 倍，保证夜里的安静基底不被误判成清醒
    var threshold: Double {
        guard acts.count >= 8 else { return 14 }
        let sorted = acts.sorted()
        let q = sorted[Int(Double(sorted.count - 1) * 0.65)]
        return max(6, q * 1.4)
    }

    /// 每个 epoch 的分期：2 清醒 / 1 浅睡 / 0 深睡
    var stageCodes: [Int] {
        guard !acts.isEmpty else { return [] }
        let th = threshold
        var codes = acts.map { $0 >= th ? 2 : 1 }
        // 连续静止超过 20 分钟（40 × 30s）判为深睡段
        var i = 0
        while i < codes.count {
            if codes[i] == 1 {
                var j = i
                while j < codes.count && codes[j] == 1 { j += 1 }
                if j - i >= 40 {
                    for k in i..<j { codes[k] = 0 }
                }
                i = j
            } else {
                i += 1
            }
        }
        return codes
    }

    var awakeEpochs: Int { stageCodes.filter { $0 == 2 }.count }
    var deepEpochs: Int { stageCodes.filter { $0 == 0 }.count }
    var lightEpochs: Int { stageCodes.filter { $0 == 1 }.count }

    var awakeMinutes: Int { awakeEpochs / 2 }
    var deepMinutes: Int { deepEpochs / 2 }
    var lightMinutes: Int { lightEpochs / 2 }

    /// 睡眠质量评分：有效率打底，体动与清醒扣分
    var score: Int {
        guard totalEpochs > 0 else { return 0 }
        let eff = Double(totalEpochs - awakeEpochs) / Double(totalEpochs)
        let base = eff * 100
        let penalty = min(28, Double(awakeEpochs) / Double(totalEpochs) * 100 * 0.9)
        return max(0, min(100, Int(base - penalty)))
    }

    var scoreLabel: String {
        switch score {
        case 85...: return "睡得很沉"
        case 70..<85: return "质量不错"
        case 55..<70: return "有点碎"
        case 40..<55: return "翻来覆去"
        default: return "几乎没睡好"
        }
    }

    /// 入睡 / 起床时间文本
    var startText: String { DateFormatter.twShort.string(from: start) }
    var endText: String { DateFormatter.twShort.string(from: end) }

    var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return h > 0 ? "\(h) 小时 \(m) 分" : "\(m) 分"
    }
}

struct MoveItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var group: String
    var equipment: String
    var cue: String
    var pr: String
    var error: String = ""
    var alt: String = ""
    var level: String = "初级"
    var video: String = ""
}

/// 每日快照，用于趋势图
struct DayLog: Codable, Identifiable, Hashable {
    var id: String        // yyyy-MM-dd
    var steps: Int
    var hr: Int
    var hrv: Int
    var moveKcal: Double
    var exerciseMin: Double
    var kcal: Double? = nil
    var protein: Double? = nil
    var carb: Double? = nil
    var fat: Double? = nil
}


// MARK: - 自定义训练方案

struct CustomSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = ""
    var sets: Int = 3
    var reps: String = "10"
    var weight: String = ""
    var restSec: Int = 45
    var note: String = ""
}

struct CustomDay: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String = "第 1 天"
    var sets: [CustomSet] = []
}

struct CustomPlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = "我的方案"
    var tag: String = "自定义"
    var cycle: String = "每周 3 次"
    var days: [CustomDay] = [CustomDay(title: "第 1 天")]

    /// 转成 FlowPage 直接能用的 PlanTemplate
    var template: PlanTemplate {
        PlanTemplate(
            name: name,
            tag: tag,
            level: "自定义",
            daysPerWeek: 3,
            cycle: cycle,
            summary: "自己排的方案，动作、组数、次数、重量、休息都可改。",
            progression: "按感觉调整重量，做不满次数就减 5%。",
            days: days.map { d in
                PlanDay(
                    title: d.title,
                    focus: "\(d.sets.count) 个动作",
                    items: d.sets.map { it in
                        PlanItem(
                            name: it.name,
                            sets: "\(it.sets) 组",
                            reps: it.reps,
                            rest: it.restSec > 0 ? "\(it.restSec) 秒" : "60 秒"
                        )
                    }
                )
            }
        )
    }
}

final class TWStore: ObservableObject {
    /// Siri / 快捷指令在 App 没起时也要能改数据，所以只留一个实例，界面也用这个
    static let shared = TWStore()

    /// 高频数值挪到 TWLive，这里只做转发——Store 自己的 objectWillChange
    /// 不再被步数、心率、三环的跳动牵动，其余四个页面就不会跟着重绘了。
    let live = TWLive()

    // 环形
    var moveKcal: Double {
        get { live.moveKcal }
        set { live.moveKcal = newValue }
    }
    @Published var moveTarget: Double = 520
    var exerciseMin: Double {
        get { live.exerciseMin }
        set { live.exerciseMin = newValue }
    }
    @Published var exerciseTarget: Double = 30
    var standHours: Double {
        get { live.standHours }
        set { live.standHours = newValue }
    }
    @Published var standTarget: Double = 10
    var hrv: Int {
        get { live.hrv }
        set { live.hrv = newValue }
    }

    // 身体
    var steps: Int {
        get { live.steps }
        set { live.steps = newValue }
    }
    var hr: Int {
        get { live.hr }
        set { live.hr = newValue }
    }
    @Published var restingHR: Int = 0
    var pedometerSteps: Int {
        get { live.pedometerSteps }
        set { live.pedometerSteps = newValue }
    }
    var pedometerDistance: Double {
        get { live.pedometerDistance }
        set { live.pedometerDistance = newValue }
    }
    var measuredHR: Int {
        get { live.measuredHR }
        set { live.measuredHR = newValue }
    }
    var measuredHRV: Int {
        get { live.measuredHRV }
        set { live.measuredHRV = newValue }
    }
    var measuredAt: Date? {
        get { live.measuredAt }
        set { live.measuredAt = newValue }
    }
    var hrSource: String {
        get { live.hrSource }
        set { live.hrSource = newValue }
    }
    @Published var watchSteps: Int = 0
    /// 手表同步进来的睡眠数据（Quick 快捷指令通道）
    @Published var watchSleepMin: Int = 0
    /// 免费签名拿不到 HealthKit，这几项允许手填，恢复度才有得算
    @Published var manualSleepMin: Int = 0
    @Published var manualRestingHR: Int = 0
    @Published var manualHRV: Int = 0
    @Published var watchDeepMin: Int = 0
    @Published var watchSyncAt: Date?
    @Published var watchSyncCount: Int = 0
    @Published var mindfulMin: Int = 0
    @Published var mindfulAt: Date?

    // 饮食
    @Published var dietKcal: Double = 0
    @Published var dietTarget: Double = 2200
    @Published var proteinGoal: Double = 120
    /// 每周练几次算达标，本周日历和「还差几次」提醒都用它
    @Published var weeklyGoal: Int = 4
    @Published var protein: Double = 0
    @Published var carb: Double = 0
    @Published var fat: Double = 0
    @Published var veg: Double = 0
    @Published var meals: [MealEntry] = []
    /// 最近一次删除，6 秒内可以撤销
    @Published var undo: TWUndoAction?
    private var undoCommit: (() -> Void)?
    private var undoWork: DispatchWorkItem?
    /// 餐食照片：日期 → 文件名（存在 Documents/mealPhotos 里，只留最近 40 天）
    @Published var mealPhotos: [String: [String]] = [:]

    // 心情
    @Published var mood: String = "ok"

    // 训练会话
    @Published var sessionStart: Date?
    @Published var sessionSets: Int = 0
    @Published var sessionMoves: [String] = []
    @Published var sessionTonnage: Double = 0
    /// 本次训练每一组的明细，结束训练时写进 SessionLog.records
    @Published var sessionRecords: [SetRecord] = []
    @Published var logs: [DayLog] = []

    // 收藏
    @Published var favoriteMoves: [String] = []

    // 身体数据
    @Published var bodyWeight: Double = 0
    /// 算热量目标用的基础信息
    @Published var age: Int = 20
    @Published var sexMale: Bool = true
    /// 0 少动 / 1 一般 / 2 常练
    @Published var activityLevel: Int = 1
    /// 0 减脂 / 1 维持 / 2 增肌
    @Published var goalMode: Int = 1
    @Published var heightCM: Double = 0
    @Published var waistCM: Double = 0
    @Published var chestCM: Double = 0
    @Published var armCM: Double = 0
    @Published var thighCM: Double = 0
    @Published var hipCM: Double = 0
    @Published var weightGoal: Double = 0
    @Published var weightLogs: [WeightLog] = []

    // 训练历史
    @Published var sessions: [SessionLog] = []
    @Published var girthLogs: [GirthLog] = []

    // 方案选择记忆
    @Published var planPick: Int = 0
    @Published var dayPick: Int = 0

    /// 动作名 → 自己的最好成绩，如 "70kg × 5"
    @Published var prs: [String: String] = [:]
    /// 每个动作的历史最好 e1RM，用来判断这组是不是破纪录
    @Published var prBest: [String: Double] = [:]
    /// 破纪录时弹一下的文案，几秒后自己消失
    @Published var prBurst: String?
    /// 上次没结算的训练，重进 App 时提示接上
    @Published var pendingSession: TWPendingSession?
    /// 手上有哪些器械，计划只从能做的动作里挑
    @Published var ownedGear: Set<String> = ["哑铃", "杠铃", "器械", "自重", "弹力带"]
    /// 打开 App 要 Face ID / 设备密码，设置里可关
    @Published var lockEnabled: Bool = false

    // 饮水
    @Published var waterCups: Int = 0
    @Published var waterTarget: Int = 8
    /// 每杯容量（ml），可自定义
    @Published var cupSize: Int = 250
    /// 非整杯的零头（喝了一瓶 550ml、半杯 120ml 这类）
    @Published var waterExtraML: Int = 0

    var waterML: Int { waterCups * cupSize + waterExtraML }
    var waterTargetML: Int { waterTarget * cupSize }

    // 睡眠记录（新的在前）
    @Published var sleepLogs: [SleepLog] = []

    /// 血氧（%），来自手表 / 快捷指令
    @Published var watchSpO2: Int = 0
    @Published var watchSpO2At: Date?

    // 自定义训练方案
    @Published var customPlans: [CustomPlan] = []
    /// 休息秒数覆盖：0 = 用动作自带，>0 = 全局强制这个数
    @Published var restOverride: Int = 0
    /// 跨天游标（yyyy-MM-dd），用于每日自动归零
    @Published var lastDayKey: String = ""

    // 自定义食物
    @Published var customFoods: [CustomFood] = []
    /// 按日期存的历史餐食明细（保留最近 40 天），供「复制昨天」用
    @Published var mealHistory: [String: [MealEntry]] = [:]
    /// 本机条码库：code → 营养。扫到过的码都留在这里。
    @Published var barcodeNotes: [String: BarcodeNote] = [:]
    /// 自动备份失败时的提示，首页会显示一条细横幅，点掉即可
    @Published var saveIssue: String? = nil
    /// 进度照索引，图本身在 Documents/progressPhotos
    @Published var progressPhotos: [ProgressPhoto] = []

    private let d = UserDefaults.standard
    private var saveWork: DispatchWorkItem?
    /// 三个大数组在后台读。读完之前不许把内存里的空数组写回盘，否则首屏就把它盖没了。
    private var heavyLoaded = false

    private enum Key {
        static let prBest = "tw.prBest.v1"
        static let gear = "tw.gear.v1"
        static let lock = "tw.lock.v1"
        static let hr = "tw.hr.v2"
        static let hrv = "tw.hrv.v2"
        static let hrAt = "tw.hrAt.v2"
        static let hrSrc = "tw.hrSrc.v2"
        static let steps = "tw.steps.v2"
        static let dist = "tw.dist.v2"
        static let mood = "tw.mood.v2"
        static let meals = "tw.meals.v2"
        static let logs = "tw.logs.v2"
        static let kcal = "tw.kcal.v2"
        static let protein = "tw.protein.v2"
        static let carb = "tw.carb.v2"
        static let fat = "tw.fat.v2"
        static let veg = "tw.veg.v2"
        static let exercise = "tw.exercise.v2"
        static let moveK = "tw.moveK.v2"
        static let stand = "tw.stand.v2"
        static let fav = "tw.fav.v2"
        static let weight = "tw.weight.v2"
        static let height = "tw.height.v2"
        static let waist = "tw.waist.v2"
        static let wlogs = "tw.wlogs.v2"
        static let water = "tw.water.v2"
        static let waterDay = "tw.waterDay.v2"
        static let spo2 = "tw.spo2.v3"
        static let spo2At = "tw.spo2At.v3"
        static let cplans = "tw.cplans.v3"
        static let restOv = "tw.restOv.v3"
        static let dayKey = "tw.dayKey.v3"
        static let wextra = "tw.wextra.v2"
        static let cupsize = "tw.cupsize.v2"
        static let cfoods = "tw.cfoods.v2"
        static let wgoal = "tw.wgoal.v2"
        static let sess = "tw.sess.v2"
        static let chest = "tw.chest.v2"
        static let arm = "tw.arm.v2"
        static let thigh = "tw.thigh.v2"
        static let hip = "tw.hip.v2"
        static let glogs = "tw.glogs.v2"
        static let planpick = "tw.planpick.v2"
        static let daypick = "tw.daypick.v2"
        static let prs = "tw.prs.v2"
        static let sleeps = "tw.sleeps.v2"
        static let wsleep = "tw.wsleep.v2"
        static let wdeep = "tw.wdeep.v2"
        static let dt = "tw.dt.v2"
        static let pgoal = "tw.pgoal.v2"
        static let weekly = "tw.weekly.v1"
        static let wt = "tw.wt.v2"
        static let mhist = "tw.mhist.v2"
        static let wsync = "tw.wsync.v2"
        static let wcount = "tw.wcount.v2"
        static let mindmin = "tw.mindmin.v2"
        static let mindat = "tw.mindat.v2"
        static let msleep = "tw.msleep.v1"
        static let mhr = "tw.mhr.v1"
        static let mhrv = "tw.mhrv.v1"
    }

    init() {
        load()
        loadPendingSession()
        // 饮食、照片、训练记录这三个大数组放后台解，首屏不等
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadHeavy()
        }
        if logs.isEmpty == false {
            let today = DateFormatter.twDay.string(from: Date())
            if let last = logs.last, last.id != today {
                // 新的一天，清零运动量
            }
        }
    }

    // MARK: - 派生

    var ringMove: Double { moveTarget > 0 ? min(moveKcal / moveTarget, 1) : 0 }
    var ringExercise: Double { exerciseTarget > 0 ? min(exerciseMin / exerciseTarget, 1) : 0 }
    var ringStand: Double { standTarget > 0 ? min(standHours / standTarget, 1) : 0 }
    var ringHrv: Double {
        guard hrv > 0 else { return 0.18 }
        return min(Double(hrv) / 100.0, 1.0)
    }

    var avatarAsset: String {
        switch mood {
        case "tired": return "avatar-tired"
        case "sleep": return "avatar-sleep"
        case "win":   return "avatar-win"
        case "train": return "avatar-train"
        default:      return "avatar"
        }
    }

    var dietLeft: Double { max(dietTarget - dietKcal, 0) }

    /// 预设方案 + 自建方案，训练页统一从这里取
    var allPlans: [PlanTemplate] {
        planTemplates + customPlans.map { $0.template }
    }


    // MARK: - 肌群恢复

    /// 某个肌群距上次训练几天。从最近 60 次训练里倒着找，没练过返回 nil。
    func daysSinceTrain(group: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        let names = Set(allMoves.filter { $0.group == group }.map { $0.name })
        for s in sessions.prefix(60) {
            guard let done = s.moveNames, !done.isEmpty else { continue }
            guard done.contains(where: { names.contains($0) }) else { continue }
            guard let d = f.date(from: s.date) else { continue }
            return Calendar.current.dateComponents([.day], from: d, to: today).day
        }
        return nil
    }

    /// 今天最该练的肌群：间隔最久、且已经过了 2 天恢复；从没练过的优先
    var trainTip: (group: String, days: Int?, urgent: Bool)? {
        let groups = ["胸", "背", "腿", "肩", "臂", "核心"]
        var neverGroup: String? = nil
        var bestGroup: String? = nil
        var bestDays = 0
        for g in groups {
            guard let d = daysSinceTrain(group: g) else {
                if neverGroup == nil { neverGroup = g }
                continue
            }
            if d >= 2, d > bestDays {
                bestGroup = g
                bestDays = d
            }
        }
        if let n = neverGroup { return (n, nil, true) }
        guard let b = bestGroup else { return nil }
        return (b, bestDays, bestDays >= 5)
    }

    // MARK: - 热量目标推算（Mifflin-St Jeor）

    /// 基础代谢：10×kg + 6.25×cm − 5×年龄 +（男 +5 / 女 −161）
    var bmr: Double {
        guard bodyWeight > 0, heightCM > 0 else { return 0 }
        let s: Double = sexMale ? 5 : -161
        return 10 * bodyWeight + 6.25 * heightCM - 5 * Double(age) + s
    }

    var activityFactor: Double {
        switch activityLevel {
        case 0: return 1.375
        case 2: return 1.725
        default: return 1.55
        }
    }

    /// 维持体重一天的总消耗
    var maintainKcal: Int {
        bmr > 0 ? Int((bmr * activityFactor).rounded()) : 0
    }

    /// 按“减脂 / 维持 / 增肌”给出的建议热量
    var recommendedKcal: Int {
        guard maintainKcal > 0 else { return 0 }
        switch goalMode {
        case 0: return max(1200, maintainKcal - 400)
        case 2: return maintainKcal + 300
        default: return maintainKcal
        }
    }

    var goalModeLabel: String {
        switch goalMode {
        case 0: return "减脂"
        case 2: return "增肌"
        default: return "维持"
        }
    }

    var activityLabel: String {
        switch activityLevel {
        case 0: return "少动"
        case 2: return "常练"
        default: return "一般"
        }
    }

    var stepsForDisplay: Int { max(pedometerSteps, max(watchSteps, steps)) }
    var watchStepsForDisplay: Int { watchSteps > 0 ? watchSteps : 0 }

    // MARK: - 变更

    func addMeal(_ m: MealEntry) {
        meals.append(m)
        dietKcal += m.kcal
        protein += m.protein
        carb += m.carb
        fat += m.fat
        veg += m.veg
        moveKcal += m.kcal * 0.06
        syncMealHistory()
        persistSoon()
    }

    /// 把识别到的食物按每 100g 的营养换算，存进「我的常吃」。同名覆盖。
    func saveAsCustom(_ hits: [FoodHit]) {
        for h in hits {
            guard h.grams > 0 else { continue }
            let k = 100.0 / h.grams
            let c = CustomFood(
                name: h.name,
                kcalPer100: (h.kcal * k).rounded(),
                proteinPer100: ((h.protein * k) * 10).rounded() / 10,
                carbPer100: ((h.carb * k) * 10).rounded() / 10,
                fatPer100: ((h.fat * k) * 10).rounded() / 10
            )
            if let i = customFoods.firstIndex(where: { $0.name == h.name }) {
                customFoods[i] = c
            } else {
                customFoods.append(c)
            }
        }
        if customFoods.count > 60 {
            customFoods.removeFirst(customFoods.count - 60)
        }
        persistSoon()
    }

    func deleteMeal(id: UUID) {
        guard let idx = meals.firstIndex(where: { $0.id == id }) else { return }
        let m = meals[idx]
        meals.remove(at: idx)
        dietKcal = max(0, dietKcal - m.kcal)
        protein = max(0, protein - m.protein)
        carb = max(0, carb - m.carb)
        fat = max(0, fat - m.fat)
        veg = max(0, veg - m.veg)
        moveKcal = max(0, moveKcal - m.kcal * 0.06)
        syncMealHistory()
        persistSoon()
        offerUndo("已删除「\(m.name)」") { [weak self] in
            guard let self else { return }
            self.meals.insert(m, at: min(idx, self.meals.count))
            self.dietKcal += m.kcal
            self.protein += m.protein
            self.carb += m.carb
            self.fat += m.fat
            self.veg += m.veg
            self.moveKcal += m.kcal * 0.06
            self.syncMealHistory()
            self.persist()
        }
    }

    func toggleFav(_ name: String) {
        if favoriteMoves.contains(name) {
            favoriteMoves.removeAll { $0 == name }
        } else {
            favoriteMoves.insert(name, at: 0)
        }
        persistSoon()
    }

    // MARK: - 身体数据

    func logWeight(_ kg: Double) {
        guard kg > 20, kg < 300 else { return }
        bodyWeight = kg
        let key = DateFormatter.twDay.string(from: Date())
        let entry = WeightLog(id: key, kg: kg)
        if let i = weightLogs.firstIndex(where: { $0.id == key }) {
            weightLogs[i] = entry
        } else {
            weightLogs.append(entry)
        }
        if weightLogs.count > 90 {
            weightLogs.removeFirst(weightLogs.count - 90)
        }
        persistSoon()
    }

    /// 按最近一次训练推断下一个该练的是哪天（同方案内轮转）
    var nextDayHint: (plan: String, day: String)? {
        guard let last = sessions.first else { return nil }
        guard let tpl = planTemplates.first(where: { $0.name == last.plan }) else {
            return (last.plan, last.day)
        }
        if let idx = tpl.days.firstIndex(where: { $0.title == last.day }) {
            let next = tpl.days[(idx + 1) % tpl.days.count]
            return (tpl.name, next.title)
        }
        return (tpl.name, tpl.days.first?.title ?? "")
    }

    var bmi: Double {
        guard bodyWeight > 0, heightCM > 0 else { return 0 }
        let h = heightCM / 100
        return bodyWeight / (h * h)
    }

    // MARK: - 饮水

    func addWater(_ cups: Int = 1) {
        waterCups = max(0, min(waterCups + cups, 30))
        persistSoon()
    }

    /// 直接记录任意毫升摄入：先凑整杯，余数记进零头
    func addWaterML(_ ml: Int) {
        guard ml != 0 else { return }
        let cup = max(1, cupSize)
        let cap = 30 * cup
        let total = min(max(0, waterML + ml), cap)
        waterCups = total / cup
        waterExtraML = total % cup
        persistSoon()
    }

    // MARK: - 围度历史

    func addSleep(start: Date, end: Date, acts: [Double]) {
        guard !acts.isEmpty, end > start else { return }
        let log = SleepLog(date: DateFormatter.twDay.string(from: start),
                           start: start, end: end, acts: acts)
        sleepLogs.insert(log, at: 0)
        if sleepLogs.count > 60 { sleepLogs.removeLast(sleepLogs.count - 60) }
        persist()
    }

    var lastSleep: SleepLog? { sleepLogs.first }

    // MARK: - 睡眠缺口与补觉建议

    /// 每晚目标睡眠分钟（7 小时 30 分）
    var sleepGoalMin: Int { 450 }

    /// 近 7 天累计睡眠缺口（分钟）。只统计有记录的夜晚。
    var sleepDebt: Int {
        let recent = Array(sleepLogs.prefix(7))
        guard !recent.isEmpty else { return 0 }
        let total = recent.reduce(0) { $0 + $1.durationMinutes }
        return max(0, sleepGoalMin * recent.count - total)
    }

    /// 建议今晚的睡眠时长：把缺口补一半，封顶 10 小时
    var sleepTonightMin: Int {
        min(sleepGoalMin + sleepDebt / 2, 600)
    }

    /// 按 7:00 起床倒推的建议入睡时间
    var sleepBedtimeText: String {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 7
        comps.minute = 0
        guard let wake = cal.date(from: comps) else { return "—" }
        var bed = wake.addingTimeInterval(-Double(sleepTonightMin) * 60)
        if bed > Date() { bed = bed.addingTimeInterval(-86_400) }
        return DateFormatter.twShort.string(from: bed)
    }

    var sleepAdviceTitle: String {
        switch sleepDebt {
        case 0..<31:   return "睡眠够了，保持现在的作息"
        case 31..<121: return "稍微欠一点，今晚提前睡"
        case 121..<241: return "欠得不少，今晚和明晚都要补"
        default:        return "债有点大，别靠周末一次补"
        }
    }

    var sleepAdviceBody: String {
        switch sleepDebt {
        case 0..<31:
            return "近 7 天平均都睡够了。固定起床时间比固定入睡时间更管用，早上同一时间见光，晚上更容易困。"
        case 31..<121:
            return "按 7 小时 30 分的目标，你还欠一点。今晚把入睡时间往前挪 30 分钟就能还上，别在白天靠咖啡硬撑。"
        case 121..<241:
            return "缺口已经积累到几个小时。今晚多睡 1 小时、明晚再多睡 1 小时，两天分开补比一次睡 10 小时更有效。"
        default:
            return "连续几晚都不足，反应速度和力量都会掉。今晚尽量提前 1.5 小时上床，把房间温度调低一点、屏幕提前 40 分钟放下。"
        }
    }

    func setPR(_ name: String, weight: Double, reps: Int) {
        guard reps > 0 else { return }
        let text: String
        if weight <= 0 {
            text = "自重 × \(reps)"
        } else if weight.truncatingRemainder(dividingBy: 1) == 0 {
            text = "\(Int(weight))kg × \(reps)"
        } else {
            text = String(format: "%.1fkg × %d", weight, reps)
        }
        prs[name] = text
        persistSoon()
    }

    func clearPR(_ name: String) {
        prs.removeValue(forKey: name)
        persistSoon()
    }

    // MARK: - 训练现场快照

    /// 组记录只活在内存里，App 被杀就全丢了；每记一组落一份快照
    func writePendingSession() {
        guard let start = sessionStart, sessionSets > 0 else { return }
        let snap = TWPendingSession(start: start, sets: sessionSets,
                                    tonnage: sessionTonnage, records: sessionRecords)
        pendingSession = snap
        if let data = try? JSONEncoder().encode(snap) {
            d.set(data, forKey: "tw.pendingSession.v1")
        }
    }

    func loadPendingSession() {
        guard let data = d.data(forKey: "tw.pendingSession.v1"),
              let snap = try? JSONDecoder().decode(TWPendingSession.self, from: data) else { return }
        // 隔夜的旧快照没有接上的意义
        guard Date().timeIntervalSince(snap.start) < 12 * 3600 else {
            d.removeObject(forKey: "tw.pendingSession.v1")
            return
        }
        pendingSession = snap
    }

    func resumePendingSession() {
        guard let snap = pendingSession else { return }
        sessionStart = snap.start
        sessionSets = snap.sets
        sessionTonnage = snap.tonnage
        sessionRecords = snap.records
        pendingSession = nil
        mood = "train"
        persistSoon()
    }

    func discardPendingSession() {
        pendingSession = nil
        d.removeObject(forKey: "tw.pendingSession.v1")
    }

    // MARK: - PR 与器械

    static func e1rm(_ weight: Double, _ reps: Int) -> Double {
        weight * (1 + Double(reps) / 30.0)
    }

    /// 每组都和历史最好比一次，破了就写 PR 并弹一下
    func notePR(move: String, weight: Double, reps: Int) {
        guard weight > 0, reps > 0, reps <= 30, !move.isEmpty else { return }
        let est = TWStore.e1rm(weight, reps)
        if est > (prBest[move] ?? 0) + 0.01 {
            prBest[move] = est
            setPR(move, weight: weight, reps: reps)
            prBurst = "\(move) 破了 · \(Int(est))kg 估算 1RM"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.prBurst = nil
            }
        }
    }

    func canDo(_ m: MoveItem) -> Bool { ownedGear.contains(m.equipment) }

    var availableMoves: [MoveItem] { allMoves.filter { canDo($0) } }

    // MARK: - 强度换算

    /// 60–90% 的常用强度，按这个动作的历史最好 e1RM 换算；点一下直接填进这一组
    func percentTable(move: String) -> [TWPctRow] {
        guard !move.isEmpty else { return [] }
        var best = prBest[move] ?? 0
        if best <= 0, let p = e1rmPoints(move: move, limit: 1).last { best = p.kg }
        guard best > 0 else { return [] }
        let rows: [(Int, Int)] = [(60, 15), (70, 12), (75, 10), (80, 8), (85, 6), (90, 4)]
        return rows.map { r in
            let kg = max(2.5, (best * Double(r.0) / 100 * 2).rounded() / 2)
            return TWPctRow(pct: r.0, kg: kg, reps: r.1)
        }
    }

    // MARK: - 停滞与过载

    /// 连续三周没破自己最好成绩的动作；没到 21 天的不算，免得刚开始练就报
    func stalledMoves(limit: Int = 3) -> [TWStallInfo] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = Calendar.current.startOfDay(for: Date())
        let names = Array(Set(prBest.keys).union(Set(sessions.flatMap { ($0.records ?? []).map { $0.move } })))
        var out: [TWStallInfo] = []
        for name in names {
            let pts = e1rmPoints(move: name, limit: 8)
            guard pts.count >= 4, let bestPoint = pts.max(by: { $0.kg < $1.kg }) else { continue }
            let best = bestPoint.kg
            let last = pts.last?.kg ?? best
            guard last <= best + 0.01, let bd = f.date(from: bestPoint.date) else { continue }
            let days = Calendar.current.dateComponents([.day], from: bd, to: today).day ?? 0
            if days >= 21 {
                out.append(TWStallInfo(move: name, days: days, best: best, last: last))
            }
        }
        return Array(out.sorted { $0.days > $1.days }.prefix(limit))
    }

    /// 某一周练了多少组（0 = 本周，1 = 上周）
    func weeklySetCount(_ weeksAgo: Int = 0) -> Int {
        let cal = Calendar.current
        guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start,
              let start = cal.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek) else { return 0 }
        let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return sessions.filter { s in
            guard let d = f.date(from: s.date) else { return false }
            return d >= start && d < end
        }.reduce(0) { $0 + $1.sets }
    }

    /// 本周组数比上周多 40% 以上就提醒，别硬堆
    var volumeJump: (pct: Int, now: Int, prev: Int)? {
        let now = weeklySetCount(0)
        let prev = weeklySetCount(1)
        guard prev >= 6, now > prev else { return nil }
        let pct = Int(((Double(now) / Double(prev)) - 1) * 100)
        return pct >= 40 ? (pct, now, prev) : nil
    }

    // MARK: - 热量随体重自适应

    /// 近两周体重的周均变化（kg/周）
    var weightTrendPerWeek: Double? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let pts = weightLogs.compactMap { w -> (Date, Double)? in
            guard let d = f.date(from: w.id), d >= cutoff, w.kg > 0 else { return nil }
            return (d, w.kg)
        }.sorted { $0.0 < $1.0 }
        guard pts.count >= 3, let a = pts.first, let b = pts.last else { return nil }
        let days = b.0.timeIntervalSince(a.0) / 86400
        guard days >= 7 else { return nil }
        return (b.1 - a.1) / days * 7
    }

    /// 实际趋势和目标差太多时给一个新热量；没差到值得改就不返回
    var adaptiveKcalAdvice: (target: Int, reason: String)? {
        guard bodyWeight > 0, let trend = weightTrendPerWeek else { return nil }
        let target: Double
        switch goalMode {
        case 0: target = -0.0075 * bodyWeight
        case 2: target = 0.0025 * bodyWeight
        default: target = 0
        }
        let tol = 0.0025 * bodyWeight
        let now = Int(dietTarget)
        let trendText = String(format: "%@%.2f kg/周", trend >= 0 ? "+" : "−", abs(trend))
        if trend < target - tol {
            let why: String
            switch goalMode {
            case 0: why = "掉得比目标快，容易连肌肉一起掉"
            case 2: why = "涨得比目标慢，热量还不够"
            default: why = "往下飘得有点快"
            }
            return (min(6000, now + 200), "近两周 \(trendText)，\(why)，先加 200 kcal")
        }
        if trend > target + tol {
            let why: String
            switch goalMode {
            case 0: why = "减得比目标慢"
            case 2: why = "涨得比目标快，多出来的多半是脂肪"
            default: why = "在往上飘"
            }
            return (max(800, now - 200), "近两周 \(trendText)，\(why)，建议收 200 kcal")
        }
        return nil
    }

    // MARK: - 饮食批量整理

    func deleteMeals(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let removed = meals.filter { ids.contains($0.id) }
        meals.removeAll { ids.contains($0.id) }
        applyMealDelta(removed)
        syncMealHistory()
        persistSoon()
    }

    func setMealSlot(ids: Set<UUID>, slot: String) {
        guard !ids.isEmpty else { return }
        for i in meals.indices where ids.contains(meals[i].id) { meals[i].slot = slot }
        syncMealHistory()
        persistSoon()
    }

    /// 记错日子的：从今天挪到昨天，两边统计一起改
    func moveMealsToYesterday(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let removed = meals.filter { ids.contains($0.id) }
        meals.removeAll { ids.contains($0.id) }
        applyMealDelta(removed)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let key = f.string(from: y)
        var list = mealHistory[key] ?? []
        list.append(contentsOf: removed)
        mealHistory[key] = list
        syncMealHistory()
        persistSoon()
    }

    private func applyMealDelta(_ removed: [MealEntry]) {
        for m in removed {
            dietKcal = max(0, dietKcal - m.kcal)
            protein = max(0, protein - m.protein)
            carb = max(0, carb - m.carb)
            fat = max(0, fat - m.fat)
            veg = max(0, veg - m.veg)
            moveKcal = max(0, moveKcal - m.kcal * 0.06)
        }
    }

    // MARK: - 备份提醒

    var backupDays: Int? {
        guard let d = TWStore.lastExportAt else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }

    var backupStale: Bool { (backupDays ?? 99) >= 14 }

    // MARK: - 补录

    /// 补一条过去的训练。合并到同一天的记录里，没那天就新建。
    /// 用「补录」作为方案名，和正常训练区分开，统计里照样算。
    func addBackfill(date: String, move: String, sets: Int, weight: Double, reps: Int) {
        guard sets > 0, reps > 0, !move.isEmpty else { return }
        let tonnage = Double(sets) * weight * Double(reps)
        let recs = (0..<sets).map { _ in
            SetRecord(move: move, weight: weight, reps: reps, date: date)
        }
        if let i = sessions.firstIndex(where: { $0.date == date }) {
            var s = sessions[i]
            s.moves += sets
            s.sets += sets
            s.minutes += max(15, sets * 3)
            s.tonnage = (s.tonnage ?? 0) + tonnage
            var names = s.moveNames ?? []
            if !names.contains(move) { names.append(move) }
            s.moveNames = names
            s.records = (s.records ?? []) + recs
            sessions[i] = s
        } else {
            sessions.append(SessionLog(
                date: date,
                plan: "补录",
                day: move,
                moves: sets,
                sets: sets,
                minutes: max(15, sets * 3),
                moveNames: [move],
                tonnage: tonnage,
                records: recs
            ))
        }
        sessions.sort { $0.date < $1.date }
        notePR(move: move, weight: weight, reps: reps)
        persistSoon()
    }

    // MARK: - 数据体检

    /// 找脏数据：空训练、体重单日跳变。只报告，不擅自删。
    func auditData() -> [TWDataIssue] {
        var out: [TWDataIssue] = []

        let zero = sessions.filter { $0.minutes <= 0 || $0.moves <= 0 }
        if !zero.isEmpty {
            out.append(TWDataIssue(
                title: "空训练记录 \(zero.count) 条",
                detail: "没记时长或没记动作，多半是误点「开始」又直接「结束」。可以一键清掉。",
                count: zero.count, kind: "zero"))
        }

        let bad = meals.filter { $0.kcal <= 0 || $0.grams <= 0 || $0.name.isEmpty }
        if !bad.isEmpty {
            out.append(TWDataIssue(
                title: "饮食记录不完整 \(bad.count) 条",
                detail: "没有克数或热量是 0，多半是识别失败后硬存进来的。可以一键清掉。",
                count: bad.count, kind: "meal"))
        }

        let sorted = weightLogs.sorted { $0.id < $1.id }
        var jumps: [String] = []
        var prev: WeightLog?
        for w in sorted {
            if let p = prev, abs(w.kg - p.kg) > 2.0 {
                jumps.append("\(p.id) → \(w.id)：\(String(format: "%.1f", p.kg)) → \(String(format: "%.1f", w.kg))")
            }
            prev = w
        }
        if !jumps.isEmpty {
            out.append(TWDataIssue(
                title: "体重单日跳变 \(jumps.count) 处",
                detail: jumps.prefix(2).joined(separator: "；") + (jumps.count > 2 ? " 等" : "") + "。多半是换了秤或手误，建议到身体页核对。",
                count: jumps.count, kind: "weight"))
        }

        return out
    }

    /// 体检发现的一键修：空训练 + 不完整饮食，返回处理了几条
    @discardableResult
    func cleanDataIssues() -> Int {
        var n = cleanZeroSessions()
        let bad = meals.filter { $0.kcal <= 0 || $0.grams <= 0 || $0.name.isEmpty }
        if !bad.isEmpty {
            meals.removeAll { $0.kcal <= 0 || $0.grams <= 0 || $0.name.isEmpty }
            applyMealDelta(bad)
            syncMealHistory()
            n += bad.count
        }
        if n > 0 { persistSoon() }
        return n
    }

    /// 清掉 0 时长、0 动作的训练记录，返回删了几条
    @discardableResult
    func cleanZeroSessions() -> Int {
        let before = sessions.count
        sessions.removeAll { $0.minutes <= 0 || $0.moves <= 0 }
        let n = before - sessions.count
        if n > 0 { persistSoon() }
        return n
    }

    // MARK: - 训练节奏（供本周日历和智能提醒用）

    /// 最近一次训练距今几天；从没练过返回 999
    func gapDays() -> Int {
        let cal = Calendar.current
        guard let last = sessions.compactMap({ DateFormatter.twDay.date(from: $0.date) }).max() else { return 999 }
        return cal.dateComponents([.day],
                                  from: cal.startOfDay(for: last),
                                  to: cal.startOfDay(for: Date())).day ?? 0
    }

    /// 本周（周一起算）练了几次
    func weeklyDone() -> Int {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let offset = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -offset,
                                    to: cal.startOfDay(for: today)) else { return 0 }
        let keys = Set(sessions.map { $0.date })
        return (0..<7)
            .compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
            .filter { keys.contains(DateFormatter.twDay.string(from: $0)) }
            .count
    }

    /// 近三周里最常练的星期几（1=周日 … 7=周六）。没有计划表时，
    /// 用它推「你通常会在这几天练」，比硬编码周几更贴合实际。
    func habitWeekdays(limit: Int = 3) -> Set<Int> {
        let cal = Calendar.current
        var counts: [Int: Int] = [:]
        for s in sessions.prefix(60) {
            guard let d = DateFormatter.twDay.date(from: s.date) else { continue }
            guard let diff = cal.dateComponents([.day], from: d, to: Date()).day, diff <= 21 else { continue }
            counts[cal.component(.weekday, from: d), default: 0] += 1
        }
        return Set(counts.sorted { $0.value > $1.value }.prefix(limit).map { $0.key })
    }

    /// 把导出的 JSON 落成一个真实的 .json 文件，交给系统分享面板存到「文件」或发给自己
    func exportJSONFile() -> URL? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let name = "Persist-数据备份-\(f.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try exportJSON().data(using: .utf8)?.write(to: url, options: .atomic)
            d.set(Date().timeIntervalSince1970, forKey: "tw.lastExport.v1")
            return url
        } catch {
            return nil
        }
    }

    /// 导出一份 CSV：训练、每组明细、饮食、体重、围度五段，Excel / 表格软件直接能开
    func exportCSV() -> String {
        func q(_ raw: String) -> String {
            if raw.contains(",") || raw.contains("\"") || raw.contains("\n") {
                return "\"" + raw.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return raw
        }

        var lines: [String] = []
        lines.append("Persist 数据导出, \(todayKey())")
        lines.append("")

        lines.append("【训练记录】")
        lines.append("日期,方案,当天主题,动作数,组数,时长分,总容量kg,动作")
        for s in sessions {
            lines.append([s.date, q(s.plan), q(s.day), "\(s.moves)", "\(s.sets)", "\(s.minutes)",
                          String(format: "%.0f", s.tonnage ?? 0),
                          q((s.moveNames ?? []).joined(separator: " / "))].joined(separator: ","))
        }
        lines.append("")

        lines.append("【每组明细】")
        lines.append("日期,动作,重量kg,次数")
        for s in sessions {
            for r in (s.records ?? []) {
                lines.append([r.date, q(r.move), String(format: "%.1f", r.weight), "\(r.reps)"].joined(separator: ","))
            }
        }
        lines.append("")

        lines.append("【饮食记录】")
        lines.append("日期,餐次,食物,克数,热量,蛋白g,碳水g,脂肪g")
        var mealKeys = mealHistory.keys.sorted()
        let today = todayKey()
        if !meals.isEmpty, !mealKeys.contains(today) { mealKeys.append(today) }
        for k in mealKeys {
            let list = (k == today && !meals.isEmpty) ? meals : (mealHistory[k] ?? [])
            for m in list {
                lines.append([k, q(m.slot ?? "加餐"), q(m.name),
                              String(format: "%.0f", m.grams),
                              String(format: "%.0f", m.kcal),
                              String(format: "%.1f", m.protein),
                              String(format: "%.1f", m.carb),
                              String(format: "%.1f", m.fat)].joined(separator: ","))
            }
        }
        lines.append("")

        lines.append("【体重记录】")
        lines.append("日期,体重kg")
        for w in weightLogs {
            lines.append([w.id, String(format: "%.1f", w.kg)].joined(separator: ","))
        }
        lines.append("")

        lines.append("【围度记录】")
        lines.append("日期,胸cm,腰cm,臀cm,臂cm,腿cm")
        for g in girthLogs {
            lines.append([g.id,
                          String(format: "%.1f", g.chest),
                          String(format: "%.1f", g.waist),
                          String(format: "%.1f", g.hip),
                          String(format: "%.1f", g.arm),
                          String(format: "%.1f", g.thigh)].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// 把 CSV 落成文件，交给分享面板
    func exportCSVFile() -> URL? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let name = "Persist-数据-\(f.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        // 带 BOM，Excel 打开中文不乱码
        let bom = "\u{FEFF}"
        guard let data = (bom + exportCSV()).data(using: .utf8) else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 上次导出备份的时间；没导过就是 nil
    static var lastExportAt: Date? {
        let t = UserDefaults.standard.double(forKey: "tw.lastExport.v1")
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// 导出全部本机数据为 JSON 文本
    func exportJSON() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var root: [String: Any] = [:]
        root["exportedAt"] = f.string(from: Date())
        root["app"] = "Persist 3.0"
        // 备份格式版本：以后加字段靠它判断要不要迁移
        root["schemaVersion"] = 2
        root["build"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        root["commit"] = Bundle.main.infoDictionary?["TWCommit"] as? String ?? ""
        root["steps"] = pedometerSteps
        root["distanceM"] = pedometerDistance
        root["hr"] = measuredHR
        root["hrv"] = measuredHRV
        root["hrSource"] = hrSource
        root["mood"] = mood
        root["dietTarget"] = dietTarget
        root["proteinGoal"] = proteinGoal
        root["weeklyGoal"] = weeklyGoal
        root["dietKcal"] = dietKcal
        root["protein"] = protein
        root["carb"] = carb
        root["fat"] = fat
        root["waterCups"] = waterCups
        root["waterExtraML"] = waterExtraML
        root["cupSize"] = cupSize
        root["bodyWeight"] = bodyWeight
        root["heightCM"] = heightCM
        root["waistCM"] = waistCM
        root["chestCM"] = chestCM
        root["armCM"] = armCM
        root["thighCM"] = thighCM
        root["hipCM"] = hipCM
        root["weightGoal"] = weightGoal
        root["favoriteMoves"] = favoriteMoves

        if let data = try? JSONEncoder().encode(meals),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["meals"] = obj
        }
        if let data = try? JSONEncoder().encode(logs),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["dailyLogs"] = obj
        }
        if let data = try? JSONEncoder().encode(weightLogs),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["weightLogs"] = obj
        }
        if let data = try? JSONEncoder().encode(girthLogs),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["girthLogs"] = obj
        }
        if let data = try? JSONEncoder().encode(sessions),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["sessions"] = obj
        }
        if let data = try? JSONEncoder().encode(customFoods),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            root["customFoods"] = obj
        }

        guard let data = try? JSONSerialization.data(withJSONObject: root,
                                                    options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    struct ImportError: LocalizedError {
        var errorDescription: String? { "这不是Persist的备份文件，或者文件已经损坏" }
    }

    /// 把导出的 JSON 回灌进来。换手机、重装之后靠这个捡回历史。
    @discardableResult
    func importJSON(_ data: Data) throws -> Int {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["app"] as? String).map({ $0.contains("Persist") || $0.contains("天才威") }) == true else {
            TWLog.add("import", "导入失败：不是 Persist 的备份文件（改名前的旧备份也认）")
            throw ImportError()
        }
        // 老备份没有这个字段，按 1 处理；以后加字段靠它判断要不要迁移
        let schema = (root["schemaVersion"] as? NSNumber)?.intValue ?? 1
        TWLog.add("import", "开始导入 · schema \(schema)")
        // 覆盖之前先给当前数据留一份快照，恢复错了还能回滚
        TWBackup.writeNow(build: exportJSON())

        func dec<T: Decodable>(_ key: String, _ type: T.Type) -> T? {
            guard let v = root[key],
                  let d = try? JSONSerialization.data(withJSONObject: v) else { return nil }
            return try? JSONDecoder().decode(T.self, from: d)
        }
        func int(_ key: String) -> Int? { (root[key] as? NSNumber)?.intValue }
        func dbl(_ key: String) -> Double? { (root[key] as? NSNumber)?.doubleValue }

        var restored = 0

        if let v = int("steps") { pedometerSteps = v; restored += 1 }
        if let v = dbl("distanceM") { pedometerDistance = v }
        if let v = int("hr") { measuredHR = v; hr = v }
        if let v = int("hrv") { measuredHRV = v; hrv = v }
        if let v = root["hrSource"] as? String { hrSource = v }
        if let v = root["mood"] as? String { mood = v }
        if let v = dbl("dietTarget") { dietTarget = v }
        if let v = dbl("proteinGoal") { proteinGoal = v }
        if let v = int("weeklyGoal") { weeklyGoal = min(7, max(1, v)) }
        if let v = dbl("dietKcal") { dietKcal = v }
        if let v = dbl("protein") { protein = v }
        if let v = dbl("carb") { carb = v }
        if let v = dbl("fat") { fat = v }
        if let v = int("waterCups") { waterCups = v }
        if let v = int("waterExtraML") { waterExtraML = v }
        if let v = int("cupSize") { cupSize = v }
        if let v = dbl("bodyWeight") { bodyWeight = v }
        if let v = dbl("heightCM") { heightCM = v }
        if let v = dbl("waistCM") { waistCM = v }
        if let v = dbl("chestCM") { chestCM = v }
        if let v = dbl("armCM") { armCM = v }
        if let v = dbl("thighCM") { thighCM = v }
        if let v = dbl("hipCM") { hipCM = v }
        if let v = dbl("weightGoal") { weightGoal = v }
        if let v = root["favoriteMoves"] as? [String] { favoriteMoves = v }

        if let v = dec("meals", [MealEntry].self) { meals = v; restored += v.count }
        if let v = dec("dailyLogs", [DayLog].self) { logs = v }
        if let v = dec("weightLogs", [WeightLog].self) { weightLogs = v }
        if let v = dec("girthLogs", [GirthLog].self) { girthLogs = v }
        if let v = dec("sessions", [SessionLog].self) { sessions = v }
        if let v = dec("customFoods", [CustomFood].self) { customFoods = v }

        lastDayKey = DateFormatter.twDay.string(from: Date())
        persist()
        TWLog.add("import", "导入完成 · 找回 \(restored) 条")
        return restored
    }

    /// 清空本机全部数据
    func resetAll() {
        for key in d.dictionaryRepresentation().keys where key.hasPrefix("tw.") {
            d.removeObject(forKey: key)
        }

        moveKcal = 0
        exerciseMin = 0
        standHours = 0
        hrv = 0
        steps = 0
        hr = 0
        restingHR = 0
        pedometerSteps = 0
        pedometerDistance = 0
        measuredHR = 0
        measuredHRV = 0
        measuredAt = nil
        hrSource = ""
        watchSteps = 0
        dietKcal = 0
        protein = 0
        carb = 0
        fat = 0
        veg = 0
        meals = []
        mealHistory = [:]
        mood = "ok"
        sessionStart = nil
        sessionSets = 0
        sessionMoves = []
        sessionTonnage = 0
        sessionRecords = []
        dietTarget = 2200
        proteinGoal = 120
        logs = []
        favoriteMoves = []
        bodyWeight = 0
        heightCM = 0
        waistCM = 0
        chestCM = 0
        armCM = 0
        thighCM = 0
        hipCM = 0
        weightGoal = 0
        weightLogs = []
        sessions = []
        girthLogs = []
        waterCups = 0
        waterExtraML = 0
        cupSize = 250
        customFoods = []
        planPick = 0
        dayPick = 0
        prs = [:]
        sleepLogs = []
        watchSleepMin = 0
        watchDeepMin = 0
        watchSyncAt = nil
        watchSyncCount = 0
        mindfulMin = 0
        mindfulAt = nil
        mealPhotos = [:]

        // 分文件里的也要清，否则下次启动又读回来
        TWFiles.removeAll()
        heavyLoaded = true
        TWLog.add("store", "已清空全部本机数据")
        persist()
    }

    func setPlan(_ plan: Int, day: Int = 0) {
        planPick = plan
        dayPick = day
        persistSoon()
    }

    func logGirth() {
        guard waistCM > 0 || chestCM > 0 || armCM > 0 || thighCM > 0 || hipCM > 0 else { return }
        let key = DateFormatter.twDay.string(from: Date())
        let entry = GirthLog(id: key, waist: waistCM, chest: chestCM,
                             arm: armCM, thigh: thighCM, hip: hipCM)
        if let i = girthLogs.firstIndex(where: { $0.id == key }) {
            girthLogs[i] = entry
        } else {
            girthLogs.append(entry)
        }
        if girthLogs.count > 90 {
            girthLogs.removeFirst(girthLogs.count - 90)
        }
        persistSoon()
    }

    // MARK: - 自定义食物

    func addCustomFood(_ f: CustomFood) {
        customFoods.insert(f, at: 0)
        if customFoods.count > 60 {
            customFoods.removeLast(customFoods.count - 60)
        }
        persistSoon()
    }

    func removeCustomFood(id: UUID) {
        customFoods.removeAll { $0.id == id }
        persistSoon()
    }

    /// 跨天自动归零：饮食、步数、锻炼、站立、活动能量、饮水全部回到当天起点，
    /// 昨天的餐食先归档进 mealHistory（可在「历史」里翻）。
    func rollIfNewDay() {
        let today = todayKey()
        guard lastDayKey != today else { return }

        // 归档昨天的饮食明细
        if !meals.isEmpty {
            mealHistory[lastDayKey.isEmpty ? today : lastDayKey] = meals
            if mealHistory.count > 40 {
                for k in mealHistory.keys.sorted().prefix(mealHistory.count - 40) {
                    mealHistory.removeValue(forKey: k)
                }
            }
        }

        // 清零之前先把昨天这一格定格：步数、心率、活动能量存的都该是“昨天走完的最终值”
        snapshot(dayKey: lastDayKey.isEmpty ? today : lastDayKey)

        meals.removeAll()
        dietKcal = 0
        protein = 0
        carb = 0
        fat = 0
        veg = 0

        pedometerSteps = 0
        pedometerDistance = 0
        watchSteps = 0
        exerciseMin = 0
        moveKcal = 0
        standHours = 0

        waterCups = 0
        waterExtraML = 0

        lastDayKey = today
        persist()
    }

    func resetToday() {
        meals.removeAll()
        dietKcal = 0
        protein = 0
        carb = 0
        fat = 0
        veg = 0
        syncMealHistory()
        persistSoon()
    }

    // MARK: - 复制昨天

    private func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    /// 把今天的餐食快照写进历史
    private func syncMealHistory() {
        let key = todayKey()
        if meals.isEmpty {
            mealHistory[key] = nil
        } else {
            mealHistory[key] = meals
        }
        if mealHistory.count > 40 {
            let sorted = mealHistory.keys.sorted()
            for k in sorted.prefix(mealHistory.count - 40) { mealHistory.removeValue(forKey: k) }
        }
    }

    /// 昨天的某一餐（没记录返回空）
    func yesterdayMeals(slot: String) -> [MealEntry] {
        guard let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return [] }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: y)
        let list = mealHistory[key] ?? []
        guard !slot.isEmpty else { return list }
        return list.filter { ($0.slot ?? "午餐") == slot }
    }

    /// 把昨天同餐次复制进今天，新 id。返回复制了几条。
    @discardableResult
    func copyYesterday(slot: String = "全部") -> Int {
        guard let y = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return 0 }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let all = mealHistory[f.string(from: y)] ?? []
        let src = slot == "全部" ? all : all.filter { ($0.slot ?? "午餐") == slot }
        guard !src.isEmpty else { return 0 }
        for m in src {
            addMeal(MealEntry(name: m.name, grams: m.grams, kcal: m.kcal,
                              protein: m.protein, carb: m.carb, fat: m.fat, veg: m.veg,
                              slot: m.slot ?? slot, time: Date()))
        }
        return src.count
    }

    // MARK: - 快捷复现 & 力量曲线

    /// 查本机条码库
    func barcodeNote(_ code: String) -> BarcodeNote? {
        barcodeNotes[code.trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// 存一条条码。超过 400 条就丢最旧的，不至于把 UserDefaults 撑爆。
    func saveBarcodeNote(_ n: BarcodeNote) {
        var t = n
        t.code = t.code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.code.count >= 6, !t.name.isEmpty else { return }
        if t.at.timeIntervalSince1970 == 0 { t.at = Date() }
        barcodeNotes[t.code] = t
        if barcodeNotes.count > 400 {
            let old = barcodeNotes.values.sorted { $0.at < $1.at }
            for o in old.prefix(barcodeNotes.count - 400) {
                barcodeNotes.removeValue(forKey: o.code)
            }
        }
        persistSoon()
    }

    func removeBarcodeNote(_ code: String) {
        barcodeNotes.removeValue(forKey: code)
        persistSoon()
    }

    /// 最近吃过的食物：今天的 + 近 7 天归档，按名字去重，越近越前。
    func recentMeals(limit: Int = 12) -> [MealEntry] {
        var out: [MealEntry] = []
        var seen = Set<String>()
        for m in meals.reversed() {
            let k = m.name.lowercased()
            if seen.contains(k) { continue }
            seen.insert(k)
            out.append(m)
        }
        for key in mealHistory.keys.sorted(by: >).prefix(7) {
            for m in (mealHistory[key] ?? []).reversed() {
                let k = m.name.lowercased()
                if seen.contains(k) { continue }
                seen.insert(k)
                out.append(m)
            }
        }
        return Array(out.prefix(limit))
    }

    /// 某动作的力量曲线：每天取最高 e1RM（Epley：w × (1 + reps/30)）。
    /// 老记录没有 records 就跳过，不会凭空造点。
    func e1rmPoints(move: String, limit: Int = 14) -> [E1RMPoint] {
        guard !move.isEmpty else { return [] }
        var best: [String: E1RMPoint] = [:]
        for s in sessions {
            guard let recs = s.records else { continue }
            for r in recs where r.move == move && r.weight > 0 && r.reps > 0 {
                let e = r.weight * (1 + Double(r.reps) / 30.0)
                let d = r.date.isEmpty ? s.date : r.date
                if let old = best[d], old.kg >= e { continue }
                best[d] = E1RMPoint(date: d, kg: e, reps: r.reps, weight: r.weight)
            }
        }
        let arr = best.values.sorted { $0.date < $1.date }
        return Array(arr.suffix(limit))
    }

    func setMood(_ m: String) {
        mood = m
        persistSoon()
    }

    func recordHeart(rate: Int, variability: Int, source: String) {
        measuredHR = rate
        measuredHRV = variability
        measuredAt = Date()
        hrSource = source
        hr = rate
        hrv = variability
        persistSoon()
    }

    func startSession(moves: [String]) {
        discardPendingSession()
        sessionStart = Date()
        sessionSets = 0
        sessionMoves = moves
        sessionTonnage = 0
        sessionRecords = []
        mood = "train"
        persistSoon()
    }

    func addSet(weight: Double = 0, reps: Int = 0, move: String = "", rir: Int? = nil) {
        sessionSets += 1
        if weight > 0, reps > 0 {
            sessionTonnage += weight * Double(reps)
            // 动作名拿得到才记明细，拿不到就只算总量
            if !move.isEmpty {
                sessionRecords.append(SetRecord(move: move,
                                                weight: weight,
                                                reps: reps,
                                                date: DateFormatter.twDay.string(from: Date()),
                                                rir: rir))
            }
        }
        exerciseMin += 2.5
        moveKcal += 22
        standHours = min(standHours + 0.15, standTarget)
        notePR(move: move, weight: weight, reps: reps)
        writePendingSession()
        persistSoon()
    }

    @discardableResult
    func endSession(plan: String = "", day: String = "", moves: Int = 0, moveNames: [String] = []) -> SessionLog? {
        let start = sessionStart ?? Date()
        let mins = max(1, Int(Date().timeIntervalSince(start) / 60))
        var added: SessionLog? = nil
        if sessionSets > 0 {
            let entry = SessionLog(
                date: DateFormatter.twDay.string(from: Date()),
                plan: plan,
                day: day,
                moves: moves,
                sets: sessionSets,
                minutes: mins,
                moveNames: moveNames,
                tonnage: sessionTonnage > 0 ? sessionTonnage : nil,
                records: sessionRecords.isEmpty ? nil : sessionRecords
            )
            sessions.insert(entry, at: 0)
            added = entry
            if sessions.count > 90 {
                sessions.removeLast(sessions.count - 90)
            }
        }
        sessionStart = nil
        sessionTonnage = 0
        sessionRecords = []
        pendingSession = nil
        d.removeObject(forKey: "tw.pendingSession.v1")
        mood = "win"
        upsertToday()
        persistSoon()
        return added
    }

    /// 某个动作最近一次练到的重量/次数。没有明细的老记录会跳过。
    func lastRecord(move: String) -> SetRecord? {
        for s in sessions {
            guard let rs = s.records else { continue }
            if let r = rs.last(where: { $0.move == move }) { return r }
        }
        return nil
    }

    /// 上一次练这个动作时每一组的成绩，按当时做的顺序。
    /// 「上次 20×8、20×8、20×7」比只给一个好最后一组，才知道该不该加重量。
    func lastSets(move: String) -> [SetRecord] {
        for s in sessions {
            guard let rs = s.records else { continue }
            let hit = rs.filter { $0.move == move }
            if !hit.isEmpty { return hit }
        }
        return []
    }

    /// 最近 days 天每个肌群做了多少组。动作名去动作库查肌群。
    func weeklyGroupSets(days: Int = 7) -> [(group: String, sets: Int)] {
        let cal = Calendar.current
        let from = cal.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        let cutoff = DateFormatter.twDay.string(from: from)
        var map: [String: Int] = [:]
        for s in sessions where s.date >= cutoff {
            guard let rs = s.records else { continue }
            for r in rs {
                let g = allMoves.first(where: { $0.name == r.move })?.group ?? "其它"
                map[g, default: 0] += 1
            }
        }
        return map.sorted { $0.value > $1.value }.map { (group: $0.key, sets: $0.value) }
    }

    /// 渐进超负荷：上次把目标次数做满就加 2.5kg；没做满就维持上次重量。
    func suggestWeight(move: String, targetReps: Int) -> Double? {
        guard let last = lastRecord(move: move), last.weight > 0 else { return nil }
        return last.reps >= targetReps ? min(500, last.weight + 2.5) : last.weight
    }

    /// 带说明的建议：重量、次数、以及为什么是这个数
    func suggestFor(move: String, targetReps: Int) -> WeightSuggestion? {
        guard let last = lastRecord(move: move), last.weight > 0 else { return nil }
        let t = max(1, targetReps)
        var kg = last.weight
        var note: String
        if last.reps >= t {
            // 次数做满但已经力竭，说明这个重量到头了，再加就要掉次数
            if let r = last.rir, r <= 1 {
                note = "上次 \(String(format: "%g", last.weight))kg × \(last.reps) 次已经力竭（RIR \(r)），这组先守住 \(String(format: "%g", kg))kg"
            } else {
                kg = min(500, last.weight + 2.5)
                note = "上次 \(String(format: "%g", last.weight))kg × \(last.reps) 次做满了，这组加到 \(String(format: "%g", kg))kg"
            }
        } else {
            note = "上次只做到 \(last.reps) 次，先守住 \(String(format: "%g", kg))kg 把 \(t) 次做满"
        }
        if let best = e1rmPoints(move: move, limit: 3).max(by: { $0.kg < $1.kg }) {
            let est = best.kg / (1 + Double(t) / 30)
            if est >= kg + 5 {
                note += "；按最近最好成绩还能到 \(String(format: "%.1f", est))kg"
            }
        }
        return WeightSuggestion(kg: kg, reps: t, note: note)
    }

    /// 从今天往前数，连续有训练记录的天数。今天还没练时允许从昨天起算。
    var trainingStreak: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var day = Date()
        var streak = 0
        var skipToday = true
        while streak < 400 {
            let key = f.string(from: day)
            if sessions.contains(where: { $0.date == key }) {
                streak += 1
                skipToday = false
            } else if skipToday && Calendar.current.isDateInToday(day) {
                skipToday = false
            } else {
                break
            }
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    // MARK: - 删除撤销

    /// 删除后给 6 秒反悔时间。commit 是过期后真正落地的动作（比如真删文件）
    func offerUndo(_ text: String, restore: @escaping () -> Void, commit: (() -> Void)? = nil) {
        // 上一条还没过期就先把它的收尾动作执行掉
        undoCommit?()
        undoWork?.cancel()
        undoCommit = commit

        withAnimation(.snappy(duration: 0.25)) { undo = TWUndoAction(text: text, run: restore) }

        let w = DispatchWorkItem { [weak self] in
            self?.undoCommit?()
            self?.undoCommit = nil
            withAnimation(.snappy(duration: 0.25)) { self?.undo = nil }
        }
        undoWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: w)
    }

    func runUndo() {
        undoWork?.cancel()
        undoCommit = nil
        undo?.run()
        withAnimation(.snappy(duration: 0.25)) { undo = nil }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        persistSoon()
    }

    // MARK: - 进度照

    var progressDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("progressPhotos", isDirectory: true)
    }

    private static let progressCache = NSCache<NSString, UIImage>()

    @discardableResult
    func addProgressPhoto(_ img: UIImage, note: String) -> Bool {
        // 压到 1200 宽，别让一张原图占十几兆
        let maxW: CGFloat = 1200
        let scale = img.size.width > maxW ? maxW / img.size.width : 1
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = out.jpegData(compressionQuality: 0.82) else { return false }

        let name = "\(UUID().uuidString).jpg"
        let dir = progressDir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent(name), options: .atomic)
        } catch { return false }

        let p = ProgressPhoto(date: DateFormatter.twDay.string(from: Date()),
                              file: name, note: note, kg: bodyWeight)
        progressPhotos.insert(p, at: 0)
        Self.progressCache.setObject(out, forKey: name as NSString)

        if progressPhotos.count > 40 {
            for old in progressPhotos.dropFirst(40) {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(old.file))
            }
            progressPhotos = Array(progressPhotos.prefix(40))
        }
        persistSoon()
        return true
    }

    func progressImage(_ p: ProgressPhoto) -> UIImage? {
        if let c = Self.progressCache.object(forKey: p.file as NSString) { return c }
        guard let img = UIImage(contentsOfFile: progressDir.appendingPathComponent(p.file).path) else { return nil }
        Self.progressCache.setObject(img, forKey: p.file as NSString)
        return img
    }

    func deleteProgressPhoto(_ p: ProgressPhoto) {
        progressPhotos.removeAll { $0.id == p.id }
        persistSoon()
        offerUndo("已删除这张进度照", restore: { [weak self] in
            guard let self else { return }
            self.progressPhotos.append(p)
            self.progressPhotos.sort { $0.date > $1.date }
            self.persist()
        }, commit: { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.progressDir.appendingPathComponent(p.file))
            Self.progressCache.removeObject(forKey: p.file as NSString)
        })
    }

    // MARK: - 餐食照片

    var photoDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mealPhotos", isDirectory: true)
    }

    func photoURL(_ name: String) -> URL {
        photoDir.appendingPathComponent(name)
    }

    var todayPhotos: [String] {
        mealPhotos[DateFormatter.twDay.string(from: Date())] ?? []
    }

    @discardableResult
    func saveMealPhoto(data: Data) -> String? {
        let name = "\(UUID().uuidString).jpg"
        let dir = photoDir
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: dir.appendingPathComponent(name), options: .atomic)
        } catch {
            return nil
        }

        let key = DateFormatter.twDay.string(from: Date())
        mealPhotos[key, default: []].append(name)

        // 只留最近 40 天，文件和索引一起删
        if mealPhotos.count > 40 {
            for k in mealPhotos.keys.sorted().prefix(mealPhotos.count - 40) {
                for f in mealPhotos[k] ?? [] {
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
                }
                mealPhotos.removeValue(forKey: k)
            }
        }
        persistSoon()
        return name
    }

    // MARK: - 每日

    /// 把某一天当下的数值定格进 logs 的对应格。
    /// 传 dayKey 是为了跨天时能把“昨天”写回昨天那一格，而不是写到今天头上。
    func snapshot(dayKey: String) {
        let entry = DayLog(
            id: dayKey,
            steps: stepsForDisplay,
            hr: measuredHR,
            hrv: measuredHRV,
            moveKcal: moveKcal,
            exerciseMin: exerciseMin,
            kcal: dietKcal,
            protein: protein,
            carb: carb,
            fat: fat
        )
        if let i = logs.firstIndex(where: { $0.id == dayKey }) {
            logs[i] = entry
        } else {
            logs.append(entry)
        }
        if logs.count > 30 {
            logs.removeFirst(logs.count - 30)
        }
        persistSoon()
    }

    func upsertToday() {
        snapshot(dayKey: DateFormatter.twDay.string(from: Date()))
    }

    var last7: [DayLog] {
        Array(logs.suffix(7))
    }

    // MARK: - 持久化

    func persistSoon() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func persist() {
        d.set(measuredHR, forKey: Key.hr)
        d.set(measuredHRV, forKey: Key.hrv)
        d.set(hrSource, forKey: Key.hrSrc)
        d.set(pedometerSteps, forKey: Key.steps)
        d.set(pedometerDistance, forKey: Key.dist)
        d.set(mood, forKey: Key.mood)
        d.set(dietKcal, forKey: Key.kcal)
        d.set(protein, forKey: Key.protein)
        d.set(carb, forKey: Key.carb)
        d.set(fat, forKey: Key.fat)
        d.set(veg, forKey: Key.veg)
        d.set(exerciseMin, forKey: Key.exercise)
        d.set(moveKcal, forKey: Key.moveK)
        d.set(standHours, forKey: Key.stand)

        if let at = measuredAt {
            d.set(at.timeIntervalSince1970, forKey: Key.hrAt)
        }
        if heavyLoaded {
            // 三个大数组走分文件，后台写；没读完之前一律不落盘
            TWFiles.writeAsync(meals, name: "meals.json")
            TWFiles.writeAsync(mealPhotos, name: "mealPhotos.json")
            TWFiles.writeAsync(sessions, name: "sessions.json")
        }
        if let v = try? JSONEncoder().encode(barcodeNotes) {
            d.set(v, forKey: "tw.barcodes.v3")
        }
        if let v = try? JSONEncoder().encode(logs) {
            d.set(v, forKey: Key.logs)
        }
        d.set(favoriteMoves, forKey: Key.fav)

        d.set(dietTarget, forKey: Key.dt)
        d.set(proteinGoal, forKey: Key.pgoal)
        d.set(weeklyGoal, forKey: Key.weekly)
        d.set(age, forKey: "tw.age.v3")
        d.set(sexMale, forKey: "tw.sexMale.v3")
        d.set(activityLevel, forKey: "tw.activity.v3")
        d.set(goalMode, forKey: "tw.goalMode.v3")
        d.set(waterTarget, forKey: Key.wt)
        d.set(bodyWeight, forKey: Key.weight)
        d.set(heightCM, forKey: Key.height)
        d.set(waistCM, forKey: Key.waist)
        d.set(waterCups, forKey: Key.water)
        d.set(waterExtraML, forKey: Key.wextra)
        d.set(DateFormatter.twDay.string(from: Date()), forKey: Key.waterDay)
        d.set(cupSize, forKey: Key.cupsize)

        if let v = try? JSONEncoder().encode(weightLogs) {
            d.set(v, forKey: Key.wlogs)
        }
        if let v = try? JSONEncoder().encode(customFoods) {
            d.set(v, forKey: Key.cfoods)
        }
        d.set(watchSpO2, forKey: Key.spo2)
        if let at = watchSpO2At { d.set(at.timeIntervalSince1970, forKey: Key.spo2At) }
        if let v = try? JSONEncoder().encode(customPlans) {
            d.set(v, forKey: Key.cplans)
        }
        d.set(restOverride, forKey: Key.restOv)
        d.set(lastDayKey, forKey: Key.dayKey)
        if let v = try? JSONEncoder().encode(mealHistory) {
            d.set(v, forKey: Key.mhist)
        }
        d.set(weightGoal, forKey: Key.wgoal)
        d.set(chestCM, forKey: Key.chest)
        d.set(armCM, forKey: Key.arm)
        d.set(thighCM, forKey: Key.thigh)
        d.set(hipCM, forKey: Key.hip)
        if let v = try? JSONEncoder().encode(girthLogs) {
            d.set(v, forKey: Key.glogs)
        }
        d.set(planPick, forKey: Key.planpick)
        d.set(dayPick, forKey: Key.daypick)
        if let v = try? JSONEncoder().encode(prs) {
            d.set(v, forKey: Key.prs)
        }
        if let v = try? JSONEncoder().encode(prBest) {
            d.set(v, forKey: Key.prBest)
        }
        d.set(Array(ownedGear), forKey: Key.gear)
        d.set(lockEnabled, forKey: Key.lock)
        if let v = try? JSONEncoder().encode(sleepLogs) {
            d.set(v, forKey: Key.sleeps)
        }
        d.set(watchSleepMin, forKey: Key.wsleep)
        d.set(watchDeepMin, forKey: Key.wdeep)
        d.set(manualSleepMin, forKey: Key.msleep)
        d.set(manualRestingHR, forKey: Key.mhr)
        d.set(manualHRV, forKey: Key.mhrv)
        d.set(watchSyncCount, forKey: Key.wcount)
        if let t = watchSyncAt { d.set(t.timeIntervalSince1970, forKey: Key.wsync) }
        d.set(mindfulMin, forKey: Key.mindmin)
        if let t = mindfulAt { d.set(t.timeIntervalSince1970, forKey: Key.mindat) }
        if let v = try? JSONEncoder().encode(progressPhotos) {
            d.set(v, forKey: "tw.progressPhotos.v1")
        }

        // 每天顺手落一份完整 JSON 到 Documents/twbackup/，plist 坏了还能从这捡回来
        TWBackup.maybeAutoBackup(build: { [weak self] in self?.exportJSON() ?? "{}" }) { [weak self] err in
            guard let self else { return }
            if let err {
                self.saveIssue = err
                TWLog.add("backup", err)
            }
        }
    }

    func load() {
        measuredHR = d.integer(forKey: Key.hr)
        measuredHRV = d.integer(forKey: Key.hrv)
        hrSource = d.string(forKey: Key.hrSrc) ?? ""
        pedometerSteps = d.integer(forKey: Key.steps)
        pedometerDistance = d.double(forKey: Key.dist)
        mood = d.string(forKey: Key.mood) ?? "ok"
        if d.object(forKey: Key.dt) != nil { dietTarget = d.double(forKey: Key.dt) }
        if d.object(forKey: Key.pgoal) != nil { proteinGoal = d.double(forKey: Key.pgoal) }
        if d.object(forKey: Key.weekly) != nil { weeklyGoal = max(1, d.integer(forKey: Key.weekly)) }
        if d.object(forKey: "tw.age.v3") != nil { age = d.integer(forKey: "tw.age.v3") }
        if d.object(forKey: "tw.sexMale.v3") != nil { sexMale = d.bool(forKey: "tw.sexMale.v3") }
        if d.object(forKey: "tw.activity.v3") != nil { activityLevel = d.integer(forKey: "tw.activity.v3") }
        if d.object(forKey: "tw.goalMode.v3") != nil { goalMode = d.integer(forKey: "tw.goalMode.v3") }
        if d.object(forKey: Key.wt) != nil { waterTarget = max(1, d.integer(forKey: Key.wt)) }
        dietKcal = d.double(forKey: Key.kcal)
        protein = d.double(forKey: Key.protein)
        carb = d.double(forKey: Key.carb)
        fat = d.double(forKey: Key.fat)
        veg = d.double(forKey: Key.veg)
        exerciseMin = d.double(forKey: Key.exercise)
        moveKcal = d.double(forKey: Key.moveK)
        standHours = d.double(forKey: Key.stand)

        let ts = d.double(forKey: Key.hrAt)
        if ts > 0 {
            measuredAt = Date(timeIntervalSince1970: ts)
        }
        hr = measuredHR
        hrv = measuredHRV

        if let v = d.data(forKey: Key.mhist),
           let decoded = try? JSONDecoder().decode([String: [MealEntry]].self, from: v) {
            mealHistory = decoded
        }
        if let v = d.data(forKey: "tw.barcodes.v3"),
           let decoded = try? JSONDecoder().decode([String: BarcodeNote].self, from: v) {
            barcodeNotes = decoded
        }
        if let v = d.data(forKey: Key.logs),
           let decoded = try? JSONDecoder().decode([DayLog].self, from: v) {
            logs = decoded
        }
        favoriteMoves = d.stringArray(forKey: Key.fav) ?? []

        bodyWeight = d.double(forKey: Key.weight)
        heightCM = d.double(forKey: Key.height)
        waistCM = d.double(forKey: Key.waist)
        let savedWaterDay = d.string(forKey: Key.waterDay) ?? ""
        let isToday = savedWaterDay == DateFormatter.twDay.string(from: Date())
        waterCups = isToday ? d.integer(forKey: Key.water) : 0
        waterExtraML = isToday ? d.integer(forKey: Key.wextra) : 0
        let savedCup = d.integer(forKey: Key.cupsize)
        cupSize = savedCup > 0 ? savedCup : 250

        if let v = d.data(forKey: Key.wlogs),
           let decoded = try? JSONDecoder().decode([WeightLog].self, from: v) {
            weightLogs = decoded
        }
        if let v = d.data(forKey: Key.cfoods),
           let decoded = try? JSONDecoder().decode([CustomFood].self, from: v) {
            customFoods = decoded
        }
        weightGoal = d.double(forKey: Key.wgoal)
        chestCM = d.double(forKey: Key.chest)
        armCM = d.double(forKey: Key.arm)
        thighCM = d.double(forKey: Key.thigh)
        hipCM = d.double(forKey: Key.hip)
        if let v = d.data(forKey: Key.glogs),
           let decoded = try? JSONDecoder().decode([GirthLog].self, from: v) {
            girthLogs = decoded
        }
        planPick = d.integer(forKey: Key.planpick)
        dayPick = d.integer(forKey: Key.daypick)
        if let v = d.data(forKey: Key.prs),
           let decoded = try? JSONDecoder().decode([String: String].self, from: v) {
            prs = decoded
        }
        if let v = d.data(forKey: Key.prBest),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: v) {
            prBest = decoded
        }
        if let arr = d.array(forKey: Key.gear) as? [String], !arr.isEmpty {
            ownedGear = Set(arr)
        }
        lockEnabled = d.bool(forKey: Key.lock)
        if let v = d.data(forKey: Key.sleeps),
           let decoded = try? JSONDecoder().decode([SleepLog].self, from: v) {
            sleepLogs = decoded
        }
        watchSleepMin = d.integer(forKey: Key.wsleep)
        watchDeepMin = d.integer(forKey: Key.wdeep)
        manualSleepMin = d.integer(forKey: Key.msleep)
        manualRestingHR = d.integer(forKey: Key.mhr)
        manualHRV = d.integer(forKey: Key.mhrv)
        watchSyncCount = d.integer(forKey: Key.wcount)
        let syncTs = d.double(forKey: Key.wsync)
        watchSyncAt = syncTs > 0 ? Date(timeIntervalSince1970: syncTs) : nil
        watchSpO2 = d.integer(forKey: Key.spo2)
        let spo2Ts = d.double(forKey: Key.spo2At)
        watchSpO2At = spo2Ts > 0 ? Date(timeIntervalSince1970: spo2Ts) : nil
        if let v = d.data(forKey: Key.cplans),
           let decoded = try? JSONDecoder().decode([CustomPlan].self, from: v) {
            customPlans = decoded
        }
        restOverride = d.integer(forKey: Key.restOv)
        lastDayKey = d.string(forKey: Key.dayKey) ?? ""
        mindfulMin = d.integer(forKey: Key.mindmin)
        let mindTs = d.double(forKey: Key.mindat)
        mindfulAt = mindTs > 0 ? Date(timeIntervalSince1970: mindTs) : nil
        if let v = d.data(forKey: "tw.progressPhotos.v1"),
           let decoded = try? JSONDecoder().decode([ProgressPhoto].self, from: v) {
            progressPhotos = decoded
        }
    }

    /// 大数组的后台加载：先试分文件，没有再读 UserDefaults 老位置，读到就顺手迁过去。
    /// 以前一次 persist 要把几百条饮食全编码一遍，现在只写变化的那一块。
    private func loadHeavy() {
        var newMeals = TWFiles.read("meals.json", as: [MealEntry].self)
        var newPhotos = TWFiles.read("mealPhotos.json", as: [String: [String]].self)
        var newSessions = TWFiles.read("sessions.json", as: [SessionLog].self)
        var migrated = false

        if newMeals == nil,
           let v = d.data(forKey: Key.meals),
           let decoded = try? JSONDecoder().decode([MealEntry].self, from: v) {
            newMeals = decoded
            migrated = true
        }
        if newPhotos == nil,
           let v = d.data(forKey: "tw.photos.v3"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: v) {
            newPhotos = decoded
            migrated = true
        }
        if newSessions == nil,
           let v = d.data(forKey: Key.sess),
           let decoded = try? JSONDecoder().decode([SessionLog].self, from: v) {
            newSessions = decoded
            migrated = true
        }

        DispatchQueue.main.async {
            if let v = newMeals { self.meals = v }
            if let v = newPhotos { self.mealPhotos = v }
            if let v = newSessions { self.sessions = v }
            self.heavyLoaded = true
            TWLog.add("store", "大数组就绪 · 饮食 \(newMeals?.count ?? 0) 条 · 训练 \(newSessions?.count ?? 0) 场"
                      + (migrated ? " · 已迁到分文件" : ""))
            if migrated {
                TWFiles.writeAsync(self.meals, name: "meals.json")
                TWFiles.writeAsync(self.mealPhotos, name: "mealPhotos.json")
                TWFiles.writeAsync(self.sessions, name: "sessions.json")
            }
        }
    }
}

extension DateFormatter {
    static let twDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let twShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()
}

let demoMoves: [MoveItem] = [
    // 胸
    MoveItem(name: "杠铃平板卧推", group: "胸", equipment: "杠铃", cue: "肩胛收紧，杠落胸线", pr: "65kg × 8"),
    MoveItem(name: "哑铃上斜卧推", group: "胸", equipment: "哑铃", cue: "凳角 30°，别超过 45°", pr: "22kg × 10"),
    MoveItem(name: "哑铃平板飞鸟", group: "胸", equipment: "哑铃", cue: "肘微屈，画弧不推举", pr: "14kg × 12"),
    MoveItem(name: "俯卧撑", group: "胸", equipment: "自重", cue: "身体一条直线，别塌腰", pr: "20 次"),
    MoveItem(name: "双杠臂屈伸", group: "胸", equipment: "自重", cue: "身体前倾才练到下胸", pr: "12 次"),
    MoveItem(name: "绳索夹胸", group: "胸", equipment: "器械", cue: "顶峰收缩停 1 秒", pr: "15kg × 15"),

    // 背
    MoveItem(name: "高位下拉", group: "背", equipment: "器械", cue: "先沉肩再拉肘", pr: "55kg × 12"),
    MoveItem(name: "引体向上", group: "背", equipment: "自重", cue: "下巴过杠，别摆动", pr: "8 次"),
    MoveItem(name: "杠铃划船", group: "背", equipment: "杠铃", cue: "躯干 45°，拉向小腹", pr: "60kg × 10"),
    MoveItem(name: "单臂哑铃划船", group: "背", equipment: "哑铃", cue: "肘贴身体走，别外展", pr: "26kg × 10"),
    MoveItem(name: "罗马尼亚硬拉", group: "背", equipment: "杠铃", cue: "髋往后推，不是弯腰", pr: "80kg × 8"),
    MoveItem(name: "坐姿绳索划船", group: "背", equipment: "器械", cue: "肩胛后缩再拉", pr: "50kg × 12"),

    // 腿
    MoveItem(name: "杠铃深蹲", group: "腿", equipment: "杠铃", cue: "膝盖对脚尖，蹲到大腿平行", pr: "90kg × 6"),
    MoveItem(name: "高脚杯深蹲", group: "腿", equipment: "哑铃", cue: "哑铃抱在胸前", pr: "20kg × 12"),
    MoveItem(name: "保加利亚分腿蹲", group: "腿", equipment: "哑铃", cue: "前脚掌发力，别借后脚", pr: "16kg × 10"),
    MoveItem(name: "腿举", group: "腿", equipment: "器械", cue: "别锁死膝盖", pr: "140kg × 12"),
    MoveItem(name: "罗马尼亚单腿硬拉", group: "腿", equipment: "哑铃", cue: "支撑腿微屈，髋主导", pr: "18kg × 10"),
    MoveItem(name: "腿弯举", group: "腿", equipment: "器械", cue: "收缩到底停 1 秒", pr: "40kg × 12"),
    MoveItem(name: "站姿提踵", group: "腿", equipment: "自重", cue: "登顶停 1 秒再放", pr: "25 次"),
    MoveItem(name: "臀桥", group: "腿", equipment: "自重", cue: "顶端夹臀 2 秒", pr: "20 次"),

    // 肩
    MoveItem(name: "哑铃肩上推举", group: "肩", equipment: "哑铃", cue: "核心收紧别塌腰", pr: "16kg × 10"),
    MoveItem(name: "侧平举", group: "肩", equipment: "哑铃", cue: "小指略高，别耸肩", pr: "8kg × 15"),
    MoveItem(name: "俯身反向飞鸟", group: "肩", equipment: "哑铃", cue: "练后束，肘微屈", pr: "6kg × 15"),
    MoveItem(name: "面拉", group: "肩", equipment: "器械", cue: "拉向额头，肘高于手", pr: "20kg × 15"),
    MoveItem(name: "阿诺德推举", group: "肩", equipment: "哑铃", cue: "旋转到位再推", pr: "14kg × 10"),
    MoveItem(name: "杠铃耸肩", group: "肩", equipment: "杠铃", cue: "只做上下，不转肩", pr: "70kg × 12"),

    // 手臂
    MoveItem(name: "哑铃二头弯举", group: "手臂", equipment: "哑铃", cue: "肘别往前甩", pr: "14kg × 12"),
    MoveItem(name: "杠铃弯举", group: "手臂", equipment: "杠铃", cue: "下放 2 秒，别借力", pr: "30kg × 10"),
    MoveItem(name: "锤式弯举", group: "手臂", equipment: "哑铃", cue: "拇指朝上，练肱桡肌", pr: "12kg × 12"),
    MoveItem(name: "窄距俯卧撑", group: "手臂", equipment: "自重", cue: "双手与肩同宽或更窄", pr: "15 次"),
    MoveItem(name: "绳索下压", group: "手臂", equipment: "器械", cue: "肘固定在体侧", pr: "30kg × 15"),
    MoveItem(name: "过顶臂屈伸", group: "手臂", equipment: "哑铃", cue: "肘尖朝前别外张", pr: "16kg × 12"),

    // 核心
    MoveItem(name: "平板支撑", group: "核心", equipment: "自重", cue: "夹臀，肋骨收住", pr: "90 秒"),
    MoveItem(name: "侧平板", group: "核心", equipment: "自重", cue: "髋别下沉", pr: "45 秒/侧"),
    MoveItem(name: "卷腹", group: "核心", equipment: "自重", cue: "下背贴地，别拉扯脖子", pr: "20 次"),
    MoveItem(name: "悬垂举腿", group: "核心", equipment: "自重", cue: "骨盆后倾再抬腿", pr: "10 次"),
    MoveItem(name: "死虫", group: "核心", equipment: "自重", cue: "腰始终贴地", pr: "12 次/侧"),
    MoveItem(name: "健腹轮", group: "核心", equipment: "器械", cue: "能控住才往外滚", pr: "8 次")
]

let moveGroups: [String] = ["全部", "胸", "背", "腿", "肩", "手臂", "核心"]

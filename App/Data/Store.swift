import SwiftUI
import Combine

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
struct SetRecord: Codable, Hashable {
    var move: String
    var weight: Double
    var reps: Int
    var date: String   // yyyy-MM-dd
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
    // 环形
    @Published var moveKcal: Double = 0
    @Published var moveTarget: Double = 520
    @Published var exerciseMin: Double = 0
    @Published var exerciseTarget: Double = 30
    @Published var standHours: Double = 0
    @Published var standTarget: Double = 10
    @Published var hrv: Int = 0

    // 身体
    @Published var steps: Int = 0
    @Published var hr: Int = 0
    @Published var restingHR: Int = 0
    @Published var pedometerSteps: Int = 0
    @Published var pedometerDistance: Double = 0
    @Published var measuredHR: Int = 0
    @Published var measuredHRV: Int = 0
    @Published var measuredAt: Date?
    @Published var hrSource: String = ""
    @Published var watchSteps: Int = 0
    /// 手表同步进来的睡眠数据（Quick 快捷指令通道）
    @Published var watchSleepMin: Int = 0
    @Published var watchDeepMin: Int = 0
    @Published var watchSyncAt: Date?
    @Published var watchSyncCount: Int = 0
    @Published var mindfulMin: Int = 0
    @Published var mindfulAt: Date?

    // 饮食
    @Published var dietKcal: Double = 0
    @Published var dietTarget: Double = 2200
    @Published var proteinGoal: Double = 120
    @Published var protein: Double = 0
    @Published var carb: Double = 0
    @Published var fat: Double = 0
    @Published var veg: Double = 0
    @Published var meals: [MealEntry] = []
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

    private let d = UserDefaults.standard
    private var saveWork: DispatchWorkItem?

    private enum Key {
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
        static let wt = "tw.wt.v2"
        static let mhist = "tw.mhist.v2"
        static let wsync = "tw.wsync.v2"
        static let wcount = "tw.wcount.v2"
        static let mindmin = "tw.mindmin.v2"
        static let mindat = "tw.mindat.v2"
    }

    init() {
        load()
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

    /// 把导出的 JSON 落成一个真实的 .json 文件，交给系统分享面板存到「文件」或发给自己
    func exportJSONFile() -> URL? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let name = "天才威-数据备份-\(f.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try exportJSON().data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 导出全部本机数据为 JSON 文本
    func exportJSON() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var root: [String: Any] = [:]
        root["exportedAt"] = f.string(from: Date())
        root["app"] = "天才威 3.0"
        root["steps"] = pedometerSteps
        root["distanceM"] = pedometerDistance
        root["hr"] = measuredHR
        root["hrv"] = measuredHRV
        root["hrSource"] = hrSource
        root["mood"] = mood
        root["dietTarget"] = dietTarget
        root["proteinGoal"] = proteinGoal
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
        var errorDescription: String? { "这不是天才威的备份文件，或者文件已经损坏" }
    }

    /// 把导出的 JSON 回灌进来。换手机、重装之后靠这个捡回历史。
    @discardableResult
    func importJSON(_ data: Data) throws -> Int {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (root["app"] as? String)?.contains("天才威") == true else {
            throw ImportError()
        }

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
        sessionStart = Date()
        sessionSets = 0
        sessionMoves = moves
        sessionTonnage = 0
        sessionRecords = []
        mood = "train"
        persistSoon()
    }

    func addSet(weight: Double = 0, reps: Int = 0, move: String = "") {
        sessionSets += 1
        if weight > 0, reps > 0 {
            sessionTonnage += weight * Double(reps)
            // 动作名拿得到才记明细，拿不到就只算总量
            if !move.isEmpty {
                sessionRecords.append(SetRecord(move: move,
                                                weight: weight,
                                                reps: reps,
                                                date: DateFormatter.twDay.string(from: Date())))
            }
        }
        exerciseMin += 2.5
        moveKcal += 22
        standHours = min(standHours + 0.15, standTarget)
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

    /// 渐进超负荷：上次把目标次数做满就加 2.5kg；没做满就维持上次重量。
    func suggestWeight(move: String, targetReps: Int) -> Double? {
        guard let last = lastRecord(move: move), last.weight > 0 else { return nil }
        return last.reps >= targetReps ? min(500, last.weight + 2.5) : last.weight
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
        if let v = try? JSONEncoder().encode(meals) {
            d.set(v, forKey: Key.meals)
        }
        if let v = try? JSONEncoder().encode(mealPhotos) {
            d.set(v, forKey: "tw.photos.v3")
        }
        if let v = try? JSONEncoder().encode(logs) {
            d.set(v, forKey: Key.logs)
        }
        d.set(favoriteMoves, forKey: Key.fav)

        d.set(dietTarget, forKey: Key.dt)
        d.set(proteinGoal, forKey: Key.pgoal)
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
        if let v = try? JSONEncoder().encode(sleepLogs) {
            d.set(v, forKey: Key.sleeps)
        }
        d.set(watchSleepMin, forKey: Key.wsleep)
        d.set(watchDeepMin, forKey: Key.wdeep)
        d.set(watchSyncCount, forKey: Key.wcount)
        if let t = watchSyncAt { d.set(t.timeIntervalSince1970, forKey: Key.wsync) }
        d.set(mindfulMin, forKey: Key.mindmin)
        if let t = mindfulAt { d.set(t.timeIntervalSince1970, forKey: Key.mindat) }
        if let v = try? JSONEncoder().encode(sessions) {
            d.set(v, forKey: Key.sess)
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

        if let v = d.data(forKey: Key.meals),
           let decoded = try? JSONDecoder().decode([MealEntry].self, from: v) {
            meals = decoded
        }
        if let v = d.data(forKey: "tw.photos.v3"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: v) {
            mealPhotos = decoded
        }
        if let v = d.data(forKey: Key.mhist),
           let decoded = try? JSONDecoder().decode([String: [MealEntry]].self, from: v) {
            mealHistory = decoded
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
        if let v = d.data(forKey: Key.sleeps),
           let decoded = try? JSONDecoder().decode([SleepLog].self, from: v) {
            sleepLogs = decoded
        }
        watchSleepMin = d.integer(forKey: Key.wsleep)
        watchDeepMin = d.integer(forKey: Key.wdeep)
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
        if let v = d.data(forKey: Key.sess),
           let decoded = try? JSONDecoder().decode([SessionLog].self, from: v) {
            sessions = decoded
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

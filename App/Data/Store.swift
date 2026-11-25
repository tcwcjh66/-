import SwiftUI
import Combine

enum TWTab: String, CaseIterable, Identifiable {
    case today, bio, lib, flow, diet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "今天"
        case .bio:   return "身体"
        case .lib:   return "动作库"
        case .flow:  return "训练"
        case .diet:  return "饮食"
        }
    }

    var symbol: String {
        switch self {
        case .today: return "circle.dotted"
        case .bio:   return "heart"
        case .lib:   return "figure.strengthtraining.traditional"
        case .flow:  return "timer"
        case .diet:  return "fork.knife"
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

struct SessionLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: String        // yyyy-MM-dd
    var plan: String
    var day: String
    var moves: Int
    var sets: Int
    var minutes: Int
    var moveNames: [String]? = nil
}

struct GirthLog: Codable, Identifiable, Hashable {
    var id: String          // yyyy-MM-dd
    var waist: Double
    var chest: Double
    var arm: Double
    var thigh: Double
    var hip: Double
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

    // 饮食
    @Published var dietKcal: Double = 0
    @Published var dietTarget: Double = 2200
    @Published var protein: Double = 0
    @Published var carb: Double = 0
    @Published var fat: Double = 0
    @Published var veg: Double = 0
    @Published var meals: [MealEntry] = []

    // 心情
    @Published var mood: String = "ok"

    // 训练会话
    @Published var sessionStart: Date?
    @Published var sessionSets: Int = 0
    @Published var sessionMoves: [String] = []
    @Published var logs: [DayLog] = []

    // 收藏
    @Published var favoriteMoves: [String] = []

    // 身体数据
    @Published var bodyWeight: Double = 0
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

    // 饮水
    @Published var waterCups: Int = 0
    @Published var waterTarget: Int = 8

    // 自定义食物
    @Published var customFoods: [CustomFood] = []

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

    var stepsForDisplay: Int { pedometerSteps > 0 ? pedometerSteps : steps }
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

    // MARK: - 围度历史

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

    func resetToday() {
        meals.removeAll()
        dietKcal = 0
        protein = 0
        carb = 0
        fat = 0
        veg = 0
        persistSoon()
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
        mood = "train"
        persistSoon()
    }

    func addSet() {
        sessionSets += 1
        exerciseMin += 2.5
        moveKcal += 22
        standHours = min(standHours + 0.15, standTarget)
        persistSoon()
    }

    func endSession(plan: String = "", day: String = "", moves: Int = 0, moveNames: [String] = []) {
        let start = sessionStart ?? Date()
        let mins = max(1, Int(Date().timeIntervalSince(start) / 60))
        if sessionSets > 0 {
            let entry = SessionLog(
                date: DateFormatter.twDay.string(from: Date()),
                plan: plan,
                day: day,
                moves: moves,
                sets: sessionSets,
                minutes: mins,
                moveNames: moveNames
            )
            sessions.insert(entry, at: 0)
            if sessions.count > 90 {
                sessions.removeLast(sessions.count - 90)
            }
        }
        sessionStart = nil
        mood = "win"
        upsertToday()
        persistSoon()
    }

    // MARK: - 每日

    func upsertToday() {
        let key = DateFormatter.twDay.string(from: Date())
        let entry = DayLog(
            id: key,
            steps: pedometerSteps,
            hr: measuredHR,
            hrv: measuredHRV,
            moveKcal: moveKcal,
            exerciseMin: exerciseMin,
            kcal: dietKcal
        )
        if let i = logs.firstIndex(where: { $0.id == key }) {
            logs[i] = entry
        } else {
            logs.append(entry)
        }
        if logs.count > 30 {
            logs.removeFirst(logs.count - 30)
        }
        persistSoon()
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
        if let v = try? JSONEncoder().encode(logs) {
            d.set(v, forKey: Key.logs)
        }
        d.set(favoriteMoves, forKey: Key.fav)

        d.set(bodyWeight, forKey: Key.weight)
        d.set(heightCM, forKey: Key.height)
        d.set(waistCM, forKey: Key.waist)
        d.set(waterCups, forKey: Key.water)
        d.set(DateFormatter.twDay.string(from: Date()), forKey: Key.waterDay)

        if let v = try? JSONEncoder().encode(weightLogs) {
            d.set(v, forKey: Key.wlogs)
        }
        if let v = try? JSONEncoder().encode(customFoods) {
            d.set(v, forKey: Key.cfoods)
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
        if let v = d.data(forKey: Key.logs),
           let decoded = try? JSONDecoder().decode([DayLog].self, from: v) {
            logs = decoded
        }
        favoriteMoves = d.stringArray(forKey: Key.fav) ?? []

        bodyWeight = d.double(forKey: Key.weight)
        heightCM = d.double(forKey: Key.height)
        waistCM = d.double(forKey: Key.waist)
        let savedWaterDay = d.string(forKey: Key.waterDay) ?? ""
        waterCups = savedWaterDay == DateFormatter.twDay.string(from: Date())
            ? d.integer(forKey: Key.water) : 0

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

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

struct MealEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carb: Double
    var fat: Double
    var veg: Double
}

struct MoveItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var group: String
    var equipment: String
    var cue: String
    var pr: String
}

final class TWStore: ObservableObject {
    // 环形
    @Published var moveKcal: Double = 520
    @Published var moveTarget: Double = 520
    @Published var exerciseMin: Double = 30
    @Published var exerciseTarget: Double = 30
    @Published var standHours: Double = 10
    @Published var standTarget: Double = 10
    @Published var hrv: Int = 46

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

    // 饮食
    @Published var dietKcal: Double = 250
    @Published var dietTarget: Double = 2200
    @Published var protein: Double = 12
    @Published var carb: Double = 30
    @Published var fat: Double = 8
    @Published var veg: Double = 0
    @Published var meals: [MealEntry] = []

    // 心情
    @Published var mood: String = "ok"

    var ringMove: Double { moveTarget > 0 ? moveKcal / moveTarget : 0 }
    var ringExercise: Double { exerciseTarget > 0 ? exerciseMin / exerciseTarget : 0 }
    var ringStand: Double { standTarget > 0 ? standHours / standTarget : 0 }
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

    func addMeal(_ m: MealEntry) {
        meals.append(m)
        dietKcal += m.kcal
        protein += m.protein
        carb += m.carb
        fat += m.fat
        veg += m.veg
    }

    func resetToday() {
        meals.removeAll()
        dietKcal = 0
        protein = 0
        carb = 0
        fat = 0
        veg = 0
    }
}

let demoMoves: [MoveItem] = [
    MoveItem(name: "杠铃平板卧推", group: "胸", equipment: "杠铃", cue: "肩胛收紧，杠落胸线", pr: "65kg × 8"),
    MoveItem(name: "哑铃上斜卧推", group: "胸", equipment: "哑铃", cue: "凳角 30°，别超过 45°", pr: "22kg × 10"),
    MoveItem(name: "俯卧撑", group: "胸", equipment: "自重", cue: "身体一条直线，别塌腰", pr: "20 次"),
    MoveItem(name: "高位下拉", group: "背", equipment: "器械", cue: "先沉肩再拉肘", pr: "55kg × 12"),
    MoveItem(name: "罗马尼亚硬拉", group: "背", equipment: "杠铃", cue: "髋往后推，不是弯腰", pr: "80kg × 8"),
    MoveItem(name: "杠铃深蹲", group: "腿", equipment: "杠铃", cue: "膝盖对脚尖，蹲到大腿平行", pr: "90kg × 6"),
    MoveItem(name: "高脚杯深蹲", group: "腿", equipment: "哑铃", cue: "哑铃抱在胸前", pr: "20kg × 12"),
    MoveItem(name: "站姿提踵", group: "腿", equipment: "自重", cue: "登顶停 1 秒再放", pr: "25 次"),
    MoveItem(name: "哑铃肩上推举", group: "肩", equipment: "哑铃", cue: "核心收紧别塌腰", pr: "16kg × 10"),
    MoveItem(name: "哑铃二头弯举", group: "手臂", equipment: "哑铃", cue: "肘别往前甩", pr: "14kg × 12"),
    MoveItem(name: "窄距俯卧撑", group: "手臂", equipment: "自重", cue: "双手与肩同宽或更窄", pr: "15 次"),
    MoveItem(name: "平板支撑", group: "核心", equipment: "自重", cue: "夹臀，肋骨收住", pr: "90 秒")
]

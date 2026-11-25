import Foundation
import Combine

/// 会高频跳动的数值，单独一个对象。
///
/// 原来它们全挂在 TWStore 上：计步每几秒写一次、训练每组三连跳（组数/时长/站立）、
/// 测心率每秒一次。TWStore 是单个 ObservableObject，任何一次跳动都会让五个页面
/// 一起重算 body——这是真机滚动发涩的主因。
///
/// 拆出来以后，只有真正展示这些数字的视图订阅它，其余页面完全不参与。
final class TWLive: ObservableObject {
    // 计步
    @Published var steps: Int = 0
    @Published var pedometerSteps: Int = 0
    @Published var pedometerDistance: Double = 0

    // 心率 / HRV
    @Published var hr: Int = 0
    @Published var hrv: Int = 0
    @Published var measuredHR: Int = 0
    @Published var measuredHRV: Int = 0
    @Published var measuredAt: Date?
    @Published var hrSource: String = ""

    // 三环
    @Published var moveKcal: Double = 0
    @Published var exerciseMin: Double = 0
    @Published var standHours: Double = 0
}

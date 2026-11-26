import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// 组间休息的灵动岛数据。主 App 起活动，Widget 扩展负责渲染。
/// 这份文件同时被主 App 和 Widget 两个 target 编译，所以只放纯数据，不引用 App 里的主题。
struct TWRestAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 休息结束的绝对时间，锁屏用 Text(..., style: .timer) 自己走秒
        var endAt: Date
        /// 本轮总秒数，用来画进度
        var total: Int
    }

    /// 刚做完的动作
    var move: String
    /// 下一个要做的
    var next: String
}
#endif

import Foundation

/// 练后拉伸：按今天练到的肌群挑几条，每条 30 秒，练完顺手做。
struct StretchStep: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let group: String
    let tip: String
    let seconds: Int
}

enum Stretch {
    static let all: [StretchStep] = [
        StretchStep(name: "站姿深呼吸", group: "全身",
                    tip: "鼻子吸气 4 秒、嘴呼气 6 秒，把心率降下来", seconds: 30),
        StretchStep(name: "门框胸肌拉伸", group: "胸",
                    tip: "前臂贴门框，肘略高于肩，身体前倾，别耸肩", seconds: 30),
        StretchStep(name: "猫牛式", group: "背",
                    tip: "四点跪姿，吸气塌腰、呼气拱背，跟着呼吸走", seconds: 30),
        StretchStep(name: "背阔肌拉伸", group: "背",
                    tip: "双手扶住固定物，屁股后坐，让背阔拉开", seconds: 30),
        StretchStep(name: "股四头拉伸", group: "腿",
                    tip: "单脚站稳，另一只脚后勾，膝盖朝下，扶墙保持", seconds: 30),
        StretchStep(name: "坐姿腘绳拉伸", group: "腿",
                    tip: "一条腿伸直，背别拱，从髋部往前折", seconds: 30),
        StretchStep(name: "靠墙小腿拉伸", group: "腿",
                    tip: "前脚掌踩墙、脚跟着地，腿伸直，身体慢慢靠近", seconds: 30),
        StretchStep(name: "过头三头拉伸", group: "肩",
                    tip: "手肘举过头，另一只手轻轻往后压，别拉到疼", seconds: 30),
        StretchStep(name: "肩后束拉伸", group: "肩",
                    tip: "手臂横过胸前，另一只手扣住上臂往回收", seconds: 30),
        StretchStep(name: "墙边二头拉伸", group: "手臂",
                    tip: "掌心贴墙、手臂伸直，身体往外转，胸口打开", seconds: 30),
        StretchStep(name: "眼镜蛇式", group: "核心",
                    tip: "俯卧，手掌撑地慢慢抬起胸口，髋别离地", seconds: 30),
        StretchStep(name: "侧腰拉伸", group: "核心",
                    tip: "双脚交叉站，一手过头向侧倒，肋骨跟着拉开", seconds: 30)
    ]

    /// 按今天练到的肌群挑，最多 5 条，最后一定带一条全身呼吸
    static func steps(groups: Set<String>, limit: Int = 5) -> [StretchStep] {
        var out = all.filter { groups.contains($0.group) }
        if out.count > limit { out = Array(out.prefix(limit)) }
        if let breath = all.first(where: { $0.group == "全身" }) {
            out.append(breath)
        }
        return out
    }
}

import Foundation

/// 热身清单是按「今天练什么」推出来的，不是每天一样的废话。
struct WarmupStep: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let tag: String
}

enum Warmup {
    static func steps(moveNames: [String]) -> [WarmupStep] {
        var out: [WarmupStep] = [
            WarmupStep(name: "5 分钟有氧",
                       detail: "快走、慢跑或跳绳，心率到微喘但还能说话",
                       tag: "全身")
        ]

        let groups = Set(moveNames.compactMap { n in
            allMoves.first { $0.name == n }?.group
        })

        if groups.contains("胸") {
            out.append(WarmupStep(name: "肩袖激活",
                                  detail: "弹力带外旋 15 次 / 侧，肩胛后缩 12 次",
                                  tag: "胸"))
        }
        if groups.contains("背") {
            out.append(WarmupStep(name: "肩胛下沉",
                                  detail: "弹力带下拉 15 次，悬垂 20 秒",
                                  tag: "背"))
        }
        if groups.contains("腿") {
            out.append(WarmupStep(name: "髋膝踝预热",
                                  detail: "空蹲 20 次，髋铰链 15 次，踝背屈 10 次 / 侧",
                                  tag: "腿"))
        }
        if groups.contains("肩") {
            out.append(WarmupStep(name: "绕肩",
                                  detail: "弹力带绕肩 15 次 / 方向，别耸肩",
                                  tag: "肩"))
        }
        if groups.contains("手臂") {
            out.append(WarmupStep(name: "手腕肘热身",
                                  detail: "手腕绕环 15 次，轻哑铃弯举 20 次",
                                  tag: "臂"))
        }
        if groups.contains("核心") {
            out.append(WarmupStep(name: "核心唤醒",
                                  detail: "死虫 10 次 / 侧，臀桥 15 次",
                                  tag: "核心"))
        }

        if let first = moveNames.first {
            out.append(WarmupStep(name: "首个动作递增组",
                                  detail: "\(first)：空杆 1 组 × 10，50% 重量 1 组 × 6，再上正式组",
                                  tag: "主项"))
        }
        return out
    }
}

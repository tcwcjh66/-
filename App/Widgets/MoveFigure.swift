import SwiftUI

/// 动作姿态示意：按动作模式挑一个系统人形符号，配一个大号渐变底。
/// 是示意不是解剖图——真要看细节还是动作要点那段文字。
struct MoveFigure: View {
    let name: String
    var size: CGFloat = 42
    var active: Bool = false

    private var symbol: String {
        let n = name
        if n.contains("深蹲") || n.contains("腿举") || n.contains("分腿蹲") || n.contains("提踵") || n.contains("臀桥") {
            return "figure.strengthtraining.functional"
        }
        if n.contains("卷腹") || n.contains("平板") || n.contains("核心") || n.contains("举腿") || n.contains("俄罗斯") {
            return "figure.core.training"
        }
        if n.contains("跑") || n.contains("跳绳") || n.contains("单脚跳") {
            return "figure.run"
        }
        if n.contains("拉伸") || n.contains("瑜伽") || n.contains("放松") {
            return "figure.flexibility"
        }
        if n.contains("划船") || n.contains("引体") || n.contains("下拉") || n.contains("硬拉") {
            return "figure.rowing"
        }
        if n.contains("推举") || n.contains("平举") || n.contains("飞鸟") || n.contains("弯举") || n.contains("夹胸") {
            return "dumbbell.fill"
        }
        return "figure.strengthtraining.traditional"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(
                    colors: active
                        ? [TWColor.purple.opacity(0.85), TWColor.blue.opacity(0.75)]
                        : [TWColor.purple.opacity(0.16), TWColor.violet.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Image(systemName: symbol)
                .font(.system(size: size * 0.52, weight: .semibold))
                .foregroundStyle(active ? .white : TWColor.purple)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

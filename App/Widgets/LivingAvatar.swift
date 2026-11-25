import SwiftUI

/// 心情立绘的"活图"实现。
///
/// 不做序列帧（生成帧之间构图对不齐，切换会跳），改为实时计算：
/// 呼吸相位驱动纵向缩放与胸腔体积、3D 透视微摆、底部下沉、光晕脉动、悬浮微粒。
/// TimelineView(.animation) 跟随屏幕刷新率（ProMotion 120Hz）逐帧求值，
/// 相位用正弦函数连续变化，所以不存在补间断层，视觉上是真正的「活着」而不是播动画。
struct LivingAvatar: View {
    let asset: String
    let mood: String

    private var cfg: MotionCfg { MotionCfg.of(mood) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            let t = CGFloat(context.date.timeIntervalSinceReferenceDate)
            canvas(t: t)
        }
    }

    private func canvas(t: CGFloat) -> some View {
        let c = cfg
        let twoPi = CGFloat.pi * 2

        // 呼吸相位：0 为呼气末，1 为吸气末
        let breath = sin(t * c.breatheHz * twoPi)
        // 摆动相位：慢于呼吸，制造"重心在挪"的感觉
        let sway = sin(t * c.swayHz * twoPi)
        // 极慢的漂浮
        let drift = sin(t * 0.18 * twoPi)

        return ZStack {
            // 地面光晕，随呼吸明暗起伏
            Circle()
                .fill(
                    RadialGradient(
                        colors: [c.glow.opacity(0.26 + 0.10 * breath), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 172
                    )
                )
                .frame(width: 344, height: 344)
                .scaleEffect(1 + 0.035 * breath)
                .blendMode(.plusLighter)

            // 悬浮微粒
            particles(t: t, tint: c.glow)

            // 落影，吸气时略收
            Ellipse()
                .fill(Color(red: 0.34, green: 0.27, blue: 0.50).opacity(0.14))
                .frame(width: 132 - 7 * breath, height: 17 + 1.5 * breath)
                .blur(radius: 9)
                .offset(y: 140 + c.sink)

            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 286)
                .scaleEffect(
                    x: 1 + 0.010 * breath,
                    y: 1 + 0.020 * breath,
                    anchor: .bottom
                )
                .rotation3DEffect(
                    .degrees(1.4 * sway),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottom,
                    perspective: 0.55
                )
                .rotationEffect(.degrees(0.35 * sway), anchor: .bottom)
                .offset(y: 8 - 2.6 * breath + 1.6 * drift + c.sink)
                .shadow(color: TWColor.cardShadow, radius: 22, x: 0, y: 14)
        }
        .frame(height: 322, alignment: .center)
    }

    private func particles(t: CGFloat, tint: Color) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let seed = CGFloat(i)
                let speed = 0.10 + 0.02 * seed
                let p = (t * speed + seed * 0.31).truncatingRemainder(dividingBy: 1.0)
                let baseX = ParticleSpec.x[i]
                let wobble = sin(t * (0.6 + 0.1 * seed) * CGFloat.pi * 2 + seed) * 6

                Circle()
                    .fill(tint.opacity(0.42 * (1 - p) * (1 - p)))
                    .frame(width: ParticleSpec.size[i])
                    .offset(x: baseX + wobble, y: 118 - p * 236)
                    .blur(radius: 0.5)
            }
        }
    }
}

private enum ParticleSpec {
    static let x: [CGFloat] = [-86, 74, -52, 92, -18, 44]
    static let size: [CGFloat] = [2.6, 2.0, 3.2, 2.2, 1.8, 2.8]
}

struct MotionCfg {
    var breatheHz: CGFloat
    var swayHz: CGFloat
    var glow: Color
    var sink: CGFloat

    static func of(_ mood: String) -> MotionCfg {
        switch mood {
        case "win":
            return MotionCfg(
                breatheHz: 0.40, swayHz: 0.26,
                glow: TWColor.mint, sink: 0
            )
        case "tired":
            return MotionCfg(
                breatheHz: 0.21, swayHz: 0.14,
                glow: TWColor.coral, sink: 11
            )
        case "sleep":
            return MotionCfg(
                breatheHz: 0.16, swayHz: 0.10,
                glow: TWColor.blue, sink: 5
            )
        default:
            return MotionCfg(
                breatheHz: 0.30, swayHz: 0.21,
                glow: TWColor.violet, sink: 0
            )
        }
    }
}

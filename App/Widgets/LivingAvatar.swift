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
    /// 0–23；传 -1 表示不按时段调色
    var hour: Int = -1

    @StateObject private var gyro = Gyro3D()

    private var cfg: MotionCfg { MotionCfg.of(mood) }

    /// 按时段给光晕换色温：清晨偏暖、白天偏紫、黄昏偏橙、夜里偏冷
    private var lightTint: Color {
        guard hour >= 0 else { return cfg.glow }
        switch hour {
        case 5..<9:   return Color(red: 1.00, green: 0.80, blue: 0.58)
        case 9..<17:  return cfg.glow
        case 17..<20: return Color(red: 1.00, green: 0.64, blue: 0.46)
        default:      return Color(red: 0.46, green: 0.44, blue: 0.86)
        }
    }

    var body: some View {
        // 120Hz 驱动：ProMotion 机型跑满，60Hz 机型自动降频，不会跳帧
        TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: false)) { context in
            let t = CGFloat(context.date.timeIntervalSinceReferenceDate)
            canvas(t: t)
        }
        .onAppear { gyro.start() }
        .onDisappear { gyro.stop() }
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

        // 陀螺仪倾角：±1，低通后已经平滑
        let tx = CGFloat(gyro.roll)
        let ty = CGFloat(gyro.pitch)
        // 倾斜角速度 → 拖影强度（60Hz 屏上补出"中间帧"的观感）
        let sp = CGFloat(gyro.rollSpeed)
        let trailOpacity = min(0.26, abs(sp) * 0.42)

        return ZStack {
            // 地面光晕，随呼吸明暗起伏，色温跟随时段
            Circle()
                .fill(
                    RadialGradient(
                        colors: [lightTint.opacity(0.26 + 0.10 * breath), .clear],
                        center: .center,
                        startRadius: 12,
                        endRadius: 172
                    )
                )
                .frame(width: 344, height: 344)
                .scaleEffect(1 + 0.035 * breath)
                .offset(x: tx * 7, y: ty * 4)
                .blendMode(.plusLighter)

            // 远景微粒（视差系数小，跟在立绘后面）
            particles(t: t, tint: lightTint, tx: tx, ty: ty, near: false)

            // 落影，吸气时略收
            Ellipse()
                .fill(Color(red: 0.34, green: 0.27, blue: 0.50).opacity(0.14))
                .frame(width: 132 - 7 * breath, height: 17 + 1.5 * breath)
                .blur(radius: 9)
                .offset(x: -tx * 6, y: 140 + c.sink)

            // 第 1 层：背衬厚度影 —— 与主图反向偏移，倾斜时露出"厚度"
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 286)
                .blur(radius: 15)
                .opacity(0.28 + 0.07 * breath)
                .scaleEffect(0.965)
                .offset(x: -tx * 10, y: 13 + c.sink - ty * 4)

            // 第 2 层：主图 —— 双轴 3D 旋转 + 位移 + 阴影分离
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
                    .degrees(1.4 * sway + tx * 9),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottom,
                    perspective: 0.62
                )
                .rotation3DEffect(
                    .degrees(-ty * 5.5),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.62
                )
                .rotationEffect(.degrees(0.35 * sway), anchor: .bottom)
                .offset(
                    x: tx * 5,
                    y: 8 - 2.6 * breath + 1.6 * drift + c.sink + ty * 3
                )
                .shadow(color: TWColor.cardShadow, radius: 24, x: tx * 13, y: 16)

            // 第 3 层：右侧轮廓高光 —— 倾斜时忽明忽暗，强化体积
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 286)
                .blendMode(.plusLighter)
                .opacity(0.13 + 0.16 * max(0, tx))
                .rotation3DEffect(
                    .degrees(1.4 * sway + tx * 9),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottom,
                    perspective: 0.62
                )
                .rotation3DEffect(
                    .degrees(-ty * 5.5),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.62
                )
                .offset(
                    x: tx * 5,
                    y: 8 - 2.6 * breath + 1.6 * drift + c.sink + ty * 3
                )

            // 第 4 层：运动拖影 —— 倾得越快越明显，60Hz 屏上也能读出"顺"
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(height: 286)
                .blur(radius: 4)
                .opacity(trailOpacity)
                .rotation3DEffect(
                    .degrees(1.4 * sway + tx * 9),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .bottom,
                    perspective: 0.62
                )
                .offset(
                    x: tx * 5 - sp * 26,
                    y: 8 - 2.6 * breath + 1.6 * drift + c.sink + ty * 3
                )

            // 第 5 层：近景微粒 —— 视差最大，压在人物前景，做出"镜头穿过粒子"的纵深
            particles(t: t, tint: lightTint, tx: tx, ty: ty, near: true)
        }
        .frame(height: 322, alignment: .center)
    }

    private func particles(t: CGFloat, tint: Color, tx: CGFloat, ty: CGFloat, near: Bool) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { k in
                let idx = (near ? 4 : 0) + k
                let seed = CGFloat(idx)
                let depth = ParticleSpec.depth[idx]
                let speed = 0.10 + 0.018 * seed
                let p = (t * speed + seed * 0.29).truncatingRemainder(dividingBy: 1.0)
                let baseX = ParticleSpec.x[idx]
                let wobble = sin(t * (0.6 + 0.1 * seed) * CGFloat.pi * 2 + seed) * 6

                Circle()
                    .fill(tint.opacity((near ? 0.30 : 0.42) * (1 - p) * (1 - p)))
                    .frame(width: ParticleSpec.size[idx])
                    .offset(
                        x: baseX + wobble + tx * 30 * depth,
                        y: 118 - p * 236 + ty * 12 * depth
                    )
                    .blur(radius: near ? 1.6 : 0.5)
            }
        }
    }
}

private enum ParticleSpec {
    // 前 4 个是远景（视差弱），后 4 个是近景（视差强，压在前景）
    static let x: [CGFloat] = [-86, 74, -52, 92, -110, 58, -30, 104]
    static let size: [CGFloat] = [2.0, 1.8, 2.4, 2.0, 4.2, 3.6, 4.6, 3.2]
    static let depth: [CGFloat] = [0.28, 0.36, 0.42, 0.34, 0.92, 1.0, 0.86, 0.78]
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
        case "calm":
            // 沉思后：最慢的呼吸，光晕收成薄荷色
            return MotionCfg(
                breatheHz: 0.17, swayHz: 0.11,
                glow: TWColor.mintSoft, sink: 0
            )
        default:
            return MotionCfg(
                breatheHz: 0.30, swayHz: 0.21,
                glow: TWColor.violet, sink: 0
            )
        }
    }
}

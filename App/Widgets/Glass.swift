import SwiftUI

/// 液态玻璃容器。
/// 用系统材质打底（真实模糊 + vibrancy），再叠三层：顶部高光渐变、着色层、0.8pt 亮边。
/// 这样在 iOS 26 之前也能拿到接近原生的透镜质感，且不依赖尚未普及的 glassEffect API。
struct GlassSurface: ViewModifier {
    var radius: CGFloat = 22
    var tint: Color = .white
    var tintAmount: Double = 0
    var shadow: Bool = true

    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    // 浅色背景本来就是淡紫渐变，模糊看不出来，用纯色替掉能省掉整层离屏模糊。
                    // 深色下材质差异明显，保留。
                    if scheme == .dark {
                        shape.fill(.ultraThinMaterial)
                    } else {
                        shape.fill(TWColor.fill)
                    }

                    shape.fill(
                        LinearGradient(
                            colors: [
                                TWColor.glass(0.46),
                                TWColor.glass(0.14),
                                TWColor.glass(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    if tintAmount > 0 {
                        shape.fill(tint.opacity(tintAmount))
                    }

                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                TWColor.glass(0.92),
                                TWColor.glass(0.34),
                                TWColor.glass(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )

                    // 浅色下没有实时模糊了，补一条极淡内边，别让卡片显得发平
                    if scheme == .light {
                        shape.strokeBorder(Color.black.opacity(0.045), lineWidth: 1)
                    }
                }
            }
            .clipShape(shape)
            .compositingGroup()
            .shadow(
                color: shadow ? TWColor.cardShadow : .clear,
                radius: shadow ? 12 : 0,
                x: 0,
                y: shadow ? 5 : 0
            )
    }
}

extension View {
    func twGlass(
        radius: CGFloat = 22,
        tint: Color = .white,
        tintAmount: Double = 0,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassSurface(radius: radius, tint: tint, tintAmount: tintAmount, shadow: shadow))
    }
}

// MARK: - 滚动状态（给逐帧动画用）

private struct TWScrollPauseKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 手指正在拖 / 惯性还没停时为 true，逐帧动画据此暂停，别跟滚动抢帧。
    var twScrollPause: Bool {
        get { self[TWScrollPauseKey.self] }
        set { self[TWScrollPauseKey.self] = newValue }
    }
}

/// 内凹的小胶囊（用于数字/标签）
struct GlassPill: View {
    var text: String
    var tint: Color = TWColor.purple

    var body: some View {
        Text(text)
            .font(.tw(14, .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(tint.opacity(0.22), lineWidth: 0.7)
                    }
            }
    }
}

/// 分段选择器（胶囊组），对应网页 .cf-segs
struct SegGroup<T: Hashable>: View {
    let items: [T]
    let label: (T) -> String
    @Binding var selected: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                let on = item == selected
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selected = item }
                } label: {
                    Text(label(item))
                        .font(.tw(14.5, on ? .bold : .medium))
                        .foregroundStyle(on ? .white : TWColor.ink2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            Capsule(style: .continuous)
                                .fill(on
                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(TWColor.glass(0.55)))
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

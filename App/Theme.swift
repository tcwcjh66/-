import SwiftUI

/// 一个颜色两种外观：浅色用浅色值，深色用深色值，系统切换时自动跟随。
private func dyn(_ l: (Double, Double, Double), _ d: (Double, Double, Double)) -> Color {
    Color(UIColor { t in
        let c = t.userInterfaceStyle == .dark ? d : l
        return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
    })
}

enum TWColor {
    static let ink    = dyn((0.090, 0.086, 0.110), (0.949, 0.945, 0.969))
    static let ink2   = dyn((0.427, 0.416, 0.471), (0.769, 0.753, 0.824))
    static let ink3   = dyn((0.647, 0.631, 0.686), (0.573, 0.557, 0.635))

    static let purple = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)
    static let pink   = Color(red: 0.957, green: 0.447, blue: 0.714)
    static let coral  = Color(red: 0.984, green: 0.443, blue: 0.522)
    static let mint   = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let mintSoft = Color(red: 0.369, green: 0.918, blue: 0.831)
    static let blue   = Color(red: 0.184, green: 0.420, blue: 1.0)
    static let amber  = Color(red: 0.984, green: 0.749, blue: 0.141)

    static let cardShadow = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0, green: 0, blue: 0, alpha: 0.42)
            : UIColor(red: 0.235, green: 0.157, blue: 0.431, alpha: 0.10)
    })

    /// 卡片填充底色（深色下不能再用纯白半透明，否则会糊成一片灰白）
    static let fill = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.075)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 0.55)
    })

    /// 玻璃高光用的白色。深色下压到三成左右，否则整块卡片会发白。
    static func glass(_ v: Double) -> Color {
        Color(UIColor { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(v) * 0.34)
                : UIColor(red: 1, green: 1, blue: 1, alpha: CGFloat(v))
        })
    }

    static let fillSoft = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.05)
            : UIColor(red: 1, green: 1, blue: 1, alpha: 0.42)
    })
}

/// 整块背景：浅色是奶油紫 + 四角光晕；深色是墨蓝底 + 低饱和紫青微光。
struct AuroraBG: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            if scheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.070, green: 0.063, blue: 0.098), location: 0.0),
                        .init(color: Color(red: 0.086, green: 0.071, blue: 0.114), location: 0.5),
                        .init(color: Color(red: 0.055, green: 0.075, blue: 0.086), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color(red: 0.243, green: 0.169, blue: 0.451).opacity(0.85), .clear],
                    center: UnitPoint(x: 0.16, y: 0.10),
                    startRadius: 0, endRadius: 340
                )

                RadialGradient(
                    colors: [Color(red: 0.361, green: 0.145, blue: 0.263).opacity(0.70), .clear],
                    center: UnitPoint(x: 0.86, y: 0.16),
                    startRadius: 0, endRadius: 320
                )

                RadialGradient(
                    colors: [Color(red: 0.078, green: 0.243, blue: 0.216).opacity(0.62), .clear],
                    center: UnitPoint(x: 0.74, y: 0.86),
                    startRadius: 0, endRadius: 340
                )

                RadialGradient(
                    colors: [Color(red: 0.290, green: 0.204, blue: 0.078).opacity(0.52), .clear],
                    center: UnitPoint(x: 0.26, y: 0.80),
                    startRadius: 0, endRadius: 360
                )
            } else {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.957, green: 0.945, blue: 0.984), location: 0.0),
                        .init(color: Color(red: 0.984, green: 0.945, blue: 0.965), location: 0.5),
                        .init(color: Color(red: 0.933, green: 0.976, blue: 0.957), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [Color(red: 0.906, green: 0.863, blue: 0.984).opacity(0.95), .clear],
                    center: UnitPoint(x: 0.16, y: 0.10),
                    startRadius: 0, endRadius: 340
                )

                RadialGradient(
                    colors: [Color(red: 0.992, green: 0.890, blue: 0.937).opacity(0.95), .clear],
                    center: UnitPoint(x: 0.86, y: 0.16),
                    startRadius: 0, endRadius: 320
                )

                RadialGradient(
                    colors: [Color(red: 0.875, green: 0.969, blue: 0.933).opacity(0.90), .clear],
                    center: UnitPoint(x: 0.74, y: 0.86),
                    startRadius: 0, endRadius: 340
                )

                RadialGradient(
                    colors: [Color(red: 0.996, green: 0.953, blue: 0.886).opacity(0.92), .clear],
                    center: UnitPoint(x: 0.26, y: 0.80),
                    startRadius: 0, endRadius: 360
                )
            }
        }
        // 5 层渐变是静态的，栅格成一张位图，滚动时不再逐帧重画
        .drawingGroup()
        .ignoresSafeArea()
    }
}

extension View {
    /// 统一大标题风格
    func twTitle() -> some View {
        self.font(.system(size: 36, weight: .heavy))
    }
}

struct TwGradientText: View {
    let text: String
    var size: CGFloat = 34
    @Environment(\.colorScheme) private var scheme

    private var colors: [Color] {
        if scheme == .dark {
            return [
                Color(red: 0.812, green: 0.769, blue: 0.965),
                Color(red: 0.741, green: 0.588, blue: 0.996),
                Color(red: 0.976, green: 0.560, blue: 0.808),
                Color(red: 0.996, green: 0.694, blue: 0.596)
            ]
        }
        return [
            Color(red: 0.231, green: 0.184, blue: 0.388),
            Color(red: 0.486, green: 0.294, blue: 0.839),
            Color(red: 0.851, green: 0.310, blue: 0.592),
            Color(red: 0.937, green: 0.498, blue: 0.416)
        ]
    }

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .foregroundStyle(
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
            )
    }
}

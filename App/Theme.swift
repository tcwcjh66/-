import SwiftUI

enum TWColor {
    static let ink    = Color(red: 0.090, green: 0.086, blue: 0.110)
    static let ink2   = Color(red: 0.427, green: 0.416, blue: 0.471)
    static let ink3   = Color(red: 0.647, green: 0.631, blue: 0.686)
    static let purple = Color(red: 0.545, green: 0.361, blue: 0.965)
    static let violet = Color(red: 0.655, green: 0.545, blue: 0.980)
    static let pink   = Color(red: 0.957, green: 0.447, blue: 0.714)
    static let coral  = Color(red: 0.984, green: 0.443, blue: 0.522)
    static let mint   = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let mintSoft = Color(red: 0.369, green: 0.918, blue: 0.831)
    static let blue   = Color(red: 0.184, green: 0.420, blue: 1.0)
    static let amber  = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let cardShadow = Color(red: 0.235, green: 0.157, blue: 0.431).opacity(0.10)
}

/// 整块背景：四角光晕 + 斜向渐变，对应网页 body::before
struct AuroraBG: View {
    var body: some View {
        ZStack {
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
        .ignoresSafeArea()
    }
}

extension View {
    /// 统一大标题风格
    func twTitle() -> some View {
        self.font(.system(size: 34, weight: .heavy, design: .rounded))
    }
}

struct TwGradientText: View {
    let text: String
    var size: CGFloat = 34

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.231, green: 0.184, blue: 0.388),
                        Color(red: 0.486, green: 0.294, blue: 0.839),
                        Color(red: 0.851, green: 0.310, blue: 0.592),
                        Color(red: 0.937, green: 0.498, blue: 0.416)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
}

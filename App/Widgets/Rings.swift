import SwiftUI

struct ProgressRing: View {
    var value: Double
    var lineWidth: CGFloat
    var colors: [Color]
    var size: CGFloat

    var body: some View {
        let p = min(max(value, 0), 1)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.34), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: p)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: colors),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .shadow(color: colors.first?.opacity(0.30) ?? .clear, radius: 7, x: 0, y: 0)
        }
    }
}

struct FourRings: View {
    var move: Double
    var exercise: Double
    var stand: Double
    var hrv: Double

    var body: some View {
        ZStack {
            ProgressRing(value: move, lineWidth: 11,
                         colors: [TWColor.purple, TWColor.violet], size: 176)
            ProgressRing(value: exercise, lineWidth: 11,
                         colors: [TWColor.pink, TWColor.coral], size: 146)
            ProgressRing(value: stand, lineWidth: 11,
                         colors: [TWColor.mint, TWColor.mintSoft], size: 116)
            ProgressRing(value: hrv, lineWidth: 11,
                         colors: [TWColor.amber, Color(red: 1.0, green: 0.86, blue: 0.48)], size: 86)
        }
        .frame(width: 176, height: 176)
    }
}

/// 巨型刻度盘
struct BigDial: View {
    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                ForEach(0..<72, id: \.self) { i in
                    let major = (i % 6 == 0)
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(major ? 0.92 : 0.46))
                        .frame(width: major ? 2.6 : 1.3, height: major ? 17 : 9)
                        .offset(y: -(r - 10))
                        .rotationEffect(.degrees(Double(i) * 5.0))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

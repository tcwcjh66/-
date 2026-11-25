import SwiftUI

struct BioPage: View {
    @EnvironmentObject var store: TWStore

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "身体", subtitle: "实时体征 · 手表回传")

            hrCard
            bodyRow
            syncCard
        }
    }

    private var hrCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("实时心率")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: "静息", tint: TWColor.coral)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.hr)")
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("HRV")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                    Text("\(store.hrv) ms")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(TWColor.amber)
                }
            }

            SparkLine()
                .frame(height: 62)
        }
        .padding(18)
        .twGlass()
    }

    private var bodyRow: some View {
        HStack(spacing: 10) {
            metric(title: "步数", value: "\(store.steps)", unit: "步", tint: TWColor.blue)
            metric(title: "活动", value: "\(Int(store.moveKcal))", unit: "kcal", tint: TWColor.purple)
        }
    }

    private func metric(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .twGlass(radius: 18)
    }

    private var syncCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "applewatch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Text("设备同步")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: "已连接", tint: TWColor.mint)
            }

            ForEach(syncItems) { item in
                HStack {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(TWColor.ink2)
                    Spacer()
                    Text(item.value)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            Text("心率与 HRV 来自 Apple Watch 的传感器；iPhone 本身没有光学心率模组，所以必须戴表才有真实数据。")
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(TWColor.ink3)
                .padding(.top, 2)
        }
        .padding(16)
        .twGlass()
    }

    private var syncItems: [SyncRow] {
        [
            SyncRow(title: "Apple Watch · Xs 配对手表", value: "刚刚"),
            SyncRow(title: "心率 / HRV", value: "实时"),
            SyncRow(title: "步数 / 爬楼", value: "实时"),
            SyncRow(title: "睡眠分期", value: "今晨 07:12")
        ]
    }
}

struct SyncRow: Identifiable {
    let id = UUID()
    var title: String
    var value: String
}

struct SparkLine: View {
    private let points: [CGFloat] = [0.42, 0.55, 0.38, 0.62, 0.48, 0.7, 0.52, 0.66, 0.44, 0.58, 0.5, 0.72, 0.46, 0.6, 0.40]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                for (i, v) in points.enumerated() {
                    let x = w * CGFloat(i) / CGFloat(points.count - 1)
                    let y = h * (1 - v)
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(
                LinearGradient(colors: [TWColor.coral.opacity(0.85), TWColor.pink.opacity(0.65)],
                               startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
            .overlay {
                Path { p in
                    for (i, v) in points.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(points.count - 1)
                        let y = h * (1 - v)
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(TWColor.coral.opacity(0.14), lineWidth: 6)
            }
        }
    }
}

struct PageHeader: View {
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(TWColor.ink3)
                }
                TwGradientText(text: title, size: 29)
            }
            Spacer()
        }
    }
}

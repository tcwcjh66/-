import WidgetKit
import SwiftUI

@main
struct TWWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        TWEntryWidget()
        TWRestLiveWidget()
    }
}

// MARK: - 桌面 / 锁屏入口

/// 免费签名拿不到 App Group，Widget 读不到主 App 的 UserDefaults。
/// 所以这里不编数字，只做入口和快捷格子：点哪进哪。
struct TWEntryEntry: TimelineEntry {
    let date: Date
}

struct TWEntryProvider: TimelineProvider {
    func placeholder(in context: Context) -> TWEntryEntry { TWEntryEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (TWEntryEntry) -> Void) {
        completion(TWEntryEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TWEntryEntry>) -> Void) {
        completion(Timeline(entries: [TWEntryEntry(date: Date())], policy: .never))
    }
}

struct TWEntryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TWEntry", provider: TWEntryProvider()) { entry in
            TWEntryView(date: entry.date)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.30, blue: 0.88),
                                 Color(red: 0.18, green: 0.36, blue: 0.62),
                                 Color(red: 0.10, green: 0.16, blue: 0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Persist")
        .description("四个入口：记水、拍餐、开练、记体重。")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TWEntryView: View {
    let date: Date
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 17, weight: .bold))
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Persist").font(.system(size: 13, weight: .bold))
                    Text("点开记今天").font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label("Persist · 记今天", systemImage: "bolt.heart.fill")
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Persist")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            Text("点开")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text("记今天的水 · 饭 · 训练")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
        .widgetURL(URL(string: "twfit://today"))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Persist")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                Spacer(minLength: 0)
                Text(date, format: .dateTime.month(.defaultDigits).day())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .foregroundStyle(.white)

            HStack(spacing: 7) {
                tile("记水", "drop.fill", "twfit://water")
                tile("拍餐", "camera.fill", "twfit://meal")
                tile("开练", "figure.strengthtraining.traditional", "twfit://train")
                tile("体重", "scalemass.fill", "twfit://weight")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(4)
    }

    private func tile(_ title: String, _ icon: String, _ link: String) -> some View {
        Link(destination: URL(string: link)!) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.16))
            }
        }
    }
}

// MARK: - 训练实况

struct TWRestLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TWRestAttributes.self) { context in
            let resting = context.state.phase == "rest"
            HStack(spacing: 14) {
                Image(systemName: resting ? "timer" : "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(.white.opacity(0.16)) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(resting
                         ? (context.state.move.isEmpty ? "组间休息" : "\(context.state.move) 之后")
                         : (context.attributes.plan.isEmpty ? "训练进行中" : "\(context.attributes.plan) · 训练中"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(resting
                         ? (context.state.next.isEmpty ? "歇够了继续" : "下一个：\(context.state.next)")
                         : "第 \(max(1, context.state.setNo)) 组 · 记完一组自动更新")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if resting {
                    Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 78, alignment: .trailing)
                } else {
                    Text("第 \(max(1, context.state.setNo)) 组")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 78, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(red: 0.16, green: 0.13, blue: 0.32))
        } dynamicIsland: { context in
            let resting = context.state.phase == "rest"
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(resting ? (context.state.move.isEmpty ? "休息" : context.state.move) : "训练中",
                          systemImage: resting ? "timer" : "figure.strengthtraining.traditional")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if resting {
                        Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    } else {
                        Text("第 \(max(1, context.state.setNo)) 组")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(resting ? "休息中" : "已记 \(max(1, context.state.setNo) - 1) 组")
                        .font(.system(size: 11))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(resting
                         ? (context.state.next.isEmpty ? "歇够了点开继续下一组" : "下一个：\(context.state.next)")
                         : (context.attributes.plan.isEmpty ? "点开回到训练" : context.attributes.plan))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: resting ? "timer" : "figure.strengthtraining.traditional")
            } compactTrailing: {
                if resting {
                    Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: 44)
                } else {
                    Text("\(max(1, context.state.setNo))")
                        .font(.system(size: 12, weight: .bold))
                        .frame(maxWidth: 44)
                }
            } minimal: {
                Image(systemName: resting ? "timer" : "figure.strengthtraining.traditional")
            }
        }
    }
}

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

// MARK: - 锁屏 / 桌面入口

/// 免费签名拿不到 App Group，Widget 读不到主 App 的 UserDefaults。
/// 所以这里不编步数，只做入口：点一下直接进 App 记当天的账。
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
                        colors: [Color(red: 0.45, green: 0.31, blue: 0.90),
                                 Color(red: 0.22, green: 0.18, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("天才威")
        .description("点一下打开天才威，记今天的水、饭和训练。")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
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
                    Text("天才威").font(.system(size: 13, weight: .bold))
                    Text("点开记今天").font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label("天才威 · 记今天", systemImage: "bolt.heart.fill")
        default:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("天才威")
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
    }
}

// MARK: - 组间休息实况

struct TWRestLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TWRestAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background { Circle().fill(.white.opacity(0.16)) }

                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.move.isEmpty ? "组间休息" : "\(context.attributes.move) 之后")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                    Text(context.attributes.next.isEmpty ? "歇够了继续" : "下一个：\(context.attributes.next)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 78, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .activityBackgroundTint(Color(red: 0.18, green: 0.14, blue: 0.34))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.move.isEmpty ? "休息" : context.attributes.move,
                          systemImage: "figure.strengthtraining.traditional")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("休息中")
                        .font(.system(size: 11))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.next.isEmpty ? "歇够了点开继续下一组" : "下一个：\(context.attributes.next)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.endAt, countsDown: true)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }
}

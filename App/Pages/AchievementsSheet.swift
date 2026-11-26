import SwiftUI

struct AchievementItem: Identifiable {
    var id: String
    var title: String
    var note: String
    var icon: String
    var tint: Color
    var done: Bool
    /// 0–1，用来画未解锁时的进度条；nil 表示不显示进度
    var progress: Double? = nil
}

struct AchievementsSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var glow = false

    private var totalTonnage: Double {
        store.sessions.compactMap { $0.tonnage }.reduce(0, +)
    }

    private var goodSleepCount: Int {
        store.sleepLogs.filter { $0.end.timeIntervalSince($0.start) >= 7 * 3600 }.count
    }

    private var items: [AchievementItem] {
        let ton = totalTonnage
        return [
            AchievementItem(id: "first", title: "开张", note: "完成第 1 次训练",
                            icon: "flag.fill", tint: TWColor.mint,
                            done: store.sessions.count >= 1,
                            progress: min(1, Double(store.sessions.count) / 1)),
            AchievementItem(id: "streak3", title: "三日不断", note: "连续训练 3 天",
                            icon: "flame.fill", tint: TWColor.amber,
                            done: store.trainingStreak >= 3,
                            progress: min(1, Double(store.trainingStreak) / 3)),
            AchievementItem(id: "streak7", title: "一周不歇", note: "连续训练 7 天",
                            icon: "flame", tint: TWColor.coral,
                            done: store.trainingStreak >= 7,
                            progress: min(1, Double(store.trainingStreak) / 7)),
            AchievementItem(id: "streak15", title: "半月坚持", note: "连续训练 15 天",
                            icon: "crown.fill", tint: TWColor.purple,
                            done: store.trainingStreak >= 15,
                            progress: min(1, Double(store.trainingStreak) / 15)),
            AchievementItem(id: "s10", title: "十炼", note: "累计 10 次训练",
                            icon: "dumbbell.fill", tint: TWColor.blue,
                            done: store.sessions.count >= 10,
                            progress: min(1, Double(store.sessions.count) / 10)),
            AchievementItem(id: "s50", title: "五十炼", note: "累计 50 次训练",
                            icon: "dumbbell", tint: TWColor.violet,
                            done: store.sessions.count >= 50,
                            progress: min(1, Double(store.sessions.count) / 50)),
            AchievementItem(id: "t1", title: "一吨", note: "累计举重 1000 kg",
                            icon: "scalemass.fill", tint: TWColor.mint,
                            done: ton >= 1000,
                            progress: min(1, ton / 1000)),
            AchievementItem(id: "t10", title: "十吨", note: "累计举重 10000 kg",
                            icon: "scalemass", tint: TWColor.amber,
                            done: ton >= 10000,
                            progress: min(1, ton / 10000)),
            AchievementItem(id: "weigh", title: "有据可依", note: "记录体重 10 次",
                            icon: "chart.line.uptrend.xyaxis", tint: TWColor.blue,
                            done: store.weightLogs.count >= 10,
                            progress: min(1, Double(store.weightLogs.count) / 10)),
            AchievementItem(id: "sleep", title: "睡够", note: "睡满 7 小时 5 次",
                            icon: "moon.zzz.fill", tint: TWColor.violet,
                            done: goodSleepCount >= 5,
                            progress: min(1, Double(goodSleepCount) / 5)),
        ]
    }

    private var unlockedCount: Int { items.filter { $0.done }.count }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("成就")
                                .font(.tw(26, .heavy))
                                .foregroundStyle(TWColor.ink)
                            Text("已解锁 \(unlockedCount) / \(items.count)")
                                .font(.tw(12.5, .medium))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        statTile("连续天数", "\(store.trainingStreak)", TWColor.amber)
                        statTile("训练次数", "\(store.sessions.count)", TWColor.purple)
                        statTile("总容量", tonText(totalTonnage), TWColor.mint)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 11),
                                        GridItem(.flexible(), spacing: 11)], spacing: 11) {
                        ForEach(items) { item in
                            badge(item)
                        }
                    }

                    Text("全部由本机记录算出，没有一条是写死的。新记录会继续解锁，旧数据不丢。")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // 让已解锁的徽章开始呼吸
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { glow = true }
        }
    }

    private func tonText(_ v: Double) -> String {
        if v >= 10000 { return String(format: "%.1f t", v / 1000) }
        if v >= 1000 { return String(format: "%.0f kg", v) }
        return String(format: "%.0f kg", v)
    }

    private func statTile(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tw(10.5, .medium))
                .foregroundStyle(TWColor.ink3)
            Text(value)
                .font(.tw(17, .heavy))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.55))
        }
    }

    private func badge(_ item: AchievementItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(item.done ? item.tint.opacity(0.16) : TWColor.ink3.opacity(0.10))
                        .frame(width: 34, height: 34)
                    Image(systemName: item.done ? item.icon : "lock.fill")
                        .font(.tw(14, .bold))
                        .foregroundStyle(item.done ? item.tint : TWColor.ink3.opacity(0.7))
                        .scaleEffect(item.done && glow ? 1.14 : 1.0)
                        .animation(item.done
                                   ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                                   : .default,
                                   value: glow)
                }
                Spacer(minLength: 0)
                if item.done {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.tw(12, .bold))
                        .foregroundStyle(item.tint)
                }
            }

            Text(item.title)
                .font(.tw(14, .bold))
                .foregroundStyle(item.done ? TWColor.ink : TWColor.ink2)

            Text(item.note)
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if !item.done, let p = item.progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TWColor.ink3.opacity(0.15))
                        Capsule()
                            .fill(item.tint.opacity(0.7))
                            .frame(width: max(3, geo.size.width * p))
                    }
                }
                .frame(height: 3)
            } else {
                Spacer(minLength: 0).frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .twGlass(radius: 16)
        .opacity(item.done ? 1 : 0.92)
    }
}

import SwiftUI

/// 运行状态：把"到底存了几份、同步还活着吗"摊开，出问题不用猜。
struct SystemStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TWStore

    @State private var backups: [String] = []
    @State private var backupBytes: Int = 0
    @State private var photoBytes: Int = 0
    @State private var photoCount: Int = 0
    @State private var prefsCount: Int = 0

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("运行状态")
                            .font(.tw(24, .heavy, .rounded))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 32, height: 32)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)

                    card("自动备份") {
                        row("备份份数", "\(backups.count) 份", backups.isEmpty ? TWColor.coral : TWColor.mint)
                        row("占用", bytes(backupBytes), TWColor.ink2)
                        if let latest = backups.first {
                            row("最新一份", latest, TWColor.ink2)
                        } else {
                            row("说明", "还没写过，明天首次启动会补一份", TWColor.amber)
                        }
                    }

                    card("本机数据") {
                        row("今日步数", "\(store.stepsForDisplay) 步", TWColor.ink2)
                        row("饮食记录", "\(store.meals.count) 餐", TWColor.ink2)
                        row("训练记录", "\(store.sessions.count) 次", TWColor.ink2)
                        row("体重记录", "\(store.weightLogs.count) 条", TWColor.ink2)
                        row("餐食照片", "\(photoCount) 张 · \(bytes(photoBytes))", TWColor.ink2)
                        row("偏好项", "\(prefsCount) 个", TWColor.ink2)
                    }

                    card("手表同步") {
                        row("累计同步", "\(store.watchSyncCount) 次", store.watchSyncCount > 0 ? TWColor.mint : TWColor.ink3)
                        row("上次同步", timeText(store.watchSyncAt), TWColor.ink2)
                        row("心率来源", store.hrSource.isEmpty ? "还没测过" : store.hrSource, TWColor.ink2)
                    }

                    card("免费签名") {
                        row("已用", "\(TWSideload.daysUsed) 天", TWColor.ink2)
                        row("还剩", TWSideload.dayText, TWSideload.daysLeft <= 2 ? TWColor.coral : TWColor.amber)
                        Text("到期后 App 会打不开，重装前先在「数据」里导一份 JSON。")
                            .font(.tw(10.5))
                            .foregroundStyle(TWColor.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("都是本机真实数值，读不到就显示“还没”，不编。")
                        .font(.tw(10.5))
                        .foregroundStyle(TWColor.ink3)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        let fm = FileManager.default
        let dir = TWBackup.dir()
        if let fs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
            backups = fs.sorted { $0.lastPathComponent > $1.lastPathComponent }.map { $0.lastPathComponent }
            backupBytes = fs.reduce(0) { sum, f in
                sum + ((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }

        let photos = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mealPhotos", isDirectory: true)
        if let fs = try? fm.contentsOfDirectory(at: photos, includingPropertiesForKeys: [.fileSizeKey]) {
            photoCount = fs.count
            photoBytes = fs.reduce(0) { sum, f in
                sum + ((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        prefsCount = UserDefaults.standard.dictionaryRepresentation().keys.count
    }

    private func card<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink2)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    private func row(_ k: String, _ v: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(k)
                .font(.tw(12))
                .foregroundStyle(TWColor.ink3)
            Spacer(minLength: 8)
            Text(v)
                .font(.tw(12, .semibold))
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }

    private func bytes(_ n: Int) -> String {
        if n > 1024 * 1024 { return String(format: "%.1f MB", Double(n) / 1048576.0) }
        if n > 1024 { return String(format: "%.0f KB", Double(n) / 1024.0) }
        return "\(n) B"
    }

    private func timeText(_ d: Date?) -> String {
        guard let d else { return "还没同步过" }
        let f = DateFormatter()
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }
}

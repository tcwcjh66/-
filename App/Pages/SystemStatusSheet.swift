import SwiftUI
import UserNotifications
import AVFoundation
import Photos
import ActivityKit

/// 运行状态：把"到底存了几份、同步还活着吗"摊开，出问题不用猜。
/// 免费签名下，扩展和权限经常悄悄失效，所以这里连"能力"一起体检。
struct SystemStatusSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: TWStore

    @State private var backups: [String] = []
    @State private var backupBytes: Int = 0
    @State private var photoBytes: Int = 0
    @State private var photoCount: Int = 0
    @State private var prefsCount: Int = 0

    /// 能力自检结果：能用的打勾，不能用的写清楚卡在哪
    @State private var caps: [Cap] = []
    @State private var checking = false
    @State private var exportURL: URL?
    @State private var issues: [TWDataIssue] = []
    @State private var lastCrash: Date?
    @State private var cleanTip = ""

    struct Cap: Identifiable {
        let id = UUID()
        let name: String
        let ok: Bool
        let detail: String
    }

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

                    card("能力自检") {
                        if caps.isEmpty {
                            row("状态", checking ? "正在检查…" : "点下面的按钮跑一遍", TWColor.ink3)
                        } else {
                            ForEach(caps) { c in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: c.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .font(.tw(12, .bold))
                                        .foregroundStyle(c.ok ? TWColor.mint : TWColor.coral)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name)
                                            .font(.tw(12, .semibold))
                                            .foregroundStyle(TWColor.ink)
                                        Text(c.detail)
                                            .font(.tw(10.5))
                                            .foregroundStyle(TWColor.ink3)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }

                        Button {
                            Task { await runChecks() }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.tw(11, .bold))
                                Text(checking ? "检查中…" : "重新检查一遍")
                                    .font(.tw(12, .bold))
                            }
                            .foregroundStyle(TWColor.mint)
                        }
                        .buttonStyle(.plain)
                        .disabled(checking)
                    }

                    card("重装前先存一份") {
                        Text("卸载会连 Documents 一起清掉。把 JSON 存进「文件」，重装后从「数据」导回来，记录原样还在。")
                            .font(.tw(10.5))
                            .foregroundStyle(TWColor.ink3)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            exportURL = store.exportJSONFile()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.badge.arrow.up")
                                    .font(.tw(11, .bold))
                                Text(exportURL == nil ? "生成一份备份" : "重新生成")
                                    .font(.tw(12, .bold))
                            }
                            .foregroundStyle(TWColor.blue)
                        }
                        .buttonStyle(.plain)

                        if let exportURL {
                            ShareLink(item: exportURL, subject: Text("Persist数据备份")) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.tw(11, .bold))
                                    Text("存到「文件」App")
                                        .font(.tw(12, .bold))
                                }
                                .foregroundStyle(TWColor.mint)
                            }
                        }
                    }

                    card("数据体检") {
                        if issues.isEmpty {
                            row("状态", "没发现空记录或异常跳动", TWColor.mint)
                        } else {
                            ForEach(issues) { i in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(i.title)
                                        .font(.tw(12.5, .semibold))
                                        .foregroundStyle(TWColor.coral)
                                    Text(i.detail)
                                        .font(.tw(10.5))
                                        .foregroundStyle(TWColor.ink3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if let zero = issues.first(where: { $0.kind == "zero" }) {
                                Button {
                                    let n = store.cleanZeroSessions()
                                    issues = store.auditData()
                                    cleanTip = n > 0 ? "已清掉 \(n) 条" : "没有可清的"
                                } label: {
                                    Text(cleanTip.isEmpty ? "清掉这 \(zero.count) 条空训练" : cleanTip)
                                        .font(.tw(12, .bold))
                                }
                                .foregroundStyle(TWColor.mint)
                            }
                        }
                        row("上次异常退出", lastCrash == nil ? "无记录" : timeText(lastCrash),
                            lastCrash == nil ? TWColor.mint : TWColor.coral)
                    }

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
        .onAppear {
            reload()
            Task { await runChecks() }
        }
    }

    /// 免费签名最容易出问题的地方：扩展没带上、权限被拒、实时活动被系统关掉。
    /// 一次把结论摆出来，比在训练中途闪退再猜强。
    private func runChecks() async {
        await MainActor.run { checking = true }
        var out: [Cap] = []

        let ns = await UNUserNotificationCenter.current().notificationSettings()
        switch ns.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            out.append(Cap(name: "通知", ok: true, detail: "已授权，提醒能正常弹出"))
        case .denied:
            out.append(Cap(name: "通知", ok: false, detail: "已被拒绝，要去系统设置里手动打开"))
        case .notDetermined:
            out.append(Cap(name: "通知", ok: false, detail: "还没申请过，开任意一个提醒就会申请"))
        @unknown default:
            out.append(Cap(name: "通知", ok: false, detail: "状态未知"))
        }

        let cam = AVCaptureDevice.authorizationStatus(for: .video)
        if cam == .authorized {
            out.append(Cap(name: "相机", ok: true, detail: "拍照识别、扫条码可用"))
        } else if cam == .denied {
            out.append(Cap(name: "相机", ok: false, detail: "已被拒绝，拍照和扫码都会失败"))
        } else if cam == .restricted {
            out.append(Cap(name: "相机", ok: false, detail: "被系统限制，无法使用"))
        } else {
            out.append(Cap(name: "相机", ok: false, detail: "还没申请过，第一次拍照时会申请"))
        }

        let photo = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if photo == .authorized || photo == .limited {
            out.append(Cap(name: "相册", ok: true, detail: photo == .limited ? "只授权了部分照片" : "从相册选图可用"))
        } else if photo == .denied {
            out.append(Cap(name: "相册", ok: false, detail: "已被拒绝，相册里的餐食照片读不到"))
        } else if photo == .restricted {
            out.append(Cap(name: "相册", ok: false, detail: "被系统限制"))
        } else {
            out.append(Cap(name: "相册", ok: false, detail: "还没申请过"))
        }

        let live = ActivityAuthorizationInfo().areActivitiesEnabled
        out.append(Cap(name: "实时活动 · 组间倒计时", ok: live,
                       detail: live ? "锁屏和灵动岛都能显示倒计时"
                                     : "系统里关掉了实时活动，锁屏看不到倒计时"))

        let plugins = Bundle.main.bundleURL.appendingPathComponent("PlugIns")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: plugins.path)) ?? []
        let exts = files.filter { $0.hasSuffix(".appex") }
        out.append(Cap(name: "桌面小组件", ok: !exts.isEmpty,
                       detail: exts.isEmpty
                       ? "包内没有扩展，桌面长按不会出现「Persist」"
                       : "已打进包：\(exts.joined(separator: "、"))"))

        await MainActor.run {
            caps = out
            checking = false
        }
    }

    private func reload() {
        issues = store.auditData()
        if let ts = UserDefaults.standard.object(forKey: "tw.lastCrashAt.v1") as? Double {
            lastCrash = Date(timeIntervalSince1970: ts)
        }
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

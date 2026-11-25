import SwiftUI
import UIKit

/// 手表同步：把 Apple Watch 的健康数据通过「快捷指令」带进天才威。
/// 免费签名读不了 HealthKit；快捷指令是系统 App，能读，它把值拼进 URL 再交回这里。
struct WatchSyncSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var copied = false
    @State private var copiedSteps = false
    @State private var copiedFull = false

    /// 最快能用的一条：心率 + 步数 + 活动能量 + 睡眠 + 血氧
    private let quickTemplate = "twfit://sync?hr=[心率]&steps=[步数]&kcal=[活动能量]&sleep=[睡眠分钟]&spo2=[血氧]"

    /// 全量 11 项
    private let template = """
    twfit://sync?hr=[心率]&hrv=[HRV]&rhr=[静息心率]&steps=[步数]&dist=[距离]&kcal=[活动能量]&exercise=[锻炼分钟]&stand=[站立小时]&sleep=[睡眠分钟]&deep=[深睡分钟]&spo2=[血氧]
    """

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    oneTapCard
                    statusCard
                    quickCard
                    paramCard
                    templateCard
                    troubleCard
                    mindfulCard
                    whyCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 34)
            }
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("手表同步")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                Text("五步配一次，之后打开 App 自动灌数据")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 33, height: 33)
                    .background {
                        Circle().fill(TWColor.glass(0.5))
                            .overlay(Circle().stroke(TWColor.glass(0.7), lineWidth: 0.8))
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    // MARK: - 状态

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("同步状态")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text(store.watchSyncAt == nil ? "未连通" : "已连通")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(store.watchSyncAt == nil ? TWColor.amber : TWColor.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill((store.watchSyncAt == nil ? TWColor.amber : TWColor.mint).opacity(0.13))
                    }
            }

            if let t = store.watchSyncAt {
                Text("上次同步 \(DateFormatter.twDay.string(from: t)) \(DateFormatter.twShort.string(from: t))，累计 \(store.watchSyncCount) 次")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink2)
            } else {
                Text("还没收到过数据。照下面「五步」走一遍，末了打开一次天才威，这里就会变成「已连通」。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                syncCell("心率", store.hr > 0 ? "\(store.hr)" : "—", "bpm")
                syncCell("步数", "\(store.pedometerSteps > 0 ? store.pedometerSteps : store.watchSteps)", "步 · 实时")
                syncCell("血氧", store.watchSpO2 > 0 ? "\(store.watchSpO2)" : "—", "%")
            }
            HStack(spacing: 0) {
                syncCell("睡眠", store.watchSleepMin > 0 ? sleepText(store.watchSleepMin) : "—", "小时")
                syncCell("活动", String(format: "%.0f", store.moveKcal), "kcal")
                syncCell("锻炼", String(format: "%.0f", store.exerciseMin), "分钟")
            }
        }
        .padding(16)
        .twGlass()
    }

    private func syncCell(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Text("\(title) · \(unit)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func sleepText(_ min: Int) -> String {
        "\(min / 60)h\(String(format: "%02d", min % 60))"
    }

    // MARK: - 一键

    private var oneTapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("第一步：点这里")
                    .font(.system(size: 16.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            Text("点一下会把「5 项模板」放进剪贴板，同时跳到快捷指令。到那边直接粘贴，不用手打。")
                .font(.system(size: 12.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button { makeShortcut() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(copied ? "已复制 · 正在跳转" : "复制模板并打开快捷指令")
                        .font(.system(size: 14.5, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background {
                    Capsule().fill(LinearGradient(colors: [TWColor.purple, TWColor.blue],
                                                  startPoint: .leading, endPoint: .trailing))
                }
                .shadow(color: TWColor.purple.opacity(0.26), radius: 12, y: 5)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "info.circle").font(.system(size: 10.5))
                Text("iOS 不允许 App 直接写入快捷指令，跳过去粘一下是系统上限，不是偷懒。")
                    .font(.system(size: 10.5))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 五步

    private var quickCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("五步，照着屏幕点")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button { copySteps() } label: {
                    Text(copiedSteps ? "已复制" : "复制全文")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                }
                .buttonStyle(.plain)
            }

            step(1,
                 "打开「快捷指令」App，点底部「自动化」，右上角 +",
                 "桌面找不到就下拉搜索“快捷指令”。进自动化后先点 + 建一条新的。")

            step(2,
                 "选「App」→ 搜“天才威”→ 选中 → 勾「打开时」→ 打开「立即运行」→ 点「下一步」",
                 "「立即运行」不开的话，每次都会先弹一个确认框，白等两秒。")

            step(3,
                 "回到「所有快捷指令」，右上角 + 新建，名字随便起（比如“天才威同步”）",
                 "这条是“数据源”，第 2 步那条自动化稍后来调它。")

            step(4,
                 "点「添加动作」→ 搜「查找健康样本」，加 4 个：心率、步数、活动能量、睡眠分析",
                 "每个动作里：类型改成对应那一项，「排序方式」选「最新样本」，「限制」填 1。睡眠选「睡眠分析」，它的值是分钟。")

            step(5,
                 "加「文本」→ 粘贴第一步复制的模板 → 把 [心率] 这类方括号逐个换成变量 → 再加「打开 URL」",
                 "换变量：先删掉方括号里的字，点键盘上方「变量」，选那个查找动作的「值」。最后「打开 URL」的输入选这个文本。")

            Text("收尾：回到自动化那条 → 「添加动作」→ 选刚建的快捷指令 → 完成。之后每次打开天才威就自动同步。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(n)")
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background {
                    Circle().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 参数表

    private var paramCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("每个占位填什么")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(TWColor.ink2)

            paramRow("[心率]", "心率", "最新样本 · 限制 1", head: true)
            paramRow("[步数]", "步数", "最新样本 · 限制 1")
            paramRow("[活动能量]", "活动能量", "最新样本 · 限制 1")
            paramRow("[睡眠分钟]", "睡眠分析", "最新样本 · 取时长")
            paramRow("[血氧]", "血氧饱和度", "最新样本 · 限制 1")
            paramRow("[HRV]", "心率变异性", "最新样本 · 限制 1")
            paramRow("[静息心率]", "静息心率", "最新样本 · 限制 1")
            paramRow("[距离]", "步行+跑步距离", "今日求和")
            paramRow("[锻炼分钟]", "锻炼时间", "今日求和")
            paramRow("[站立小时]", "站立小时", "今日求和")
            paramRow("[专注时长]", "正念分钟", "最新样本 · 取时长（模板里有时长就填这行）")
            paramRow("[深睡分钟]", "睡眠分析", "筛「深睡」阶段再求和，较绕，可先跳过")

            Text("只要心率、步数、血氧，就只做前 4 个动作，模板里也只留对应占位。缺的参数 App 会自动跳过，不报错。")
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .twGlass()
    }

    private func paramRow(_ key: String, _ type: String, _ how: String, head: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(head ? TWColor.purple : TWColor.ink)
                .frame(width: 92, alignment: .leading)
            Text(type)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 96, alignment: .leading)
            Text(how)
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 3)
    }

    // MARK: - 模板

    private var templateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("全量模板（11 项）")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Button { copyFull() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedFull ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(copiedFull ? "已复制" : "复制")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                }
                .buttonStyle(.plain)
            }

            Text(template)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(TWColor.glass(0.55))
                }

            Text("上面那个按钮给的是 5 项简版。要 HRV、距离、锻炼分钟这些就用这条全量的；用不到的占位连同前面的 & 一起删掉也行。")
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 卡住了？

    private var troubleCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("卡住了？对照这几条")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            trouble("点了按钮没跳过去", "确认「快捷指令」没被删、没被屏幕使用时间限制。跳不过去就手动打开它，模板已经在剪贴板里了。")
            trouble("文本里插不进变量", "「查找健康样本」必须排在「文本」前面。先有查找动作，变量列表里才出现它的值。")
            trouble("URL 打开没反应", "检查是不是以 twfit:// 开头、中间没有空格、& 不是中文的＆。")
            trouble("每次打开都弹确认", "自动化里关掉「运行前询问」，并确认选的是「立即运行」。")
            trouble("步数一直是 0", "设置 → 隐私与安全 → 运动与健身 → 天才威 打开；步数要手机在身上才计得准。")
            trouble("血氧显示 0 或 0.98", "健康里的血氧是 0.98 这种小数，App 两种写法都认，直接传就行。")
            trouble("心率一直是 0", "手表要贴合手腕、健康里有心率记录；「最新样本」当天没记录就是空。")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    private func trouble(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(q)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TWColor.ink)
            Text(a)
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 正念

    private var mindfulCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.mintSoft)
                Text("手表沉思 → App 心情")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if store.mindfulAt != nil {
                    Text("已生效")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(TWColor.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(TWColor.mint.opacity(0.13)) }
                }
            }

            Text("手表上做完一次「正念」，健康里会记「正念分钟」。同一条快捷指令加一个「查找健康样本 · 正念」（最新 1 条），URL 结尾补 &mind=[正念分钟]。")
                .font(.system(size: 12))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("收到 mind 后首页立绘会切「平静」：呼吸变慢、色温转薄荷。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            if let at = store.mindfulAt {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(TWColor.mint)
                    Text("上次正念 \(store.mindfulMin) 分钟 · \(DateFormatter.twShort.string(from: at))")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 为什么

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.amber)
                Text("为什么必须绕快捷指令")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("Apple Watch 的数据在系统「健康」里。第三方 App 直连要 HealthKit 权限，这个权限只在付费开发者账号下发；免费签名的 App 一调就 AUTH_FAILED。\n\n快捷指令是系统 App，天生能读健康。让它读出来、拼成链接交给天才威——这条完全免费，也是免费签名下唯一走得通的路。")
                .font(.system(size: 12))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 动作

    private func makeShortcut() {
        UIPasteboard.general.string = quickTemplate
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }

        let create = URL(string: "shortcuts://create-shortcut")
        let root = URL(string: "shortcuts://")
        guard let target = create else {
            if let root { UIApplication.shared.open(root) }
            return
        }
        UIApplication.shared.open(target, options: [:]) { ok in
            if !ok, let root { UIApplication.shared.open(root) }
        }
    }

    private func copyFull() {
        UIPasteboard.general.string = template
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        copiedFull = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedFull = false }
    }

    private func copySteps() {
        let text = """
        天才威 · 手表同步 五步

        模板（App 里点“复制模板并打开快捷指令”也能拿到）：
        \(quickTemplate)

        1. 快捷指令 App → 底部「自动化」→ 右上角 +
        2. 选「App」→ 搜“天才威”→ 勾「打开时」→ 开「立即运行」→ 下一步
        3. 回「所有快捷指令」→ 右上角 + 新建，名字随意
        4. 添加动作 → 搜「查找健康样本」，加 4 个：心率 / 步数 / 活动能量 / 睡眠分析
           每个：类型对应，排序方式=最新样本，限制=1
        5. 添加「文本」→ 粘贴模板 → 把 [心率] 这类方括号换成变量
           （删掉方括号内容，键盘上方点「变量」，选查找动作的值）
           再添加「打开 URL」，输入选这个文本

        收尾：自动化那条 → 添加动作 → 选刚建的快捷指令
        之后每次打开天才威自动同步。
        """
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        copiedSteps = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSteps = false }
    }
}

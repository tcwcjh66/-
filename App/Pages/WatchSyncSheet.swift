import SwiftUI
import UIKit

struct WatchSyncSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var copiedSteps = false

    /// 快捷指令「文本」动作里粘贴的完整模板，方括号处换成对应的魔法变量
    private let template = """
    twfit://sync?hr=[心率]&hrv=[HRV]&rhr=[静息心率]&steps=[步数]&dist=[距离]&kcal=[活动能量]&exercise=[锻炼分钟]&stand=[站立小时]&sleep=[睡眠分钟]&deep=[深睡分钟]
    """

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    statusCard
                    whyCard
                    stepsCard
                    templateCard
                    mindfulCard
                    fallbackCard
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
                Text("快捷指令自动化 · 打开 App 就自动把健康数据灌进来")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2)
            }
            Spacer(minLength: 0)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 33, height: 33)
                    .background {
                        Circle().fill(Color.white.opacity(0.5))
                            .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.8))
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
                if let t = store.watchSyncAt {
                    Text("已连通")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TWColor.mint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background {
                            Capsule().fill(TWColor.mint.opacity(0.13))
                        }
                } else {
                    Text("未连通")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TWColor.amber)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background {
                            Capsule().fill(TWColor.amber.opacity(0.14))
                        }
                }
            }

            if let t = store.watchSyncAt {
                Text("上次同步 \(DateFormatter.twDay.string(from: t)) \(DateFormatter.twShort.string(from: t))，累计 \(store.watchSyncCount) 次")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink2)

                HStack(spacing: 0) {
                    syncStat("心率", store.hr > 0 ? "\(store.hr)" : "—", "bpm")
                    divider
                    syncStat("步数", store.watchSteps > 0 ? "\(store.watchSteps)" : "—", "步")
                    divider
                    syncStat("睡眠", store.watchSleepMin > 0 ? sleepText(store.watchSleepMin) : "—", "小时")
                }
            } else {
                Text("还没有收到过手表数据。按下面的五步配一次，之后每次打开这个 App 就会自动同步，不用再动手。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .twGlass()
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.22))
            .frame(width: 1, height: 26)
    }

    private func syncStat(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Text("\(title) · \(unit)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
        }
        .frame(maxWidth: .infinity)
    }

    private func sleepText(_ min: Int) -> String {
        let h = min / 60
        let m = min % 60
        return "\(h)h\(String(format: "%02d", m))"
    }

    // MARK: - 为什么

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.amber)
                Text("为什么必须走快捷指令")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("Apple Watch 的数据在系统「健康」里，第三方 App 直接读需要 HealthKit 权限（com.apple.developer.healthkit），这个权限只在付费开发者账号下才发。免费签名的 App 一调就报 AUTH_FAILED。\n\n快捷指令是系统 App，本身就有读健康的权限。让它把数据读出来，再用链接交给天才威，这条路完全免费，也是唯一可行的一条。")
                .font(.system(size: 12.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 五步

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("配一次，以后全自动")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button {
                    copySteps()
                } label: {
                    Text(copiedSteps ? "已复制" : "复制清单")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                }
                .buttonStyle(.plain)
            }

            step(1, "打开「快捷指令」App，点右上角 + 新建一个快捷指令，命名「天才威同步」。",
                 "先建一个空的，动作下面再加。")

            step(2, "连加 10 个「查找健康样本」动作，类型依次是：心率、HRV、静息心率、步数、步行+跑步距离、活动能量、锻炼分钟、站立小时、睡眠分析、深度睡眠。",
                 "每个动作里把「排序」设成最新，「限制」设成 1；步数和距离用「求和」而不是取最新。")

            step(3, "加一个「文本」动作，把下面那张卡里的模板整段粘进去，然后把每对方括号换成对应动作的魔法变量。",
                 "变量插入方式：在文本里点一下，键盘上方会出现「变量」，选对应的查找结果。")

            step(4, "加一个「打开 URL」动作，输入选「文本」上一步的输出。",
                 "这一步就是把数据交给天才威，跑完会自动跳回 App 并写入。")

            step(5, "去底部「自动化」标签 → 新建个人自动化 → 触发选「App」→ 选天才威 → 勾「打开时」→ 下一步 → 关掉「运行前询问」→ 完成。",
                 "到这一步就成了。以后每次点开天才威，健康数据自动灌进来。")

            Text("如果只想先要心率和步数，第 2 步只加那两个、模板里也只留 hr 和 steps 就行，其余留空不影响。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 模板

    private var templateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("粘贴到「文本」动作里的模板")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Button {
                    copyTemplate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5, weight: .bold))
                        Text(copied ? "已复制" : "复制")
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
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.55))
                }

            Text("参数表：hr 心率 · hrv 心率变异性 · rhr 静息心率 · steps 步数 · dist 公里 · kcal 活动能量 · exercise 锻炼分钟 · stand 站立小时 · sleep 睡眠分钟 · deep 深睡分钟。缺哪个就不带哪个，App 会自动跳过。")
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 正念 → 心情

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

            Text("在手表上做完一次「正念 / 沉思」，Apple 会把它记进健康里的「正念分钟」。在同一个快捷指令里再加一个「查找健康样本 · 正念」（取最近 1 条），URL 结尾补上 &mind=[正念分钟] 就行。")
                .font(.system(size: 12.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("接收端收到 mind 就把心情切到「平静」，首页立绘的呼吸节奏会慢下来、光晕转薄荷色。做完沉思后打开一次天才威，就生效了。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            if store.mindfulAt != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(TWColor.mint)
                    Text("上次正念 \(store.mindfulMin) 分钟 · \(DateFormatter.twShort.string(from: store.mindfulAt!))")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 兜底

    private var fallbackCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("只测心率的话，两步就够")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("新建快捷指令 → 加「查找健康样本（心率，最新）」→ 加「打开 URL」，URL 填：\n\ntwfit://sync?hr=[心率]\n\n这比配全套快，但只有心率一个数。要步数、睡眠、能耗就回到上面五步。")
                .font(.system(size: 12))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 复制

    private func copyTemplate() {
        UIPasteboard.general.string = template
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
    }

    private func copySteps() {
        let text = """
        天才威手表同步 · 配置清单

        1. 快捷指令 App → 右上角 + 新建，命名「天才威同步」
        2. 加 10 个「查找健康样本」：心率 / HRV / 静息心率 / 步数 / 步行跑步距离 / 活动能量 / 锻炼分钟 / 站立小时 / 睡眠分析 / 深度睡眠
           · 每个都设「排序=最新」「限制=1」
           · 步数、距离改成「求和」
        3. 加「文本」，粘贴：
        twfit://sync?hr=[心率]&hrv=[HRV]&rhr=[静息心率]&steps=[步数]&dist=[距离]&kcal=[活动能量]&exercise=[锻炼分钟]&stand=[站立小时]&sleep=[睡眠分钟]&deep=[深睡分钟]
           把每个 [xx] 换成对应查找动作的变量
        4. 加「打开 URL」，输入选上一步的文本
        5. 自动化标签 → 新建个人自动化 → 触发「App」→ 选天才威 → 勾「打开时」→ 关闭「运行前询问」→ 完成

        之后每次打开天才威自动同步，无需手动。
        """
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        copiedSteps = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSteps = false }
    }
}

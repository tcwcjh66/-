import SwiftUI
import UIKit

/// 手表同步：把 Apple Watch 的健康数据通过「快捷指令」带进天才威。
/// 免费签名读不了 HealthKit；快捷指令是系统 App，能读，它把值拼进 URL 再交回这里。
struct WatchSyncSheet: View {
    @EnvironmentObject var store: TWStore
    @EnvironmentObject var live: TWLive
    @Environment(\.dismiss) private var dismiss

    @State private var copied = false
    @State private var copiedSteps = false
    @State private var copiedFull = false
    @State private var showGuide = false
    @State private var runFail = false

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
                    guideEntry
                    oneTapCard
                    statusCard
                    quickCard
                    autoCard
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
        .sheet(isPresented: $showGuide) {
            ShortcutGuideSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    /// 只要心率的两步图解入口，外加「跑一次」——建好之后就不用再进快捷指令 App
    private var guideEntry: some View {
        VStack(spacing: 9) {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showGuide = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.purple)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(TWColor.purple.opacity(0.13)) }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("只要心率 · 两步图解")
                            .font(.tw(14.5, .bold))
                            .foregroundStyle(TWColor.ink)
                        Text("比下面的五步少一半，照着图点")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.tw(12, .bold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button { runShortcut() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill").font(.tw(10, .bold))
                        Text("跑一次").font(.tw(12, .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        Capsule().fill(LinearGradient(colors: [TWColor.mint, TWColor.mintSoft],
                                                      startPoint: .leading, endPoint: .trailing))
                    }
                }
                .buttonStyle(.plain)

                Button { makeShortcut() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.on.square").font(.tw(10, .bold))
                        Text("复制模板").font(.tw(12, .bold))
                    }
                    .foregroundStyle(TWColor.ink2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background { Capsule().fill(TWColor.glass(0.45)) }
                }
                .buttonStyle(.plain)
            }

            Text(runFail ? "没找到这条快捷指令，先把名字改成「天才威心率」"
                         : "「跑一次」要求快捷指令命名成「天才威心率」")
                .font(.tw(10.5))
                .foregroundStyle(runFail ? TWColor.coral : TWColor.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .twGlass(radius: 18)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("手表同步")
                    .font(.tw(30, .heavy, .rounded))
                    .foregroundStyle(TWColor.ink)
                Text("五步配一次，之后打开 App 自动灌数据")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.tw(13, .bold))
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
                    .font(.tw(15, .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("同步状态")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text(store.watchSyncAt == nil ? "未连通" : "已连通")
                    .font(.tw(11, .bold))
                    .foregroundStyle(store.watchSyncAt == nil ? TWColor.amber : TWColor.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill((store.watchSyncAt == nil ? TWColor.amber : TWColor.mint).opacity(0.13))
                    }
            }

            if let t = store.watchSyncAt {
                Text("上次同步 \(DateFormatter.twDay.string(from: t)) \(DateFormatter.twShort.string(from: t))，累计 \(store.watchSyncCount) 次")
                    .font(.tw(12.5))
                    .foregroundStyle(TWColor.ink2)
            } else {
                Text("还没收到过数据。照下面「五步」走一遍，末了打开一次天才威，这里就会变成「已连通」。")
                    .font(.tw(12.5))
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
                .font(.tw(20, .heavy, .rounded))
                .foregroundStyle(TWColor.ink)
                .monospacedDigit()
            Text("\(title) · \(unit)")
                .font(.tw(10, .semibold))
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
                    .font(.tw(15, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("第一步：点这里")
                    .font(.tw(16.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            Text("点一下会把「5 项模板」放进剪贴板，同时跳到快捷指令。到那边直接粘贴，不用手打。")
                .font(.tw(12.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Button { makeShortcut() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.tw(14, .bold))
                    Text(copied ? "已复制 · 正在跳转" : "复制模板并打开快捷指令")
                        .font(.tw(14.5, .bold))
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
                Image(systemName: "info.circle").font(.tw(10.5))
                Text("iOS 不允许 App 直接写入快捷指令，跳过去粘一下是系统上限，不是偷懒。")
                    .font(.tw(10.5))
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
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("五步，照着屏幕点")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Button { copySteps() } label: {
                    Text(copiedSteps ? "已复制" : "复制全文")
                        .font(.tw(11.5, .bold))
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
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    /// 定时自动化：真正不用手动开 App 的那条路径
    private var autoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.mint)
                Text("改成定时，不用你记着开 App")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            Text("上面五步里的第 2 步用的是「打开天才威时」触发——你得先开 App 它才跑。把触发条件换成时间，就彻底不用管了：")
                .font(.tw(12))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            step(1,
                 "快捷指令 → 自动化 → 右上角 + → 选「特定时间」",
                 "不要选「App」，那是上面已经建过的那条。这里要新建一条用时间触发的。")

            step(2,
                 "时间设 07:00，重复选「每天」，把「运行前询问」关掉 → 下一步",
                 "关掉询问才是真的自动。不关的话每天会弹一个确认框，等于又变成手动。")

            step(3,
                 "动作只加一条：「运行快捷指令」→ 选你第 3 步建好的那条（比如“天才威同步”）→ 完成",
                 "这条自动化不用再写查找健康样本，直接调那条现成的就行。两条共用同一个快捷指令，改一处两边都生效。")

            Text("更准的两种触发：把「特定时间」换成「当闹钟关闭时」，或「当断开充电时」。这两件事你每天都会做，不用等整点。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            Text("会闪一下：最后那条「打开 URL」会把天才威拉到前台。手机锁着的话，解锁那一刻才跳过去，数据不会丢。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            Text("别用「打开 App 时」当触发器配定时：打开 App 又跳回 App，会自己套自己，表现为原地转圈。定时和闹钟都不会。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.amber)
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
                .font(.tw(12.5, .heavy, .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background {
                    Circle().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.tw(11.5))
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
                .font(.tw(13.5, .bold))
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
                .font(.tw(11))
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
                .font(.tw(11.5, .semibold, .monospaced))
                .foregroundStyle(head ? TWColor.purple : TWColor.ink)
                .frame(width: 92, alignment: .leading)
            Text(type)
                .font(.tw(11.5, .medium))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 96, alignment: .leading)
            Text(how)
                .font(.tw(11))
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
                    .font(.tw(13, .bold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Button { copyFull() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedFull ? "checkmark" : "doc.on.doc")
                            .font(.tw(10.5, .bold))
                        Text(copiedFull ? "已复制" : "复制")
                            .font(.tw(11.5, .bold))
                    }
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
                }
                .buttonStyle(.plain)
            }

            Text(template)
                .font(.tw(10.5, .medium, .monospaced))
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
                .font(.tw(11))
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
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("卡住了？对照这几条")
                    .font(.tw(14.5, .bold))
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
                .font(.tw(12, .semibold))
                .foregroundStyle(TWColor.ink)
            Text(a)
                .font(.tw(11.5))
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
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.mintSoft)
                Text("手表沉思 → App 心情")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if store.mindfulAt != nil {
                    Text("已生效")
                        .font(.tw(10.5, .bold))
                        .foregroundStyle(TWColor.mint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(TWColor.mint.opacity(0.13)) }
                }
            }

            Text("手表上做完一次「正念」，健康里会记「正念分钟」。同一条快捷指令加一个「查找健康样本 · 正念」（最新 1 条），URL 结尾补 &mind=[正念分钟]。")
                .font(.tw(12))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("收到 mind 后首页立绘会切「平静」：呼吸变慢、色温转薄荷。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            if let at = store.mindfulAt {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.mint)
                    Text("上次正念 \(store.mindfulMin) 分钟 · \(DateFormatter.twShort.string(from: at))")
                        .font(.tw(11.5, .semibold))
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
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.amber)
                Text("为什么必须绕快捷指令")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("Apple Watch 的数据在系统「健康」里。第三方 App 直连要 HealthKit 权限，这个权限只在付费开发者账号下发；免费签名的 App 一调就 AUTH_FAILED。\n\n快捷指令是系统 App，天生能读健康。让它读出来、拼成链接交给天才威——这条完全免费，也是免费签名下唯一走得通的路。")
                .font(.tw(12))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 动作

    /// 唤起用户已经建好的那条快捷指令。名字必须和引导里写的一致。
    private func runShortcut() {
        let name = "天才威心率"
        guard let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let u = URL(string: "shortcuts://run-shortcut?name=\(enc)") else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIApplication.shared.open(u) { ok in
            if !ok { runFail = true }
        }
    }

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

        ---- 想彻底不用手动开 App，再加一条定时的 ----
        快捷指令 → 自动化 → + → 选「特定时间」
        时间 07:00，重复「每天」，关掉「运行前询问」→ 下一步
        动作只加「运行快捷指令」→ 选上面那条 → 完成
        （也可把触发换成「当闹钟关闭时」/「当断开充电时」，更准时）
        """
        UIPasteboard.general.string = text
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        copiedSteps = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSteps = false }
    }
}

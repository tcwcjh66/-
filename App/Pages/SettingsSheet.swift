import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var showReset = false
    @State private var showCopied = false
    @State private var showGoal = false
    @State private var showStatus = false
    @State private var showManualHealth = false
    @State private var showLog = false
    @State private var exportURL: URL?
    @State private var csvURL: URL?
    @State private var learnCount = FoodLearn.count
    @State private var notifyDenied = false
    @State private var showImporter = false
    @State private var importAlert = false
    @State private var importMsg = ""
    @State private var sideloadText: String = TWSideload.dayText
    @State private var altIcon: String? = nil
    @State private var iconMsg: String = ""
    @State private var showChangelog = false
    @State private var lockOK = TWLock.canUse

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        // 构建号 + commit 前 7 位：手机上装的是哪一版，一眼能对上
        let c = Bundle.main.infoDictionary?["TWCommit"] as? String ?? ""
        return c.isEmpty ? "\(v) · build \(b)" : "\(v) · build \(b) · \(c)"
    }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack {
                        Text("设置")
                            .font(.tw(26, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    overviewCard
                    notifyCard
                    healthCard
                    sideloadCard
                    goalCard
                    gearCard
                    iconCard
                    lockCard
                    dataCard
                    statusCard
                    logCard
                    aboutCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showStatus) {
            SystemStatusSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showGoal) {
            GoalSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showManualHealth) {
            ManualHealthSheet()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showChangelog) {
            ChangeLogSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showLog) {
            LogSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .onAppear {
            exportURL = store.exportJSONFile()
            Task { notifyDenied = await TWNotify.denied() }
        }
        .confirmationDialog("确定清空全部数据？", isPresented: $showReset, titleVisibility: .visible) {
            Button("清空", role: .destructive) { store.resetAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("体重、围度、训练记录、饮食记录、收藏都会删掉，无法恢复。")
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try Data(contentsOf: url)
                    let n = try store.importJSON(data)
                    importMsg = "恢复完成，共找回 \(n) 条记录"
                } catch {
                    importMsg = (error as? LocalizedError)?.errorDescription ?? "这个文件读不了"
                }
                importAlert = true
            case .failure:
                importMsg = "没有选中文件"
                importAlert = true
            }
        }
        .alert("恢复数据", isPresented: $importAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importMsg)
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据概览")
                .font(.tw(15, .bold))
                .foregroundStyle(TWColor.ink)

            HStack(spacing: 0) {
                metric(title: "有记录", value: "\(store.logs.count)", unit: "天", tint: TWColor.blue)
                divider
                metric(title: "训练", value: "\(store.sessions.count)", unit: "次", tint: TWColor.purple)
                divider
                metric(title: "饮食", value: "\(store.meals.count)", unit: "餐", tint: TWColor.mint)
                divider
                metric(title: "收藏", value: "\(store.favoriteMoves.count)", unit: "个", tint: TWColor.coral)
            }
        }
        .padding(16)
        .twGlass()
    }

    private var notifyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("提醒")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if notifyDenied {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("去系统开启")
                            .font(.tw(11.5, .bold))
                            .foregroundStyle(TWColor.coral)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(TWNotify.Kind.allCases) { k in
                HStack(spacing: 11) {
                    Image(systemName: k.icon)
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWNotify.isOn(k) ? TWColor.purple : TWColor.ink3)
                        .frame(width: 32, height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill((TWNotify.isOn(k) ? TWColor.purple : TWColor.ink3).opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.label)
                            .font(.tw(14, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text(k.detail)
                            .font(.tw(11))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: notifyBinding(k))
                        .labelsHidden()
                        .tint(TWColor.purple)
                }
                .padding(.vertical, 3)

                if k != TWNotify.Kind.allCases.last {
                    Rectangle().fill(TWColor.ink3.opacity(0.10)).frame(height: 0.6)
                }
            }

            Text("本地通知，不联网。关了就不会再响。")
                .font(.tw(11))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(16)
        .twGlass()
    }

    private func notifyBinding(_ k: TWNotify.Kind) -> Binding<Bool> {
        Binding(
            get: { TWNotify.isOn(k) },
            set: { on in
                TWNotify.set(k, on)
                if on {
                    Task {
                        let ok = await TWNotify.requestPermission()
                        await MainActor.run {
                            if !ok { notifyDenied = true }
                        }
                    }
                }
                TWNotify.reschedule()
            }
        )
    }

    /// 免费签名没有 HealthKit，健康数据只能手填；这里留一个入口，别让它变成死路
    private var healthCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showManualHealth = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "heart.text.square")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.coral)
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TWColor.coral.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("手动健康数据")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text(healthSummary)
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(10, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(16)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private var healthSummary: String {
        var parts: [String] = []
        if store.manualSleepMin > 0 {
            parts.append(String(format: "睡眠 %.1f h", Double(store.manualSleepMin) / 60))
        }
        if store.manualRestingHR > 0 { parts.append("静息 \(store.manualRestingHR) bpm") }
        if store.manualHRV > 0 { parts.append("HRV \(store.manualHRV) ms") }
        return parts.isEmpty
            ? "免费签名读不到 HealthKit，手填三行就能算恢复度"
            : "已手填：" + parts.joined(separator: " · ")
    }

    private var sideloadCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("免费签名")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
                Text(sideloadText)
                    .font(.tw(11, .bold))
                    .foregroundStyle(TWSideload.daysLeft <= 2 ? TWColor.coral : TWColor.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background {
                        Capsule().fill((TWSideload.daysLeft <= 2 ? TWColor.coral : TWColor.mint).opacity(0.12))
                    }
            }
            Text("7 天到期要重签一次。第 5 天会推一条提醒；重装前先在下面「数据」里导出一份 JSON 双保险。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                let t = TWSideload.reset()
                TWNotify.scheduleExpiry(installAt: t)
                sideloadText = TWSideload.dayText
            } label: {
                Text("我刚重装过，重新计时")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(TWColor.purple.opacity(0.12)) }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }

    // MARK: - 器械

    /// 只勾手上有或能用的，计划编辑和换动作就只从这些里出
    private var gearCard: some View {
        let gears = ["哑铃", "杠铃", "器械", "自重", "弹力带"]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "dumbbell.fill")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("我有什么器械")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(store.ownedGear.count)/\(gears.count)")
                    .font(.tw(11, .semibold))
                    .foregroundStyle(TWColor.ink3)
            }
            Text("计划编辑与换动作只从勾选的器械里挑；至少留一项。")
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(gears, id: \.self) { g in
                    let on = store.ownedGear.contains(g)
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        if on {
                            if store.ownedGear.count > 1 { store.ownedGear.remove(g) }
                        } else {
                            store.ownedGear.insert(g)
                        }
                        store.persist()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .font(.tw(11, .semibold))
                                .foregroundStyle(on ? TWColor.mint : TWColor.ink3)
                            Text(g)
                                .font(.tw(12.5, .semibold))
                                .foregroundStyle(on ? TWColor.ink : TWColor.ink3)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(TWColor.glass(on ? 0.6 : 0.3))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    // MARK: - 图标

    /// 应用锁：Face ID / 设备密码，挡的是界面不是数据
    private var lockCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.violet)
                Text("隐私")
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if !lockOK {
                    GlassPill(text: "设备不支持", tint: TWColor.amber)
                }
            }

            Toggle(isOn: Binding(
                get: { store.lockEnabled },
                set: { on in
                    store.lockEnabled = on
                    store.persistSoon()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("打开 App 要验证")
                        .font(.tw(13.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text("切到后台就上锁，回来用 Face ID 或设备密码解锁")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .tint(TWColor.violet)
            .disabled(!lockOK)

            Text(lockOK ? "只挡界面，数据还是只在本机；忘了密码可以去系统设置里关掉。" : "这台设备没设 Face ID 也没设密码，先去系统设置里加一个再来开。")
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .twGlass()
    }

    /// 距离上次导出多久，超过 14 天变琥珀色
    private var backupLine: String {
        guard let days = store.backupDays else { return "还没导出过 · 重装会丢，先存一份" }
        if days <= 0 { return "上次导出：今天" }
        return "上次导出：\(days) 天前" + (store.backupStale ? " · 该存一份了" : "")
    }

    private var iconCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "app.dashed")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("桌面图标")
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                if let altIcon {
                    Text(altIcon == "AppIcon-Mono" ? "单色线" : "默认")
                        .font(.tw(10.5, .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            Text("换图标不用重装，桌面立刻变。")
                .font(.tw(10.5))
                .foregroundStyle(TWColor.ink3)

            HStack(spacing: 10) {
                iconOption(nil, "疾速 P", "原色渐变")
                iconOption("AppIcon-Mono", "单色线", "白字深底")
            }

            if !iconMsg.isEmpty {
                Text(iconMsg)
                    .font(.tw(10))
                    .foregroundStyle(TWColor.coral)
            }
        }
        .padding(16)
        .twGlass()
        .onAppear { altIcon = UIApplication.shared.alternateIconName }
    }

    private func iconOption(_ name: String?, _ title: String, _ sub: String) -> some View {
        let on = altIcon == name
        return Button {
            guard UIApplication.shared.supportsAlternateIcons else {
                iconMsg = "这台设备的系统版本不支持换图标"
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIApplication.shared.setAlternateIconName(name) { err in
                DispatchQueue.main.async {
                    if let err {
                        iconMsg = "换失败：\(err.localizedDescription)"
                    } else {
                        iconMsg = ""
                        altIcon = name
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(on ? TWColor.purple.opacity(0.18) : TWColor.glass(0.35))
                    .frame(height: 58)
                    .overlay {
                        Image(systemName: on ? "checkmark.seal.fill" : "app.fill")
                            .font(.tw(20, .semibold))
                            .foregroundStyle(on ? TWColor.purple : TWColor.ink3)
                    }
                Text(title)
                    .font(.tw(11.5, on ? .bold : .medium))
                    .foregroundStyle(TWColor.ink)
                Text(sub)
                    .font(.tw(9.5))
                    .foregroundStyle(TWColor.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(TWColor.glass(on ? 0.6 : 0.3))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(on ? TWColor.purple.opacity(0.5) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var goalCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showGoal = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "target")
                    .font(.tw(15, .semibold))
                    .foregroundStyle(TWColor.purple)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TWColor.purple.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("目标设置")
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text("\(Int(store.dietTarget)) kcal · 蛋白 \(Int(store.proteinGoal)) g · 水 \(store.waterTarget) 杯")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(11, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .twGlass()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据")
                .font(.tw(15, .bold))
                .foregroundStyle(TWColor.ink)

            ShareLink(item: exportURL ?? FileManager.default.temporaryDirectory,
                      subject: Text("Persist数据备份")) {
                HStack(spacing: 11) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.blue)
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(TWColor.blue.opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出全部数据")
                            .font(.tw(14.5, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("JSON 文件 · 存到「文件」或发给自己")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.tw(11, .bold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .buttonStyle(.plain)

            Text(backupLine)
                .font(.tw(11))
                .foregroundStyle(store.backupStale ? TWColor.amber : TWColor.ink3)
                .padding(.leading, 45)

            Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(height: 0.7)

            HStack(spacing: 11) {
                Image(systemName: "sparkles")
                    .font(.tw(15, .semibold))
                    .foregroundStyle(TWColor.amber)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TWColor.amber.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("识别学习")
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text(learnCount == 0
                         ? "认过并确认的包装词会记在这里，下次直接命中"
                         : "已记住 \(learnCount) 个包装词，认得越来越准")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                if learnCount > 0 {
                    Button("清空") {
                        FoodLearn.forgetAll()
                        learnCount = 0
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
                    .buttonStyle(.plain)
                }
            }

            if let csvURL {
                ShareLink(item: csvURL, subject: Text("Persist数据 CSV")) {
                    HStack(spacing: 11) {
                        Image(systemName: "tablecells")
                            .font(.tw(15, .semibold))
                            .foregroundStyle(TWColor.mint)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(TWColor.mint.opacity(0.12))
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("导出 CSV 表格")
                                .font(.tw(14.5, .semibold))
                                .foregroundStyle(TWColor.ink)
                            Text("训练 / 饮食 / 体重 / 围度 · Excel 直接打开")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.tw(11, .bold))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    csvURL = store.exportCSVFile()
                } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "tablecells")
                            .font(.tw(15, .semibold))
                            .foregroundStyle(TWColor.mint)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(TWColor.mint.opacity(0.12))
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("导出 CSV 表格")
                                .font(.tw(14.5, .semibold))
                                .foregroundStyle(TWColor.ink)
                            Text("点一下生成，再点分享给电脑")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.tw(11, .bold))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
                .buttonStyle(.plain)
            }

            Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(height: 0.7)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showImporter = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.mint)
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(TWColor.mint.opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("从备份恢复")
                            .font(.tw(14.5, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("选之前导出的 JSON，把历史捡回来")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.tw(11, .bold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .buttonStyle(.plain)

            Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(height: 0.7)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showReset = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "trash")
                        .font(.tw(15, .semibold))
                        .foregroundStyle(TWColor.coral)
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(TWColor.coral.opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空全部数据")
                            .font(.tw(14.5, .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("删除本机所有记录，不可恢复")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .twGlass()
    }

    private var statusCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showStatus = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "stethoscope")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.mint)
                    .frame(width: 28, height: 28)
                    .background { Circle().fill(TWColor.mint.opacity(0.14)) }
                VStack(alignment: .leading, spacing: 2) {
                    Text("运行状态")
                        .font(.tw(13.5, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text("备份份数 · 数据体积 · 手表同步 · 剩余天数")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(11, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
            .twGlass(radius: 18)
        }
        .buttonStyle(.plain)
    }

    /// 最近发生过什么：识别耗时、备份失败、数据迁移，都在这里
    private var logCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showLog = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.tw(14, .semibold))
                    .foregroundStyle(TWColor.blue)
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TWColor.blue.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("诊断日志")
                        .font(.tw(14, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text(TWLog.recent.isEmpty ? "还没有记录，出了问题再来这儿看" : "最近 \(TWLog.recent.count) 条 · 点开可复制")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.tw(10, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(16)
            .twGlass()
        }
        .buttonStyle(.plain)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("关于")
                .font(.tw(15, .bold))
                .foregroundStyle(TWColor.ink)

            infoRow("版本", versionText)
            infoRow("签名方式", "免费 Apple ID 侧载")
            infoRow("数据存储", "只在本机，不上传")
            infoRow("动作库", "\(allMoves.count) 个 · 方案 \(planTemplates.count) 套")
            infoRow("心率来源", "指尖 PPG / 手动 / 快捷指令回传")

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showChangelog = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.tw(11, .bold))
                    Text("这一版改了什么")
                        .font(.tw(12, .bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.tw(10, .bold))
                }
                .foregroundStyle(TWColor.blue)
            }
            .buttonStyle(.plain)

            Text("所有身体数据来自 iPhone 自身传感器或你手动输入，不含模拟数据。手表数据需要 HealthKit 授权，免费签名下不可用。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .twGlass()
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.16))
            .frame(width: 0.8, height: 28)
    }

    private func metric(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.tw(10.5, .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.tw(18, .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.tw(12.5, .medium))
                .foregroundStyle(TWColor.ink3)
            Spacer()
            Text(value)
                .font(.tw(12.5, .semibold))
                .foregroundStyle(TWColor.ink2)
                .multilineTextAlignment(.trailing)
        }
    }
}

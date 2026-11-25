import SwiftUI
import UIKit

// MARK: - AI 对话主界面
struct AIChatSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    /// 从识食物带进来的开场上下文，例如「刚识别到：白米饭 150g、鸡胸肉 120g」
    var seed: String? = nil

    @State private var msgs: [AIMsg] = []
    @State private var input = ""
    @State private var busy = false
    @State private var errText: String?
    @State private var showSetup = false
    @State private var didSeed = false
    @FocusState private var focused: Bool

    private let quickAsks = [
        "今天还能吃多少",
        "蛋白还差多少",
        "这顿怎么搭",
        "今晚该怎么补"
    ]

    private var client: AIClient { AIClient.shared }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                grabber
                header
                if !client.ready { notReadyBar }
                transcript
                if msgs.count <= 2 { quickRow }
                composer
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear(perform: bootstrap)
        .sheet(isPresented: $showSetup) {
            AISetupSheet().environmentObject(store)
        }
    }

    // MARK: 顶部
    private var grabber: some View {
        Capsule()
            .fill(TWColor.ink3.opacity(0.4))
            .frame(width: 34, height: 4)
            .padding(.top, 8)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.mintSoft],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 34, height: 34)
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 教练")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)
                Text(client.ready ? "\(client.provider.label) · \(client.model)" : "本地模式 · 未接大模型")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showSetup = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(TWColor.glass(0.5)))
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink2)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(TWColor.glass(0.5)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var notReadyBar: some View {
        Button {
            showSetup = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("没填 API Key，现在走本地规则引擎")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(TWColor.ink)
                    Text("填入 Key 后换成真大模型，回答更灵活")
                        .font(.system(size: 11))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Text("接入")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(TWColor.purple)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TWColor.glass(0.55))
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: 对话区
    private var transcript: some View {
        ScrollViewReader { sp in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(msgs) { m in
                        bubble(m).id(m.id)
                    }
                    if busy { typingRow.id("typing") }
                    if let e = errText { errRow(e) }
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: msgs.count) { _, _ in
                scrollToBottom(sp)
            }
            .onChange(of: busy) { _, _ in
                scrollToBottom(sp)
            }
        }
    }

    private func scrollToBottom(_ sp: ScrollViewProxy) {
        let target: AnyHashable? = busy ? AnyHashable("typing") : msgs.last.map { AnyHashable($0.id) }
        guard let target else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.25)) {
                sp.scrollTo(target, anchor: .bottom)
            }
        }
    }

    private func bubble(_ m: AIMsg) -> some View {
        HStack(alignment: .top, spacing: 0) {
            if m.role == "user" { Spacer(minLength: 46) }
            if m.role != "user" {
                ZStack {
                    Circle()
                        .fill(TWColor.glass(0.75))
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TWColor.purple)
                }
                .padding(.trailing, 7)
            }
            Text(m.text)
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(m.role == "user" ? .white : TWColor.ink)
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(m.role == "user"
                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(TWColor.glass(0.62)))
                }
            if m.role != "user" { Spacer(minLength: 26) }
        }
    }

    private var typingRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(TWColor.ink3)
                    .frame(width: 6, height: 6)
                    .opacity(0.55)
                    .scaleEffect(1.0)
                    .animation(
                        .easeInOut(duration: 0.55).repeatForever().delay(Double(i) * 0.16),
                        value: busy
                    )
            }
            Text("正在想…")
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
            Spacer(minLength: 0)
        }
        .padding(.leading, 35)
    }

    private func errRow(_ s: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(TWColor.coral)
            Text(s)
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.coral)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(TWColor.coral.opacity(0.1))
        }
    }

    // MARK: 快捷提问
    private var quickRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(quickAsks, id: \.self) { q in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        send(q)
                    } label: {
                        Text(q)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(TWColor.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(TWColor.glass(0.6))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
        }
        .padding(.bottom, 8)
    }

    // MARK: 输入
    private var composer: some View {
        HStack(spacing: 8) {
            TextField("问教练点什么…", text: $input, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(TWColor.ink)
                .lineLimit(1...4)
                .focused($focused)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TWColor.glass(0.7))
                }
                .submitLabel(.send)
                .onSubmit { send(input) }

            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background {
                        Circle().fill(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy
                                      ? AnyShapeStyle(TWColor.ink3.opacity(0.45))
                                      : AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                     startPoint: .top, endPoint: .bottom)))
                    }
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || busy)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .background {
            Rectangle()
                .fill(TWColor.glass(0.28))
                .blur(radius: 12)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: 逻辑
    private func bootstrap() {
        guard !didSeed else { return }
        didSeed = true
        let hello = localHello()
        msgs.append(AIMsg(role: "assistant", text: hello))
        if let s = seed, !s.isEmpty {
            msgs.append(AIMsg(role: "user", text: s))
            if client.ready {
                dispatch([AIMsg(role: "system", text: store.aiSystemPrompt)] + msgs)
            } else {
                msgs.append(AIMsg(role: "assistant", text: localReply(s)))
            }
        }
    }

    private func localHello() -> String {
        var t = "我是你的教练。"
        let left = max(0, Int(store.dietTarget - store.dietKcal))
        t += "今天还剩 \(left) kcal 额度"
        let pl = max(0, Int(proteinNeed - store.protein))
        if pl > 0 { t += "，蛋白差 \(pl)g" } else { t += "，蛋白够了 👍" }
        t += "。想聊哪块？吃喝、训练、睡觉都能问。"
        if !client.ready {
            t += "\n（现在走本地规则，接了 Key 会答得更灵活）"
        }
        return t
    }

    private var proteinNeed: Double {
        max(0, store.bodyWeight > 0 ? store.bodyWeight * 1.6 : 120)
    }

    private func send(_ raw: String) {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !busy else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        msgs.append(AIMsg(role: "user", text: t))
        input = ""
        errText = nil
        focused = false
        busy = true

        if client.ready {
            dispatch([AIMsg(role: "system", text: store.aiSystemPrompt)] + msgs)
        } else {
            let ans = localReply(t)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                msgs.append(AIMsg(role: "assistant", text: ans))
                busy = false
            }
        }
    }

    private func dispatch(_ payload: [AIMsg]) {
        Task {
            do {
                let ans = try await client.chat(payload)
                await MainActor.run {
                    msgs.append(AIMsg(role: "assistant", text: ans))
                    busy = false
                }
            } catch {
                await MainActor.run {
                    errText = error.localizedDescription
                    // 失败时用本地引擎兜底，保证一定有回答
                    let last = msgs.last(where: { $0.role == "user" })?.text ?? ""
                    msgs.append(AIMsg(role: "assistant", text: localReply(last)))
                    busy = false
                }
            }
        }
    }

    // MARK: 本地规则引擎（无 Key 也能答）
    private func localReply(_ q: String) -> String {
        let s = q.lowercased()
        let left = Int(max(0, store.dietTarget - store.dietKcal))
        let pl = Int(max(0, proteinNeed - store.protein))

        if s.contains("蛋白") || s.contains("protein") {
            if pl <= 0 { return "今天蛋白已经够了（\(Int(store.protein))g），别再堆蛋白了，把剩下的热量留给碳水和蔬菜。" }
            var t = "还差 \(pl)g 蛋白。按 100g 算：鸡胸肉 \(Int(Double(pl) / 19.4 * 100))g，或鸡蛋 \(Int(Double(pl) / 13.3 * 100))g，或三文鱼 \(Int(Double(pl) / 20.0 * 100))g。"
            t += "分两顿吃吸收更好，一顿 30g 左右上限。"
            return t
        }
        if s.contains("热量") || s.contains("卡路里") || s.contains("还能吃") || s.contains("kcal") || s.contains("吃多少") {
            return "今天还有 \(left) kcal。按常见搭配：一碗米饭 200 kcal + 鸡胸 150g 约 200 kcal + 一份青菜 60 kcal ≈ 460 kcal，还能加个蛋。"
        }
        if s.contains("水") || s.contains("喝") {
            let rest = max(0, store.waterTargetML - store.waterML)
            let cupsLeft = Int(ceil(Double(rest) / Double(max(1, store.cupSize))))
            return "今天喝了 \(store.waterML) ml，还差 \(rest) ml。按你设的每杯 \(store.cupSize) ml，大概 \(cupsLeft) 杯。"
        }
        if s.contains("睡") || s.contains("补觉") || s.contains("困") {
            if let last = store.lastSleep {
                return "昨晚睡了 \(last.durationMinutes / 60) 小时 \(last.durationMinutes % 60) 分，评分 \(last.score)。近 7 天欠 \(store.sleepDebt) 分钟，今晚建议 \(store.sleepTonightMin / 60) 小时 \(store.sleepTonightMin % 60) 分，\(store.sleepBedtimeText) 上床。"
            }
            return "还没测过睡眠。睡前把手机放桌上、点开睡眠监测，第二天就有报告了。"
        }
        if s.contains("练") || s.contains("训练") || s.contains("动作") {
            let done = store.sessionSets
            return done > 0
                ? "今天已经做了 \(done) 组。补一句：多关节动作放前面，孤立放后面；组间 90 秒，别刷手机拖成 3 分钟。"
                : "今天还没开练。时间紧就做 3 个动作：深蹲 3×8、俯卧撑 3×12、平板 3×45 秒，20 分钟能收工。"
        }
        if s.contains("体重") || s.contains("减") || s.contains("肥") || s.contains("bmi") {
            if store.bodyWeight > 0 {
                let g = store.weightGoal > 0 ? "目标 \(String(format: "%.1f", store.weightGoal)) kg" : "还没设目标"
                return "体重 \(String(format: "%.1f", store.bodyWeight)) kg，BMI \(String(format: "%.1f", store.bmi))，\(g)。减脂期每天热量缺口控制在 300–500 kcal，一周掉 0.3–0.5 kg 最稳。"
            }
            return "还没填体重。去身体页补一下，才能算 BMI 和热量目标。"
        }
        if s.contains("吃") || s.contains("饭") || s.contains("餐") {
            return "当前 \(Int(store.dietKcal)) kcal，剩 \(left) kcal。优先补蛋白和蔬菜，碳水放训练前后。"
        }
        return "这个我按你今天的数答：\(left) kcal 额度、蛋白差 \(pl)g、水差 \(max(0, store.waterTargetML - store.waterML)) ml。想问具体哪一项？说「蛋白」「热量」「水」「睡眠」「训练」都行。"
    }
}

// MARK: - AI 接入设置
struct AISetupSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var provider: AIProvider = .deepseek
    @State private var key = ""
    @State private var url = ""
    @State private var model = ""
    @State private var probing = false
    @State private var probeMsg: String?
    @State private var probeOK = false

    private var client: AIClient { AIClient.shared }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("接入 AI")
                                .font(.system(size: 20, weight: .heavy))
                                .foregroundStyle(TWColor.ink)
                            Spacer(minLength: 0)
                            Button("关闭") { dismiss() }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TWColor.ink2)
                        }

                        Text("填自己的 Key，按量付费由服务商直接扣。不填也能用，走本地规则引擎。")
                            .font(.system(size: 12))
                            .foregroundStyle(TWColor.ink3)
                            .fixedSize(horizontal: false, vertical: true)

                        providerCard
                        keyCard
                        probeCard
                        saveBtn
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            provider = client.provider
            key = client.apiKey
            url = client.baseURLRaw
            model = client.modelRaw
            probeMsg = client.lastProbeNote.isEmpty ? nil : client.lastProbeNote
            probeOK = false
        }
    }

    private var providerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("服务商")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TWColor.ink)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(AIProvider.allCases) { p in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) {
                            provider = p
                            url = ""
                            model = ""
                            probeMsg = nil
                        }
                    } label: {
                        Text(p.label)
                            .font(.system(size: 12.5, weight: provider == p ? .bold : .medium))
                            .foregroundStyle(provider == p ? .white : TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(provider == p
                                          ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                          : AnyShapeStyle(TWColor.glass(0.55)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(provider.hint)
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
            Text(provider.pricing)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(TWColor.mint)
        }
        .padding(15)
        .twGlass()
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("密钥")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TWColor.ink)

            SecureField("sk-...", text: $key)
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(TWColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TWColor.glass(0.62))
                }

            HStack(spacing: 8) {
                Text("接口地址")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                TextField(provider.baseURL.isEmpty ? "https://..." : provider.baseURL, text: $url)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(TWColor.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TWColor.glass(0.5))
                    }
            }

            HStack(spacing: 8) {
                Text("模型名")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                TextField(provider.model.isEmpty ? "model" : provider.model, text: $model)
                    .font(.system(size: 12, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(TWColor.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TWColor.glass(0.5))
                    }
            }

            Text("留空就用该服务商的默认地址和模型。Key 只存在本机，不上传。")
                .font(.system(size: 11))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(15)
        .twGlass()
    }

    private var probeCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Button {
                    probe()
                } label: {
                    HStack(spacing: 6) {
                        if probing {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(probing ? "测试中…" : "测试连通")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundStyle(TWColor.purple)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background {
                        Capsule().fill(TWColor.glass(0.62))
                    }
                }
                .buttonStyle(.plain)
                .disabled(probing)

                Spacer(minLength: 0)

                if let m = probeMsg {
                    HStack(spacing: 4) {
                        Image(systemName: probeOK ? "checkmark.circle.fill" : "info.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(m)
                            .font(.system(size: 10.5, weight: .semibold))
                            .lineLimit(2)
                    }
                    .foregroundStyle(probeOK ? TWColor.mint : TWColor.ink3)
                }
            }
        }
        .padding(15)
        .twGlass()
    }

    private var saveBtn: some View {
        Button {
            client.provider = provider
            client.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            client.baseURLRaw = url.trimmingCharacters(in: .whitespacesAndNewlines)
            client.modelRaw = model.trimmingCharacters(in: .whitespacesAndNewlines)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func probe() {
        probing = true
        probeMsg = nil
        let tmp = AIClient.shared
        tmp.provider = provider
        tmp.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        tmp.baseURLRaw = url.trimmingCharacters(in: .whitespacesAndNewlines)
        tmp.modelRaw = model.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let r = try await tmp.chat([
                    AIMsg(role: "system", text: "你是连通性测试机器人，只回答两个字：正常"),
                    AIMsg(role: "user", text: "在吗")
                ])
                await MainActor.run {
                    probing = false
                    probeOK = true
                    probeMsg = "连通 · " + String(r.prefix(12))
                    client.lastProbeNote = probeMsg ?? ""
                }
            } catch {
                await MainActor.run {
                    probing = false
                    probeOK = false
                    probeMsg = error.localizedDescription
                    client.lastProbeNote = probeMsg ?? ""
                }
            }
        }
    }
}

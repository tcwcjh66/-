import SwiftUI

/// 第一次打开的三页引导：这是什么 → 要给哪些权限 → 填两个数就能开始。
struct OnboardingView: View {
    @EnvironmentObject var store: TWStore
    var onFinish: () -> Void

    @State private var page = 0
    @State private var askingSteps = false
    @State private var askingNotify = false
    @State private var weightText = ""
    @State private var heightText = ""

    private var weightValue: Double? { Double(weightText) }
    private var heightValue: Double? { Double(heightText) }

    /// 引导页的粗算：20 岁、男、一般活动量
    private var roughMaintain: Int? {
        guard let w = weightValue, let h = heightValue, w > 20, h > 100 else { return nil }
        return Int((10 * w + 6.25 * h - 100 + 5) * 1.55)
    }

    var body: some View {
        ZStack {
            AuroraBG()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcome.tag(0)
                    permits.tag(1)
                    basics.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
    }

    // MARK: - 页 1

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 30)

            Text("Persist")
                .font(.tw(44, .black))
                .foregroundStyle(TWColor.ink)

            Text("自己记、自己算、不联网也不上传。\n步数、心率、饮食、训练、睡眠都在这一台手机里。")
                .font(.tw(16, .medium))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                bullet("figure.walk", "步数实时读运动协处理器，不用手动填")
                bullet("camera.fill", "心率用手指按摄像头测，不靠手环")
                bullet("fork.knife", "400 条食物库离线可查，条码一扫就是厂商数据")
                bullet("dumbbell.fill", "练一组记一组，下次自动告诉你该加多少")
            }
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.tw(14, .bold))
                .foregroundStyle(TWColor.purple)
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(TWColor.purple.opacity(0.12))
                }
            Text(text)
                .font(.tw(13.5))
                .foregroundStyle(TWColor.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 页 2

    private var permits: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 20)

            Text("先给两个权限")
                .font(.tw(30, .black))
                .foregroundStyle(TWColor.ink)

            Text("这两个都不联网，只在手机本地用。不给也能用，只是数字要自己填。")
                .font(.tw(14))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            permitRow(
                "figure.walk",
                "运动与健身",
                "读步数、距离、爬楼层。iOS 会弹一次「允许」。",
                state: askingSteps ? "已请求" : "点右边申请",
                tint: TWColor.mint
            ) {
                askingSteps = true
                StepLive.shared.bind(store)
                StepLive.shared.start()
            }

            permitRow(
                "bell.badge.fill",
                "通知",
                "组间休息到点、喝水、称重提醒。锁屏也能响。",
                state: askingNotify ? "已请求" : "点右边申请",
                tint: TWColor.amber
            ) {
                askingNotify = true
                Task { await TWNotify.requestPermission() }
            }

            Text("手表数据不在这里——免费签名拿不到 HealthKit，得走「身体 → 手表同步」配一次快捷指令。装好后按那页的五步做。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
    }

    private func permitRow(_ icon: String, _ title: String, _ detail: String,
                           state: String, tint: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.tw(16, .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
                Text(detail)
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            Button(action: action) {
                Text(state)
                    .font(.tw(11.5, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background { Capsule().fill(tint) }
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .twGlass(radius: 16)
    }

    // MARK: - 页 3

    private var basics: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 20)

            Text("两个数，算热量")
                .font(.tw(30, .black))
                .foregroundStyle(TWColor.ink)

            Text("填了体重和身高，饮食页的目标热量会按 Mifflin-St Jeor 算出来，不再是一个凭空的 2200。")
                .font(.tw(14))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                numberBox("体重", unit: "kg", text: $weightText)
                numberBox("身高", unit: "cm", text: $heightText)
            }

            if let est = roughMaintain {
                Text("按 20 岁、男、一般活动量粗算：维持 \(est) kcal 上下。年龄和性别可以进「目标」页再改。")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.mint)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("不填也能进，之后在「身体」页补上。")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
            }

            Spacer()

            Text("接下来：今天页点「开始记录」记一餐，训练页选一套方案就能练。")
                .font(.tw(12))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 10)
    }

    private func numberBox(_ title: String, unit: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.tw(11, .medium))
                .foregroundStyle(TWColor.ink3)
            HStack(spacing: 5) {
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.tw(22, .heavy))
                    .foregroundStyle(TWColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(unit)
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .padding(14)
        .twGlass(radius: 16)
    }

    // MARK: - 底部

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(page == i ? TWColor.purple : TWColor.ink3.opacity(0.25))
                        .frame(width: page == i ? 20 : 7, height: 7)
                        .animation(.snappy(duration: 0.22), value: page)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 26)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if page < 2 {
                    withAnimation(.snappy(duration: 0.28)) { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < 2 ? "下一步" : "开始用")
                    .font(.tw(16, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)

            if page < 2 {
                Button {
                    finish()
                } label: {
                    Text("跳过，直接用")
                        .font(.tw(12.5, .medium))
                        .foregroundStyle(TWColor.ink3)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(height: 16)
            }
        }
        .padding(.bottom, 26)
    }

    private func finish() {
        if let w = weightValue, w > 20, w < 300 {
            store.bodyWeight = w
            store.logWeight(w)
        }
        if let h = heightValue, h > 100, h < 250 {
            store.heightCM = h
        }
        store.persist()
        onFinish()
    }
}

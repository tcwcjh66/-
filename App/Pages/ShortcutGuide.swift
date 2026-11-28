import SwiftUI
import UIKit

/// 只同步心率的极简版：两步，配示意图。
/// 图是照着快捷指令真实界面画的，文字和选项跟系统一致，位置不保证一模一样。
struct ShortcutGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private let urlPrefix = "twfit://hr?bpm="

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    stepOne
                    stepTwo
                    checkCard
                    voiceCard
                    whyCard
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, 34)
            }
        }
    }

    // MARK: - 头

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("两步，只要心率")
                        .font(.tw(26, .heavy, .rounded))
                        .foregroundStyle(TWColor.ink)
                    Text("比原来的五步少一半，60 秒能建完")
                        .font(.tw(12.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.tw(13, .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 34, height: 34)
                        .background { Circle().fill(TWColor.glass(0.5)) }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 第一步

    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHead(1, "加「查找健康样本」", "搜这个名字，加一个动作")

            mockAction(
                icon: "heart.fill",
                tint: TWColor.coral,
                title: "查找健康样本",
                rows: [("类型", "心率"), ("排序方式", "最近"), ("限制", "1")]
            )

            hint("三个值都在同一个动作里改，改完不用再动。限制填 1 是只要最新那一条，别让它把一整天的都拉出来。")
        }
        .padding(16)
        .twGlass(radius: 20)
    }

    // MARK: - 第二步

    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHead(2, "加「打开 URL」", "地址里插一个变量")

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "link")
                        .font(.tw(12, .bold))
                        .foregroundStyle(TWColor.blue)
                        .frame(width: 24, height: 24)
                        .background { RoundedRectangle(cornerRadius: 7).fill(TWColor.blue.opacity(0.14)) }
                    Text("打开 URL")
                        .font(.tw(13.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    Text(urlPrefix)
                        .font(.tw(12))
                        .foregroundStyle(TWColor.ink2)
                    Text("心率")
                        .font(.tw(11.5, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(TWColor.purple) }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 10).fill(TWColor.glass(0.4))
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TWColor.glass(0.5))
            }

            hint("先手打 twfit://hr?bpm= ，然后把光标停在这行末尾，点键盘上方的「变量」，选第一步那个查找动作的「值」——它就变成右边那个紫色胶囊。")
            hint("建完把这条改名成「Persist心率」，以后在手表同步页点「跑一次」就不用再进来。")

            Button { copyPrefix() } label: {
                HStack(spacing: 7) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.tw(12, .bold))
                    Text(copied ? "已复制，去粘贴" : "复制 twfit://hr?bpm=")
                        .font(.tw(13.5, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    Capsule().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                  startPoint: .leading, endPoint: .trailing))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .twGlass(radius: 20)
    }

    // MARK: - 自检

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.tw(13))
                    .foregroundStyle(TWColor.mint)
                Text("建完怎么验")
                    .font(.tw(14.5, .bold))
                    .foregroundStyle(TWColor.ink)
            }
            checkLine(1, "先给这条快捷指令改名成「Persist心率」——回 App 点「跑一次」就靠这个名字找它")
            checkLine(2, "回到Persist，看首页「心率」那一格")
            checkLine(3, "数字变成了你刚才的心率，就成了；还是 — 就回来看第二步的变量插没插对")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    /// 3.64 之后新加的 Siri 口令，全都列出来，省得靠猜
    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Siri 直接说这些")
                .font(.tw(13.5, .bold))
                .foregroundStyle(TWColor.ink)
            voiceLine("记一杯水", "「嘿 Siri，给 Persist 记一杯水」")
            voiceLine("记体重", "「用 Persist 记体重」，会追问公斤数")
            voiceLine("记一组", "「给 Persist 记一组」，会追问重量和次数")
            voiceLine("开始训练", "「用 Persist 开始训练」，按今天的计划直接开")
            voiceLine("今天练什么", "「Persist 今天练什么」，不开 App 就能听")
            voiceLine("训练进度", "「Persist 这周练了几次」，读今天几组、这周几次")
            voiceLine("换动作", "「用 Persist 换个动作」，说肌群或器械就切过去")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    private func voiceLine(_ title: String, _ phrase: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "waveform")
                .font(.tw(11, .bold))
                .foregroundStyle(TWColor.purple)
                .frame(width: 18, height: 18)
                .background { Circle().fill(TWColor.purple.opacity(0.14)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tw(12.5, .semibold))
                    .foregroundStyle(TWColor.ink)
                Text(phrase)
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("为什么只有心率")
                .font(.tw(13.5, .bold))
                .foregroundStyle(TWColor.ink)
            Text("免费签名拿不到 HealthKit 权限，App 自己读不了手表。快捷指令是系统 App，它能读，把值拼进链接再交回来——这一步绕不开苹果。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("步数不用管，App 自己用 CoreMotion 拿，已经是实时的。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    // MARK: - 零件

    private func stepHead(_ n: Int, _ title: String, _ sub: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.tw(13, .heavy, .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tw(15, .bold))
                    .foregroundStyle(TWColor.ink)
                Text(sub)
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
        }
    }

    private func mockAction(icon: String, tint: Color, title: String,
                            rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.tw(12, .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background { RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.14)) }
                Text(title)
                    .font(.tw(13.5, .semibold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { item in
                HStack(spacing: 8) {
                    Text(item.element.0)
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                    Spacer(minLength: 0)
                    Text(item.element.1)
                        .font(.tw(11.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background { Capsule().fill(TWColor.glass(0.45)) }
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TWColor.glass(0.5))
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.tw(11.5))
            .foregroundStyle(TWColor.ink3)
            .lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func checkLine(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.tw(10, .bold))
                .foregroundStyle(TWColor.mint)
                .frame(width: 16, height: 16)
                .background { Circle().fill(TWColor.mint.opacity(0.16)) }
            Text(text)
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func copyPrefix() {
        UIPasteboard.general.string = urlPrefix
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.snappy(duration: 0.2)) { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) { copied = false }
        }
    }
}

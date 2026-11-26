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
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(TWColor.ink)
                    Text("比原来的五步少一半，60 秒能建完")
                        .font(.system(size: 12.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TWColor.blue)
                        .frame(width: 24, height: 24)
                        .background { RoundedRectangle(cornerRadius: 7).fill(TWColor.blue.opacity(0.14)) }
                    Text("打开 URL")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink)
                    Spacer(minLength: 0)
                }

                HStack(spacing: 0) {
                    Text(urlPrefix)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(TWColor.ink2)
                    Text("心率")
                        .font(.system(size: 11.5, weight: .bold))
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

            Button { copyPrefix() } label: {
                HStack(spacing: 7) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .bold))
                    Text(copied ? "已复制，去粘贴" : "复制 twfit://hr?bpm=")
                        .font(.system(size: 13.5, weight: .bold))
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
                    .font(.system(size: 13))
                    .foregroundStyle(TWColor.mint)
                Text("建完怎么验")
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(TWColor.ink)
            }
            checkLine(1, "在快捷指令里点一下这条，让它跑完")
            checkLine(2, "回到天才威，看首页「心率」那一格")
            checkLine(3, "数字变成了你刚才的心率，就成了；还是 — 就回来看第二步的变量插没插对")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass(radius: 20)
    }

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("为什么只有心率")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(TWColor.ink)
            Text("免费签名拿不到 HealthKit 权限，App 自己读不了手表。快捷指令是系统 App，它能读，把值拼进链接再交回来——这一步绕不开苹果。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("步数不用管，App 自己用 CoreMotion 拿，已经是实时的。")
                .font(.system(size: 11.5))
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
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Text(sub)
                    .font(.system(size: 11.5))
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background { RoundedRectangle(cornerRadius: 7).fill(tint.opacity(0.14)) }
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { item in
                HStack(spacing: 8) {
                    Text(item.element.0)
                        .font(.system(size: 11.5))
                        .foregroundStyle(TWColor.ink3)
                    Spacer(minLength: 0)
                    Text(item.element.1)
                        .font(.system(size: 11.5, weight: .semibold))
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
            .font(.system(size: 11.5))
            .foregroundStyle(TWColor.ink3)
            .lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func checkLine(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TWColor.mint)
                .frame(width: 16, height: 16)
                .background { Circle().fill(TWColor.mint.opacity(0.16)) }
            Text(text)
                .font(.system(size: 11.5))
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

import SwiftUI
import UIKit
import PhotosUI

/// 门禁卡号记录页。
/// 说清楚一件事：iPhone 不能把门禁卡复制进手机，iOS 不给 App 模拟卡片 UID 的权限。
/// 真正管用的是卡号——物业录入系统只认这个号，所以这页做的是读号、存号、生成申请话术。
struct AccessCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var box = AccessCardStore.shared

    @State private var pick: PhotosPickerItem?
    @State private var reading = false
    @State private var guesses: [String] = []
    @State private var code = ""
    @State private var alias = ""
    @State private var note = ""
    @State private var toast = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    limitCard
                    readCard
                    inputCard
                    if !box.cards.isEmpty { listCard }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background { AuroraBG() }
            .navigationTitle("门禁卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onChange(of: pick) { _, v in readPick(v) }
    }

    // MARK: - 说清楚边界

    private var limitCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.tw(13, .bold))
                    .foregroundStyle(TWColor.amber)
                Text("iPhone 当不了门禁卡")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text("iOS 不开放卡片模拟，安卓能复制门禁卡，苹果不行。Apple 钱包的门禁钥匙只对合作物业开放，个人做不了。")
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(3)
            Text("这页干的是另一件事：把卡号记下来，拿着它去找物业录入——他们只认卡号。")
                .font(.tw(11.5, .semibold))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.amber.opacity(0.10))
        }
    }

    // MARK: - 拍卡面读号

    private var readCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("拍卡面，自动读卡号")
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink)

            PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 7) {
                    Image(systemName: reading ? "hourglass" : "camera.fill")
                        .font(.tw(13, .bold))
                    Text(reading ? "正在读…" : "选一张卡面照片")
                        .font(.tw(13.5, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.blue, TWColor.purple],
                                             startPoint: .leading, endPoint: .trailing))
                }
            }
            .buttonStyle(.plain)

            if !guesses.isEmpty {
                Text("读到的号码，点一个填进去")
                    .font(.tw(11, .semibold))
                    .foregroundStyle(TWColor.ink3)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(guesses, id: \.self) { g in
                            Button {
                                code = g
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            } label: {
                                Text(g)
                                    .font(.tw(12.5, .semibold))
                                    .foregroundStyle(code == g ? .white : TWColor.purple)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background {
                                        Capsule().fill(code == g
                                                       ? AnyShapeStyle(TWColor.purple)
                                                       : AnyShapeStyle(TWColor.purple.opacity(0.10)))
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.45))
        }
    }

    // MARK: - 手动录入

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("或者直接填")
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink)

            field("卡号", text: $code, hint: "8–16 位数字")
            field("叫什么", text: $alias, hint: "家 / 公司 / 宿舍")
            field("备注", text: $note, hint: "可留空")

            Button {
                guard box.add(code: code, alias: alias, note: note) else {
                    toast = "卡号太短或已经记过了"
                    return
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                code = ""
                alias = ""
                note = ""
                guesses = []
                toast = "已记下这张卡"
            } label: {
                Text("存下来")
                    .font(.tw(14, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
            }
            .buttonStyle(.plain)

            if !toast.isEmpty {
                Text(toast)
                    .font(.tw(11.5, .semibold))
                    .foregroundStyle(TWColor.mint)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.45))
        }
    }

    private func field(_ title: String, text: Binding<String>, hint: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.tw(11.5, .semibold))
                .foregroundStyle(TWColor.ink3)
                .frame(width: 46, alignment: .leading)
            TextField(hint, text: text)
                .font(.tw(13))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(TWColor.glass(0.55))
        }
    }

    // MARK: - 已记下的卡

    private var listCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("记下的卡")
                    .font(.tw(13, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(box.cards.count) 张")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
            }

            ForEach(box.cards) { c in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text(c.alias)
                            .font(.tw(13.5, .bold))
                            .foregroundStyle(TWColor.ink)
                        Spacer(minLength: 0)
                        Button {
                            UIPasteboard.general.string = c.code
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            toast = "卡号已复制"
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.purple)
                        }
                        .buttonStyle(.plain)

                        Button {
                            UIPasteboard.general.string = box.requestText(c)
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            toast = "申请话术已复制，直接发物业"
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.mint)
                        }
                        .buttonStyle(.plain)

                        Button {
                            box.remove(c.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink3)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(c.code)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(TWColor.ink2)
                    if !c.note.isEmpty {
                        Text(c.note)
                            .font(.tw(11))
                            .foregroundStyle(TWColor.ink3)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TWColor.glass(0.4))
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TWColor.glass(0.45))
        }
    }

    // MARK: - 读图

    private func readPick(_ item: PhotosPickerItem?) {
        guard let item else { return }
        reading = true
        Task {
            var found: [String] = []
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                found = await Task.detached(priority: .userInitiated) {
                    CardOCR.codes(in: img)
                }.value
            }
            await MainActor.run {
                reading = false
                guesses = Array(found.prefix(5))
                if let first = guesses.first { code = first }
                toast = guesses.isEmpty ? "没读出号码，拍清楚点再试" : "读到 \(guesses.count) 个候选"
            }
        }
    }
}

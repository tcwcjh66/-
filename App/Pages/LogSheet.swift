import SwiftUI
import UIKit

/// 设置里的「诊断日志」：最近 300 条事件，能看能复制。
/// 识别变慢、备份失败、数据读不出来，都在这儿留了痕。
struct LogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = TWLog.text
    @State private var copied = false

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("诊断日志")
                            .font(.tw(22, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Text("最近 \(TWLog.recent.count) 条 · 只存在本机")
                            .font(.tw(11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 8)
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.tw(12, .bold))
                            .foregroundStyle(TWColor.ink2)
                            .frame(width: 32, height: 32)
                            .background { Circle().fill(TWColor.glass(0.6)) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView {
                    Text(text)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(TWColor.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(TWColor.glass(0.4))
                        }
                        .padding(.horizontal, 18)
                }

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = text
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    } label: {
                        Text(copied ? "已复制" : "复制全部")
                            .font(.tw(14, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        TWLog.clear()
                        text = TWLog.text
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } label: {
                        Text("清空")
                            .font(.tw(14, .bold))
                            .foregroundStyle(TWColor.coral)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(TWColor.coral.opacity(0.12))
                            }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }
}

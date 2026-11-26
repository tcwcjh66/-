import SwiftUI

/// 训练中替换动作：先给这个动作自带的「常见替代」，再给同肌群的其它动作。
/// 器械被占了、杠铃排队，点一下就能换，不用退出去查。
struct SwapMoveSheet: View {
    let current: String
    var onPick: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var cur: MoveItem? { allMoves.first { $0.name == current } }

    /// MoveItem.alt 是「哑铃卧推 / 器械推胸」这种写法，拆开用
    private var altNames: [String] {
        guard let c = cur, !c.alt.isEmpty else { return [] }
        return c.alt
            .split(whereSeparator: { "/／、，,".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != current }
    }

    private var sameGroup: [MoveItem] {
        guard let c = cur else { return [] }
        return allMoves.filter { $0.group == c.group && $0.name != current }
    }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("换一个动作")
                                .font(.tw(21, .heavy))
                                .foregroundStyle(TWColor.ink)
                            Text("现在练的是「\(current)」")
                                .font(.tw(12.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer(minLength: 0)
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.55)) }
                        }
                        .buttonStyle(.plain)
                    }

                    if !altNames.isEmpty {
                        head("常见替代 · 换器械最方便")
                        ForEach(altNames, id: \.self) { n in
                            let m = allMoves.first { $0.name == n }
                            row(name: n,
                                detail: m.map { "\($0.group) · \($0.equipment) · \($0.level)" } ?? "同部位替代",
                                tag: m == nil ? "替代" : "推荐",
                                tint: TWColor.mint)
                        }
                    }

                    if !sameGroup.isEmpty {
                        head("同肌群 · \(cur?.group ?? "")")
                        ForEach(sameGroup) { m in
                            row(name: m.name,
                                detail: "\(m.equipment) · \(m.level)",
                                tag: m.equipment,
                                tint: TWColor.blue)
                        }
                    }

                    if altNames.isEmpty && sameGroup.isEmpty {
                        Text("这个动作没有登记替代，去动作库翻翻同部位的动作。")
                            .font(.tw(13))
                            .foregroundStyle(TWColor.ink3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("换掉只影响这次训练，不动你的计划模板。下次还是原来的动作。")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationCornerRadius(28)
        .presentationDragIndicator(.hidden)
    }

    private func head(_ t: String) -> some View {
        Text(t)
            .font(.tw(12, .bold))
            .foregroundStyle(TWColor.ink3)
            .padding(.top, 4)
    }

    private func row(name: String, detail: String, tag: String, tint: Color) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            onPick(name)
            dismiss()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.tw(12, .bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(tint.opacity(0.13))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.tw(14.5, .semibold))
                        .foregroundStyle(TWColor.ink)
                        .lineLimit(1)
                    Text(detail)
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(tag)
                    .font(.tw(10, .bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background { Capsule().fill(tint.opacity(0.12)) }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TWColor.glass(0.46))
            }
        }
        .buttonStyle(.plain)
    }
}

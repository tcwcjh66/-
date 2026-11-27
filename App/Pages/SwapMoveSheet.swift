import SwiftUI

/// 训练中替换动作：先给这个动作自带的「常见替代」，再给同肌群的其它动作。
/// 器械被占了、杠铃排队，点一下就能换，不用退出去查。
struct SwapMoveSheet: View {
    let current: String
    var onPick: (String) -> Void
    /// 为什么换：器械被占、动作疼、还是今天想轻一点。不同原因该推的动作不一样。
    @State private var reason: String = ""
    @EnvironmentObject var store: TWStore
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
        return store.availableMoves.filter { $0.group == c.group && $0.name != current }
    }

    /// 器械被占时最有用的就是「换个器械也能练同一块肌肉」
    private var diffEquip: [MoveItem] {
        guard let c = cur else { return [] }
        return sameGroup.filter { $0.equipment != c.equipment }
    }

    /// 同器械的，用来换角度、换握距、加练
    private var sameEquip: [MoveItem] {
        guard let c = cur else { return [] }
        return sameGroup.filter { $0.equipment == c.equipment }
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

                    reasonRow

                    if reason == "疼" {
                        head("同部位 · 先避开会疼的器械")
                        if safeEquip.isEmpty {
                            Text("这个部位没登记低风险替代。先减重量、缩短幅度，疼就停。")
                                .font(.tw(12.5))
                                .foregroundStyle(TWColor.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(safeEquip) { m in
                                row(name: m.name,
                                    detail: "\(m.equipment) · \(m.level) · 不吃关节",
                                    tag: "低风险",
                                    tint: TWColor.blue)
                            }
                        }
                    } else if reason == "轻一点" {
                        head("同部位 · 轻一点的版本")
                        if lighter.isEmpty {
                            Text("这个部位没有更轻的动作，把重量降 20% 做同样的动作就行。")
                                .font(.tw(12.5))
                                .foregroundStyle(TWColor.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(lighter) { m in
                                row(name: m.name,
                                    detail: "\(m.equipment) · \(m.level)",
                                    tag: "更轻",
                                    tint: TWColor.mint)
                            }
                        }
                    } else {
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

                        if !diffEquip.isEmpty {
                            head("器械被占？换器械照样练 \(cur?.group ?? "")")
                            ForEach(diffEquip) { m in
                                row(name: m.name,
                                    detail: "\(m.equipment) · \(m.level)",
                                    tag: "换器械",
                                    tint: TWColor.mint)
                            }
                        }

                        if !sameEquip.isEmpty {
                            head("同器械 · 换角度或加练")
                            ForEach(sameEquip) { m in
                                row(name: m.name,
                                    detail: "\(m.equipment) · \(m.level)",
                                    tag: m.equipment,
                                    tint: TWColor.blue)
                            }
                        }
                    }

                    if altNames.isEmpty && diffEquip.isEmpty && sameEquip.isEmpty {
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

    /// 原因筛选：三种真实场景，选完只留该看的那批
    private var reasonRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("为什么换")
                .font(.tw(11.5, .bold))
                .foregroundStyle(TWColor.ink3)
            HStack(spacing: 7) {
                ForEach(["器械被占", "这个动作疼", "轻一点"], id: \.self) { r in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.2)) { reason = (reason == r ? "" : r) }
                    } label: {
                        Text(r)
                            .font(.tw(11.5, .bold))
                            .foregroundStyle(reason == r ? .white : TWColor.ink2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                Capsule().fill(reason == r
                                               ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                              startPoint: .top, endPoint: .bottom))
                                               : AnyShapeStyle(TWColor.glass(0.5)))
                            }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// 关节不友好的器械先剔掉：杠铃、哑铃都靠负重压，疼的时候换器械或自重
    private var safeEquip: [MoveItem] {
        guard let c = cur else { return [] }
        return allMoves.filter {
            $0.group == c.group && $0.name != current
                && ["器械", "自重", "绳索", "弹力带"].contains($0.equipment)
        }
    }

    /// 想轻一点就给新手/初级动作，别再推大重量
    private var lighter: [MoveItem] {
        guard let c = cur else { return [] }
        return allMoves.filter {
            $0.group == c.group && $0.name != current
                && ["新手", "初级", "初中级"].contains($0.level)
        }
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

import SwiftUI
import UIKit

struct LibPage: View {
    @State private var group: String = "全部"
    @State private var query: String = ""
    @State private var detail: MoveItem?

    private let groups = ["全部", "胸", "背", "腿", "肩", "手臂", "核心"]

    private var filtered: [MoveItem] {
        demoMoves.filter { m in
            (group == "全部" || m.group == group) &&
            (query.isEmpty || m.name.contains(query))
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(title: "动作库", subtitle: "按肌群筛选 · 点开看要点")

            searchBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups, id: \.self) { g in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy(duration: 0.22)) { group = g }
                        } label: {
                            Text(g)
                                .font(.system(size: 14, weight: group == g ? .bold : .medium))
                                .foregroundStyle(group == g ? .white : TWColor.ink2)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(group == g
                                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                              : AnyShapeStyle(Color.white.opacity(0.60)))
                                }
                                .contentShape(Capsule(style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            VStack(spacing: 10) {
                ForEach(filtered) { m in
                    moveRow(m)
                }
            }

            if filtered.isEmpty {
                Text("没有匹配的动作")
                    .font(.system(size: 14))
                    .foregroundStyle(TWColor.ink3)
                    .padding(.top, 40)
            }
        }
        .sheet(item: $detail) { m in
            MoveDetailSheet(move: m)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(28)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField("搜索动作", text: $query)
                .font(.system(size: 15, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .twGlass(radius: 16, shadow: false)
    }

    private func moveRow(_ m: MoveItem) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            detail = m
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(colors: [TWColor.purple.opacity(0.22), TWColor.violet.opacity(0.10)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(TWColor.purple)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(m.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(TWColor.ink)
                    Text("\(m.group) · \(m.equipment)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TWColor.ink3)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(m.pr)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TWColor.ink2)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .twGlass(radius: 17, shadow: false)
            .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MoveDetailSheet: View {
    let move: MoveItem
    @Environment(\.dismiss) private var dismiss

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

                    Text(move.name)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(TWColor.ink)

                    HStack(spacing: 8) {
                        GlassPill(text: move.group, tint: TWColor.purple)
                        GlassPill(text: move.equipment, tint: TWColor.blue)
                        GlassPill(text: "当前 \(move.pr)", tint: TWColor.mint)
                    }

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: [TWColor.purple.opacity(0.16), TWColor.blue.opacity(0.08)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 150)
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundStyle(TWColor.purple.opacity(0.75))
                                Text("演示位")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TWColor.ink3)
                            }
                        }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("动作要点")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(TWColor.ink)
                        Text(move.cue)
                            .font(.system(size: 14))
                            .foregroundStyle(TWColor.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .twGlass()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("建议组次")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(TWColor.ink)
                        ForEach(["增肌：4 组 × 8–12 次，休 90 秒",
                                 "减脂：3 组 × 12–15 次，休 60 秒",
                                 "热身：2 组 × 20 次，用一半重量"], id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(TWColor.purple.opacity(0.55))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(line)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(TWColor.ink2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .twGlass()

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
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
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 18)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

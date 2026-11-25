import SwiftUI
import UIKit

struct LibPage: View {
    @State private var group: String = "全部"
    @State private var query: String = ""

    private let groups = ["全部", "胸", "背", "腿", "肩", "手臂", "核心"]

    private var filtered: [MoveItem] {
        demoMoves.filter { m in
            (group == "全部" || m.group == group) &&
            (query.isEmpty || m.name.contains(query))
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(title: "动作库", subtitle: "按肌群筛选 · 双击看教程")

            searchBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(groups, id: \.self) { g in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy(duration: 0.22)) { group = g }
                        } label: {
                            Text(g)
                                .font(.system(size: 12, weight: group == g ? .bold : .medium, design: .rounded))
                                .foregroundStyle(group == g ? .white : TWColor.ink2)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(group == g
                                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                              : AnyShapeStyle(Color.white.opacity(0.52)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }

            VStack(spacing: 9) {
                ForEach(filtered) { m in
                    moveRow(m)
                }
            }

            if filtered.isEmpty {
                Text("没有匹配的动作")
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.ink3)
                    .padding(.top, 30)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField("搜索动作", text: $query)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .twGlass(radius: 15, shadow: false)
    }

    private func moveRow(_ m: MoveItem) -> some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(
                    LinearGradient(colors: [TWColor.purple.opacity(0.20), TWColor.violet.opacity(0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(TWColor.purple)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(m.name)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                Text("\(m.group) · \(m.equipment)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(TWColor.ink3)
            }

            Spacer(minLength: 0)

            Text(m.pr)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(TWColor.ink2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(Color.white.opacity(0.55))
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .twGlass(radius: 16, shadow: false)
    }
}

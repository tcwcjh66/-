import SwiftUI
import UIKit

struct LibPage: View {
    @EnvironmentObject var store: TWStore
    @State private var group: String = "全部"
    @State private var query: String = ""
    @State private var detail: MoveItem?

    private let groups = ["全部", "收藏", "胸", "背", "腿", "肩", "手臂", "核心"]

    private var filtered: [MoveItem] {
        let base = allMoves.filter { m in
            if group == "收藏" {
                guard store.favoriteMoves.contains(m.name) else { return false }
            } else if group != "全部" {
                guard m.group == group else { return false }
            }
            guard !query.isEmpty else { return true }
            return m.name.contains(query) || m.equipment.contains(query) || m.group.contains(query)
        }
        let fav = base.filter { store.favoriteMoves.contains($0.name) }
        let rest = base.filter { !store.favoriteMoves.contains($0.name) }
        return fav + rest
    }

    var body: some View {
        VStack(spacing: 14) {
            PageHeader(title: "动作库", subtitle: "\(allMoves.count) 个动作 · 收藏 \(store.favoriteMoves.count)")

            searchBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(groups, id: \.self) { g in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy(duration: 0.22)) { group = g }
                        } label: {
                            Text(g)
                                .font(.tw(14, group == g ? .bold : .medium))
                                .foregroundStyle(group == g ? .white : TWColor.ink2)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 9)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(group == g
                                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                              : AnyShapeStyle(TWColor.glass(0.60)))
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
                Text(group == "收藏" ? "还没有收藏的动作，点右侧的心形" : "没有匹配的动作")
                    .font(.tw(14))
                    .foregroundStyle(TWColor.ink3)
                    .padding(.top, 40)
            }
        }
        .sheet(item: $detail) { m in
            MoveDetailSheet(move: m)
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.tw(15, .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField("搜索动作、器械或肌群", text: $query)
                .font(.tw(15, .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.tw(15))
                        .foregroundStyle(TWColor.ink3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .twGlass(radius: 16, shadow: false)
    }

    private func moveRow(_ m: MoveItem) -> some View {
        let fav = store.favoriteMoves.contains(m.name)
        return HStack(spacing: 11) {
            MoveFigure(name: m.name, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(m.name)
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
                    .lineLimit(1)
                Text("\(m.group) · \(m.equipment) · \(m.level)")
                    .font(.tw(12.5, .medium))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(store.prs[m.name] ?? "未记录")
                .font(.tw(11.5, store.prs[m.name] == nil ? .medium : .semibold))
                .foregroundStyle(store.prs[m.name] == nil ? TWColor.ink3 : TWColor.ink2)
                .lineLimit(1)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.snappy(duration: 0.2)) { store.toggleFav(m.name) }
            } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .font(.tw(18, .semibold))
                    .foregroundStyle(fav ? TWColor.pink : TWColor.ink3.opacity(0.55))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .twGlass(radius: 17, shadow: false)
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            detail = m
        }
    }

    private func iconFor(_ g: String) -> String {
        switch g {
        case "胸": return "figure.strengthtraining.traditional"
        case "背": return "figure.rower"
        case "腿": return "figure.run"
        case "肩": return "figure.dance"
        case "手臂": return "figure.boxing"
        case "核心": return "figure.core.training"
        default: return "figure.mixed.cardio"
        }
    }
}

struct MoveDetailSheet: View {
    let move: MoveItem
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var showPR = false

    private var fav: Bool {
        store.favoriteMoves.contains(move.name)
    }

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

                    HStack(alignment: .top, spacing: 12) {
                        Text(move.name)
                            .font(.tw(27, .heavy))
                            .foregroundStyle(TWColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) { store.toggleFav(move.name) }
                        } label: {
                            Image(systemName: fav ? "heart.fill" : "heart")
                                .font(.tw(22, .semibold))
                                .foregroundStyle(fav ? TWColor.pink : TWColor.ink3)
                                .frame(width: 42, height: 42)
                                .background {
                                    Circle().fill(TWColor.glass(0.55))
                                }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        GlassPill(text: move.group, tint: TWColor.purple)
                        GlassPill(text: move.equipment, tint: TWColor.blue)
                        GlassPill(text: move.level, tint: TWColor.amber)
                    }

                    HStack(spacing: 11) {
                        Image(systemName: "trophy.fill")
                            .font(.tw(15, .semibold))
                            .foregroundStyle(TWColor.amber)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(TWColor.amber.opacity(0.12))
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("我的最好成绩")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink)
                            Text(store.prs[move.name] ?? "还没记录")
                                .font(.tw(12))
                                .foregroundStyle(store.prs[move.name] == nil ? TWColor.ink3 : TWColor.ink2)
                        }

                        Spacer(minLength: 0)

                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            showPR = true
                        } label: {
                            Text(store.prs[move.name] == nil ? "记录" : "更新")
                                .font(.tw(12.5, .bold))
                                .foregroundStyle(TWColor.amber)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule().fill(TWColor.amber.opacity(0.13))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .twGlass()

                    StrengthCurveCard(points: store.e1rmPoints(move: move.name))

                    videoBlock

                    cardBlock(title: "动作要点", body: move.cue, tint: TWColor.mint, icon: "checkmark.seal.fill")

                    if !move.error.isEmpty {
                        cardBlock(title: "常见错误", body: move.error, tint: TWColor.amber, icon: "exclamationmark.triangle.fill")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("建议组次")
                            .font(.tw(17, .bold))
                            .foregroundStyle(TWColor.ink)
                        ForEach(["增肌：4 组 × 8–12 次，组间休 90 秒",
                                 "力量：5 组 × 3–5 次，组间休 3 分钟",
                                 "减脂：3 组 × 15–20 次，组间休 45 秒",
                                 "热身：2 组 × 20 次，用一半重量"], id: \.self) { line in
                            HStack(alignment: .top, spacing: 8) {
                                Circle().fill(TWColor.purple.opacity(0.55))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 7)
                                Text(line)
                                    .font(.tw(14))
                                    .foregroundStyle(TWColor.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .twGlass()

                    if !move.alt.isEmpty {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.tw(15, .semibold))
                                .foregroundStyle(TWColor.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("替代动作")
                                    .font(.tw(15, .bold))
                                    .foregroundStyle(TWColor.ink)
                                Text(move.alt)
                                    .font(.tw(14))
                                    .foregroundStyle(TWColor.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .twGlass()
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
                            .font(.tw(16, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 26)
                }
                .padding(.horizontal, 18)
            }
        }
        .sheet(isPresented: $showPR) {
            PRSheet(moveName: move.name,
                    current: store.prs[move.name]) { weight, reps in
                store.setPR(move.name, weight: weight, reps: reps)
            }
            .presentationDetents([.height(330)])
            .presentationCornerRadius(26)
        }
    }

    private var videoBlock: some View {
        Button {
            let target = move.video.isEmpty ? moveSearchURL(move.name) : move.video
            if let url = URL(string: target) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [TWColor.purple.opacity(0.20), TWColor.blue.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.tw(19, .bold))
                            .foregroundStyle(TWColor.purple)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text(move.video.isEmpty ? "看教学视频" : "看精讲视频")
                        .font(.tw(16, .bold))
                        .foregroundStyle(TWColor.ink)
                    Text(move.video.isEmpty ? "在抖音搜这个动作的标准示范" : "已收录专业教学，点开直接看")
                        .font(.tw(12.5, .medium))
                        .foregroundStyle(TWColor.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
            .twGlass()
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func cardBlock(title: String, body: String, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.tw(14, .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.tw(16, .bold))
                    .foregroundStyle(TWColor.ink)
            }
            Text(body)
                .font(.tw(14.5))
                .foregroundStyle(TWColor.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .twGlass()
    }
}

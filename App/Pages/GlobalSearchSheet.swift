import SwiftUI

/// 一个框搜三样东西：食物、动作、过去的训练。
/// 之前找个「上次卧推多少」要翻月份，这个页面就是为这一下。
struct GlobalSearchSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var q = ""
    @FocusState private var focused: Bool

    private var key: String {
        q.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var foods: [LocalFood] {
        key.isEmpty ? [] : Array(FoodBase.search(key, limit: 6))
    }

    private var moves: [MoveItem] {
        guard !key.isEmpty else { return [] }
        return Array(allMoves.filter {
            $0.name.contains(key) || $0.group.contains(key) || $0.equipment.contains(key)
        }.prefix(6))
    }

    private var logs: [SessionLog] {
        guard !key.isEmpty else { return [] }
        return Array(store.sessions.filter {
            $0.plan.contains(key) || $0.day.contains(key)
            || ($0.moveNames ?? []).contains { $0.contains(key) }
        }.suffix(8).reversed())
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.tw(13, .semibold))
                            .foregroundStyle(TWColor.ink3)
                        TextField("食物、动作、训练记录", text: $q)
                            .font(.tw(14))
                            .focused($focused)
                            .submitLabel(.search)
                        if !q.isEmpty {
                            Button {
                                q = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.tw(13))
                                    .foregroundStyle(TWColor.ink3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(TWColor.glass(0.6)) }

                    Button("关闭") { dismiss() }
                        .font(.tw(13, .semibold))
                        .foregroundStyle(TWColor.ink2)
                }
                .padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if key.isEmpty {
                            Text("试试「鸡胸」「卧推」「5×5」——食物给热量，动作给要领，记录给当时的重量。")
                                .font(.tw(12))
                                .foregroundStyle(TWColor.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        } else {
                            if foods.isEmpty && moves.isEmpty && logs.isEmpty {
                                Text("没找到。换个说法，或者只输入两个字。")
                                    .font(.tw(12))
                                    .foregroundStyle(TWColor.ink3)
                            }

                            if !foods.isEmpty {
                                section("食物", "fork.knife", TWColor.mint) {
                                    ForEach(foods) { f in
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(f.name).font(.tw(13, .semibold)).foregroundStyle(TWColor.ink)
                                                Text("\(f.group) · 每份 \(Int(f.portion))g").font(.tw(10.5)).foregroundStyle(TWColor.ink3)
                                            }
                                            Spacer(minLength: 0)
                                            Text("\(Int(f.kcal)) kcal")
                                                .font(.tw(11, .semibold))
                                                .foregroundStyle(TWColor.ink2)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                            }

                            if !moves.isEmpty {
                                section("动作", "figure.strengthtraining.traditional", TWColor.blue) {
                                    ForEach(moves) { m in
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(m.name).font(.tw(13, .semibold)).foregroundStyle(TWColor.ink)
                                                Text(m.group).font(.tw(10)).foregroundStyle(TWColor.ink3)
                                                Spacer(minLength: 0)
                                                Text(m.pr).font(.tw(10.5, .semibold)).foregroundStyle(TWColor.mint)
                                            }
                                            Text(m.cue)
                                                .font(.tw(10.5))
                                                .foregroundStyle(TWColor.ink3)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                            }

                            if !logs.isEmpty {
                                section("训练记录", "clock.arrow.circlepath", TWColor.purple) {
                                    ForEach(logs) { s in
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(s.date) · \(s.plan)").font(.tw(12.5, .semibold)).foregroundStyle(TWColor.ink)
                                                Text(s.day).font(.tw(10.5)).foregroundStyle(TWColor.ink3)
                                            }
                                            Spacer(minLength: 0)
                                            Text("\(s.sets) 组 · \(s.minutes) 分")
                                                .font(.tw(11))
                                                .foregroundStyle(TWColor.ink2)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, 18)
        }
        .onAppear { focused = true }
    }

    private func section<C: View>(_ title: String, _ icon: String, _ tint: Color,
                                  @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.tw(12, .semibold)).foregroundStyle(tint)
                Text(title).font(.tw(13, .bold)).foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background { RoundedRectangle(cornerRadius: 14, style: .continuous).fill(TWColor.glass(0.45)) }
        }
    }
}

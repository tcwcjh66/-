import SwiftUI
import UIKit

/// 自建训练方案：动作、组数、次数、重量、每个动作的休息秒数，全部自己排。
struct PlanEditorSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = CustomPlan()
    @State private var editIndex: Int?
    @State private var loaded = false
    @State private var showMovePicker = false
    @State private var pickerDay = 0

    init(editIndex: Int? = nil) {
        _editIndex = State(initialValue: editIndex)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("方案") {
                    TextField("方案名，例如「宿舍哑铃 4 天」", text: $draft.name)
                    TextField("频率，例如「每周 4 次」", text: $draft.cycle)
                }

                ForEach(Array(draft.days.indices), id: \.self) { di in
                    Section {
                        TextField("这天的名字，例如「推日」", text: $draft.days[di].title)

                        ForEach(Array(draft.days[di].sets.indices), id: \.self) { si in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(draft.days[di].sets[si].name.isEmpty ? "未命名动作" : draft.days[di].sets[si].name)
                                        .font(.tw(15, .semibold))
                                    Spacer()
                                    Button {
                                        draft.days[di].sets[si].name = ""
                                    } label: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.tw(12))
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(TWColor.purple)
                                }

                                HStack(spacing: 14) {
                                    Stepper("组数 \(draft.days[di].sets[si].sets)",
                                            value: $draft.days[di].sets[si].sets, in: 1...12)
                                        .font(.tw(13))
                                }

                                HStack(spacing: 12) {
                                    TextField("次数", text: $draft.days[di].sets[si].reps)
                                        .frame(width: 56)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("重量", text: $draft.days[di].sets[si].weight)
                                        .frame(width: 78)
                                        .textFieldStyle(.roundedBorder)
                                    Stepper("休息 \(draft.days[di].sets[si].restSec)s",
                                            value: $draft.days[di].sets[si].restSec, in: 10...300, step: 5)
                                        .font(.tw(12))
                                }
                            }
                            .padding(.vertical, 3)
                        }
                        .onDelete { idx in
                            draft.days[di].sets.remove(atOffsets: idx)
                        }

                        Button {
                            pickerDay = di
                            showMovePicker = true
                        } label: {
                            Label("从动作库挑一个", systemImage: "plus.circle.fill")
                                .font(.tw(14, .semibold))
                        }
                    } header: {
                        Text("第 \(di + 1) 天")
                    }
                }
                .onDelete { idx in
                    if draft.days.count > 1 { draft.days.remove(atOffsets: idx) }
                }

                Section {
                    Button {
                        draft.days.append(CustomDay(title: "第 \(draft.days.count + 1) 天"))
                    } label: {
                        Label("加一天", systemImage: "calendar.badge.plus")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        if let i = editIndex, i >= 0, i < store.customPlans.count {
                            store.customPlans.remove(at: i)
                            store.persist()
                        }
                        dismiss()
                    } label: {
                        Label("删除这个方案", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(editIndex == nil ? "新建方案" : "编辑方案")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let i = editIndex, i >= 0, i < store.customPlans.count {
                    draft = store.customPlans[i]
                }
            }
            .sheet(isPresented: $showMovePicker) {
                MovePickerSheet { name in
                    let item = CustomSet(name: name, sets: 3, reps: "10", weight: "", restSec: 45)
                    if pickerDay < draft.days.count {
                        draft.days[pickerDay].sets.append(item)
                    }
                    showMovePicker = false
                }
            }
        }
    }

    private func save() {
        var clean = draft
        clean.name = clean.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.name.isEmpty { clean.name = "我的方案" }
        clean.days = clean.days.map { d in
            var dd = d
            if dd.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                dd.title = "训练日"
            }
            dd.sets = dd.sets.filter { !$0.name.isEmpty }
            return dd
        }

        if let i = editIndex, i >= 0, i < store.customPlans.count {
            store.customPlans[i] = clean
        } else {
            store.customPlans.append(clean)
            store.planPick = planTemplates.count + store.customPlans.count - 1
            store.dayPick = 0
        }
        store.persist()
        dismiss()
    }
}

/// 从 88 个动作里挑一个，可按部位筛
struct MovePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    var onPick: (String) -> Void

    private var groups: [String] {
        Array(Set(allMoves.map { $0.group })).sorted()
    }

    private var filtered: [MoveItem] {
        guard !q.isEmpty else { return allMoves }
        return allMoves.filter { $0.name.contains(q) || $0.group.contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(Set(filtered.map { $0.group })).sorted(), id: \.self) { g in
                    Section(g) {
                        ForEach(filtered.filter { $0.group == g }, id: \.name) { m in
                            Button {
                                onPick(m.name)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.name)
                                            .font(.tw(15, .semibold))
                                        Text(m.equipment)
                                            .font(.tw(11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus")
                                        .foregroundStyle(TWColor.purple)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $q, prompt: "搜动作或部位")
            .navigationTitle("动作库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

/// 组间休息的全局覆盖设置
struct RestSettingSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double = 0

    private let presets = [0, 30, 45, 60, 90, 120]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("组间休息")
                    .font(.tw(26, .heavy, .rounded))

                Text(value == 0
                     ? "跟随动作自带：每个方案里写多少秒就歇多少秒。"
                     : "统一 \(Int(value)) 秒：不管方案里写多少，每组做完都歇这么久。")
                    .font(.tw(13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { p in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy) { value = Double(p) }
                        } label: {
                            Text(p == 0 ? "跟随" : "\(p)s")
                                .font(.tw(13.5, .bold))
                                .foregroundStyle(value == Double(p) ? .white : TWColor.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    Capsule().fill(value == Double(p)
                                                   ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                                  startPoint: .leading, endPoint: .trailing))
                                                   : AnyShapeStyle(TWColor.purple.opacity(0.12)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Slider(value: $value, in: 0...180, step: 5)
                    .tint(TWColor.purple)

                Text("\(Int(value)) 秒")
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink3)

                Spacer()

                Button {
                    store.restOverride = Int(value)
                    store.persist()
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.purple, TWColor.blue],
                                                     startPoint: .leading, endPoint: .trailing))
                        }
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { value = Double(store.restOverride) }
        }
    }
}

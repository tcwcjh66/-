import UIKit
import SwiftUI

/// 补录：那天没带手机、或者忘了记，回来补上。
/// 只记「动作 + 组数 × 重量 × 次数」，够进曲线和统计了。
struct BackfillSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var q = ""
    @State private var move = ""
    @State private var sets = 3
    @State private var weight = "60"
    @State private var reps = 8
    @State private var saved = false

    private var candidates: [MoveItem] {
        let key = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        return Array(allMoves.filter {
            $0.name.contains(key) || $0.group.contains(key)
        }.prefix(6))
    }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("补录一次训练")
                            .font(.tw(22, .heavy, .rounded))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 32, height: 32)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        rowLabel("哪天")
                        DatePicker("", selection: $date, in: Date().addingTimeInterval(-60 * 86400)...Date(),
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(TWColor.mint)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        rowLabel("练了什么")
                        TextField("搜动作，也可以自己打", text: $q)
                            .font(.tw(13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(TWColor.glass(0.5)) }

                        ForEach(candidates) { m in
                            Button {
                                move = m.name
                                q = m.name
                            } label: {
                                HStack(spacing: 8) {
                                    Text(m.name).font(.tw(12.5, .semibold)).foregroundStyle(TWColor.ink)
                                    Text(m.group).font(.tw(10)).foregroundStyle(TWColor.ink3)
                                    Spacer(minLength: 0)
                                    Text(m.pr).font(.tw(10)).foregroundStyle(TWColor.mint)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }

                        if !move.isEmpty {
                            GlassPill(text: move, tint: TWColor.mint)
                        }
                    }

                    HStack(spacing: 12) {
                        stepper("组数", value: $sets, range: 1...12, unit: "组")
                        stepper("次数", value: $reps, range: 1...40, unit: "次")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        rowLabel("重量 kg")
                        TextField("0 表示自重", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.tw(15, .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(TWColor.glass(0.5)) }
                    }

                    Button {
                        let key = DateFormatter.twDay.string(from: date)
                        let w = Double(weight) ?? 0
                        store.addBackfill(date: key, move: move.isEmpty ? q : move,
                                          sets: sets, weight: w, reps: reps)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        saved = true
                        dismiss()
                    } label: {
                        Text(saved ? "已保存" : "存进训练记录")
                            .font(.tw(14, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.mint, TWColor.blue],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .opacity((move.isEmpty && q.isEmpty) ? 0.35 : 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(move.isEmpty && q.isEmpty)

                    Text("补录会合并到同一天的记录里；统计和力量曲线都会算上，但不会覆盖当天的正常训练。")
                        .font(.tw(10))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
    }

    private func rowLabel(_ t: String) -> some View {
        Text(t)
            .font(.tw(11, .semibold))
            .foregroundStyle(TWColor.ink3)
    }

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            rowLabel(title)
            HStack(spacing: 8) {
                Button { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } } label: {
                    Image(systemName: "minus")
                        .font(.tw(12, .bold))
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(TWColor.glass(0.5)) }
                }
                .buttonStyle(.plain)

                Text("\(value.wrappedValue)")
                    .font(.tw(17, .bold))
                    .foregroundStyle(TWColor.ink)
                    .frame(minWidth: 34)

                Button { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } } label: {
                    Image(systemName: "plus")
                        .font(.tw(12, .bold))
                        .frame(width: 30, height: 30)
                        .background { Circle().fill(TWColor.glass(0.5)) }
                }
                .buttonStyle(.plain)

                Text(unit).font(.tw(10.5)).foregroundStyle(TWColor.ink3)
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background { RoundedRectangle(cornerRadius: 13, style: .continuous).fill(TWColor.glass(0.4)) }
    }
}

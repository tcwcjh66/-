import SwiftUI

/// 目标设置：热量、蛋白、饮水、体重四项目标，改完立刻生效并持久化。
struct GoalSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var kcalText: String = ""
    @State private var proteinText: String = ""
    @State private var waterText: String = ""
    @State private var weightText: String = ""
    @State private var saved = false
    @FocusState private var focused: Int?

    private var kcalValue: Double? { Double(kcalText.replacingOccurrences(of: ",", with: "")) }
    private var proteinValue: Double? { Double(proteinText) }
    private var waterValue: Int? { Int(waterText) }
    private var weightValue: Double? { Double(weightText) }

    private var canSave: Bool {
        (kcalValue ?? 0) >= 800 && (kcalValue ?? 0) <= 6000 &&
        (proteinValue ?? 0) >= 20 && (proteinValue ?? 0) <= 500 &&
        (waterValue ?? 0) >= 2 && (waterValue ?? 0) <= 30
    }

    private var hint: String {
        let p = store.bodyWeight
        guard p > 0 else { return "先填体重，才能给你算蛋白推荐" }
        let low = Int(p * 1.4)
        let high = Int(p * 1.8)
        return "按你的体重 \(String(format: "%g", p)) kg，蛋白建议 \(low)–\(high) g（减脂吃 \(low) g，增肌吃 \(high) g）"
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

                    HStack {
                        Text("目标")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(Color.white.opacity(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    fieldBox("每日热量", unit: "kcal", text: $kcalText, index: 0,
                             note: "总消耗之外想吃到多少，减脂一般比维持低 15%")

                    fieldBox("每日蛋白", unit: "g", text: $proteinText, index: 1,
                             note: hint)

                    fieldBox("每日饮水", unit: "杯（\(store.cupSize)ml）", text: $waterText, index: 2,
                             note: "按 \(store.cupSize)ml 一杯算，大约每公斤体重 30ml")

                    fieldBox("目标体重", unit: "kg", text: $weightText, index: 3,
                             note: "只用作进度条基准，不影响热量目标")

                    Button {
                        save()
                    } label: {
                        HStack(spacing: 6) {
                            if saved {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            Text(saved ? "已保存" : "保存目标")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(canSave
                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                      : AnyShapeStyle(Color.gray.opacity(0.45)))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)

                    Text("热量 800–6000 kcal、蛋白 20–500 g、饮水 2–30 杯，超出范围不允许保存。")
                        .font(.system(size: 11))
                        .foregroundStyle(TWColor.ink3)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            kcalText = String(Int(store.dietTarget))
            proteinText = String(Int(store.proteinGoal))
            waterText = String(store.waterTarget)
            weightText = store.weightGoal > 0 ? String(format: "%g", store.weightGoal) : ""
        }
    }

    private func save() {
        guard canSave else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.dietTarget = kcalValue ?? store.dietTarget
        store.proteinGoal = proteinValue ?? store.proteinGoal
        store.waterTarget = waterValue ?? store.waterTarget
        if let w = weightValue, w > 20, w < 300 { store.weightGoal = w }
        store.persistSoon()
        withAnimation(.snappy(duration: 0.2)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
    }

    private func fieldBox(_ title: String, unit: String, text: Binding<String>,
                          index: Int, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(TWColor.ink)
            HStack(spacing: 8) {
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .focused($focused, equals: index)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.62))
                    }
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }
            Text(note)
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .twGlass()
    }
}

import SwiftUI
import UIKit

struct CustomFoodSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carb = ""
    @State private var fat = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(kcal) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 13) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                Text("自定义食物")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)

                Text("按每 100g 填写，记入时按分量自动换算")
                    .font(.system(size: 12))
                    .foregroundStyle(TWColor.ink3)

                row(title: "名称", text: $name, unit: "", placeholder: "如 食堂红烧肉", decimal: false)
                row(title: "热量", text: $kcal, unit: "kcal", placeholder: "如 320", decimal: true)
                row(title: "蛋白", text: $protein, unit: "g", placeholder: "如 12", decimal: true)
                row(title: "碳水", text: $carb, unit: "g", placeholder: "如 8", decimal: true)
                row(title: "脂肪", text: $fat, unit: "g", placeholder: "如 28", decimal: true)

                if !store.customFoods.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(store.customFoods.prefix(6)) { f in
                                Button {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    withAnimation(.snappy(duration: 0.2)) { store.removeCustomFood(id: f.id) }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(f.name)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(TWColor.ink2)
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(TWColor.ink3)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background {
                                        Capsule().fill(TWColor.glass(0.55))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    store.addCustomFood(CustomFood(
                        name: name.trimmingCharacters(in: .whitespaces),
                        kcalPer100: Double(kcal) ?? 0,
                        proteinPer100: Double(protein) ?? 0,
                        carbPer100: Double(carb) ?? 0,
                        fatPer100: Double(fat) ?? 0
                    ))
                    dismiss()
                } label: {
                    Text("保存到常吃")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .opacity(canSave ? 1 : 0.45)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
    }

    private func row(title: String, text: Binding<String>, unit: String, placeholder: String, decimal: Bool) -> some View {
        HStack(spacing: 9) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 38, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(TWColor.ink)
                .keyboardType(decimal ? .decimalPad : .default)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(TWColor.glass(0.62))
                }

            Text(unit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
                .frame(width: 30, alignment: .leading)
        }
    }
}

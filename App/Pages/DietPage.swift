import SwiftUI
import UIKit

struct DietPage: View {
    @EnvironmentObject var store: TWStore
    @State private var showPicker = false

    private var remaining: Double { max(store.dietTarget - store.dietKcal, 0) }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "饮食", subtitle: "今日摄入 · 拍照识别")
            kcalCard
            macroCard
            addCard
            mealList
        }
        .sheet(isPresented: $showPicker) {
            FoodPicker { item in
                store.addMeal(item)
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(28)
        }
    }

    private var kcalCard: some View {
        HStack(spacing: 18) {
            ZStack {
                ProgressRing(
                    value: store.dietTarget > 0 ? store.dietKcal / store.dietTarget : 0,
                    lineWidth: 12,
                    colors: [TWColor.mint, TWColor.mintSoft, TWColor.blue],
                    size: 136
                )
                VStack(spacing: 0) {
                    Text("\(Int(store.dietKcal))")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(TWColor.ink)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("还可以吃")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(TWColor.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(remaining))")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(TWColor.mint)
                        Text("kcal")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(TWColor.ink3)
                    }
                }

                Text("目标 \(Int(store.dietTarget)) · 已记录 \(store.meals.count) 餐")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .twGlass()
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("三大营养素")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(TWColor.ink2)

            macroRow(title: "蛋白质", value: store.protein, target: 110, tint: TWColor.coral, unit: "g")
            macroRow(title: "碳水", value: store.carb, target: 260, tint: TWColor.blue, unit: "g")
            macroRow(title: "脂肪", value: store.fat, target: 70, tint: TWColor.amber, unit: "g")
        }
        .padding(16)
        .twGlass()
    }

    private func macroRow(title: String, value: Double, target: Double, tint: Color, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) \(unit)")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(value >= target ? TWColor.mint : TWColor.ink3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.45))
                    Capsule()
                        .fill(LinearGradient(colors: [tint.opacity(0.85), tint.opacity(0.55)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(min(value / max(target, 1), 1)))
                }
            }
            .frame(height: 6)
        }
    }

    private var addCard: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 13, weight: .bold))
                    Text("加一餐").font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "camera.fill").font(.system(size: 14, weight: .bold))
                    Text("拍照识别").font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(TWColor.purple)
                .frame(width: 82, height: 46)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(TWColor.purple.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(TWColor.purple.opacity(0.22), lineWidth: 0.7)
                        }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var mealList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今天吃了什么")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                if !store.meals.isEmpty {
                    Button("清空") { store.resetToday() }
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            if store.meals.isEmpty {
                Text("还没记录。点「加一餐」或拍张照片，系统会算出热量和蛋白。")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            } else {
                ForEach(store.meals) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.name)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(TWColor.ink)
                            Text("\(Int(m.grams))g · 蛋白 \(Int(m.protein))g")
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer()
                        Text("\(Int(m.kcal)) kcal")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(TWColor.ink2)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .twGlass()
    }
}

struct FoodPicker: View {
    var onPick: (MealEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 150
    @State private var selected: FoodPreset = foodPresets[0]

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                Text("加一餐")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(foodPresets) { f in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { selected = f }
                            } label: {
                                HStack {
                                    Text(f.emoji).font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.name)
                                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(TWColor.ink)
                                        Text("每 100g · \(Int(f.kcalPer100)) kcal · 蛋白 \(String(format: "%.1f", f.proteinPer100))g")
                                            .font(.system(size: 9.5, weight: .regular))
                                            .foregroundStyle(TWColor.ink3)
                                    }
                                    Spacer()
                                    if selected.id == f.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(TWColor.purple)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(selected.id == f.id ? Color.white.opacity(0.82) : Color.white.opacity(0.34))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("分量")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(TWColor.ink2)
                        Spacer()
                        Text("\(Int(grams)) g")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(TWColor.purple)
                    }
                    Slider(value: $grams, in: 30...500, step: 5)
                        .tint(TWColor.purple)
                }
                .padding(.horizontal, 18)

                Button {
                    let g = grams / 100
                    onPick(MealEntry(
                        name: selected.name,
                        grams: grams,
                        kcal: selected.kcalPer100 * g,
                        protein: selected.proteinPer100 * g,
                        carb: selected.carbPer100 * g,
                        fat: selected.fatPer100 * g,
                        veg: selected.vegPer100 * g
                    ))
                    dismiss()
                } label: {
                    Text("记入今天")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 22)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct FoodPreset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var emoji: String
    var kcalPer100: Double
    var proteinPer100: Double
    var carbPer100: Double
    var fatPer100: Double
    var vegPer100: Double
}

let foodPresets: [FoodPreset] = [
    FoodPreset(name: "白米饭", emoji: "🍚", kcalPer100: 116, proteinPer100: 2.6, carbPer100: 25.9, fatPer100: 0.3, vegPer100: 0),
    FoodPreset(name: "鸡胸肉", emoji: "🍗", kcalPer100: 133, proteinPer100: 19.4, carbPer100: 2.5, fatPer100: 5.0, vegPer100: 0),
    FoodPreset(name: "西兰花", emoji: "🥦", kcalPer100: 34, proteinPer100: 2.8, carbPer100: 6.6, fatPer100: 0.4, vegPer100: 100),
    FoodPreset(name: "全麦面包", emoji: "🍞", kcalPer100: 246, proteinPer100: 8.5, carbPer100: 45.0, fatPer100: 3.3, vegPer100: 0),
    FoodPreset(name: "鸡蛋", emoji: "🥚", kcalPer100: 144, proteinPer100: 13.3, carbPer100: 2.8, fatPer100: 8.8, vegPer100: 0),
    FoodPreset(name: "牛油果", emoji: "🥑", kcalPer100: 160, proteinPer100: 2.0, carbPer100: 8.5, fatPer100: 14.7, vegPer100: 0),
    FoodPreset(name: "三文鱼", emoji: "🐟", kcalPer100: 208, proteinPer100: 20.0, carbPer100: 0, fatPer100: 13.0, vegPer100: 0),
    FoodPreset(name: "红薯", emoji: "🍠", kcalPer100: 86, proteinPer100: 1.6, carbPer100: 20.1, fatPer100: 0.1, vegPer100: 0)
]

import SwiftUI
import UIKit
import PhotosUI

struct DietPage: View {
    @EnvironmentObject var store: TWStore
    @State private var showPicker = false
    @State private var pick: PhotosPickerItem?
    @State private var analyzing = false
    @State private var hits: [FoodHit] = []
    @State private var showResult = false

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]

    private var remaining: Double { max(store.dietTarget - store.dietKcal, 0) }

    /// 按当前时间推断餐次
    private var autoSlot: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<10:  return "早餐"
        case 10..<15: return "午餐"
        case 15..<21: return "晚餐"
        default:      return "加餐"
        }
    }

    private func meals(in slot: String) -> [MealEntry] {
        store.meals.filter { ($0.slot ?? "加餐") == slot }
    }

    private func kcal(in slot: String) -> Int {
        Int(meals(in: slot).reduce(0) { $0 + $1.kcal })
    }

    private func slotTint(_ s: String) -> Color {
        switch s {
        case "早餐": return TWColor.amber
        case "午餐": return TWColor.mint
        case "晚餐": return TWColor.purple
        default:     return TWColor.blue
        }
    }

    private var recentLogs: [DayLog] { Array(store.logs.suffix(7)) }

    private var dayLabels: [String] {
        recentLogs.map { log in
            let p = log.id.split(separator: "-")
            return p.count == 3 ? "\(p[1])/\(p[2])" : log.id
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(title: "饮食", subtitle: "今日摄入 · 拍照识别")
            kcalCard
            macroCard
            addCard
            slotSection
            trendCard
            weekCard
        }
        .sheet(isPresented: $showPicker) {
            FoodPicker(defaultSlot: autoSlot) { item in
                store.addMeal(item)
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showResult) {
            ShotResultSheet(hits: hits, defaultSlot: autoSlot) { hit in
                store.addMeal(MealEntry(
                    name: hit.name,
                    grams: hit.grams,
                    kcal: hit.kcal,
                    protein: hit.protein,
                    carb: hit.carb,
                    fat: hit.fat,
                    veg: hit.veg,
                    slot: autoSlot,
                    time: Date()
                ))
            }
            .presentationDetents([.large])
            .presentationCornerRadius(28)
        }
        .onChange(of: pick) { _, newValue in
            guard let newValue else { return }
            analyzing = true
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    let found = FoodVision.analyze(img)
                    await MainActor.run {
                        hits = found
                        analyzing = false
                        showResult = true
                    }
                } else {
                    await MainActor.run { analyzing = false }
                }
            }
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
                        .font(.system(size: 31, weight: .heavy))
                        .foregroundStyle(TWColor.ink)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("还可以吃")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(Int(remaining))")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(TWColor.mint)
                        Text("kcal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(TWColor.ink3)
                    }
                }

                Text("目标 \(Int(store.dietTarget)) · 已记录 \(store.meals.count) 餐")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(TWColor.ink3)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .twGlass()
    }

    private var proteinNeed: Double {
        (store.sessionStart == nil && store.sessions.isEmpty) ? 110 : 130
    }

    private var proteinLeft: Double { max(0, proteinNeed - store.protein) }

    private var proteinHint: String {
        proteinLeft <= 0 ? "蛋白已达标" : "还差 \(Int(proteinLeft))g 蛋白"
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("三大营养素")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                GlassPill(text: proteinHint,
                          tint: proteinLeft <= 0 ? TWColor.mint : TWColor.coral)
            }

            macroRow(title: "蛋白质", value: store.protein, target: proteinNeed, tint: TWColor.coral, unit: "g")
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) \(unit)")
                    .font(.system(size: 12.5, weight: .semibold))
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
                    Image(systemName: "plus.circle.fill").font(.system(size: 15, weight: .bold))
                    Text("加一餐 · \(autoSlot)").font(.system(size: 15, weight: .bold))
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

            PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill").font(.system(size: 17, weight: .bold))
                    Text(analyzing ? "识别中" : "拍照识别").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(TWColor.purple)
                .frame(width: 92, height: 52)
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

    private var slotSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今天吃了什么")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(TWColor.ink2)
                Spacer()
                if !store.meals.isEmpty {
                    Button("清空") { store.resetToday() }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink3)
                }
            }

            if store.meals.isEmpty {
                Text("还没记录。点「加一餐」或拍张照片，系统会算出热量和蛋白。")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(slots, id: \.self) { s in
                    let items = meals(in: s)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 7) {
                                Circle()
                                    .fill(slotTint(s))
                                    .frame(width: 7, height: 7)
                                Text(s)
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(TWColor.ink)
                                Text("\(kcal(in: s)) kcal")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer(minLength: 0)
                            }
                            ForEach(items) { m in
                                mealRow(m)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .twGlass()
    }

    private func mealRow(_ m: MealEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.ink)
                Text("\(Int(m.grams))g · 蛋白 \(Int(m.protein))g · 碳 \(Int(m.carb))g · 脂 \(Int(m.fat))g")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 4)
            Text("\(Int(m.kcal))")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TWColor.ink2)
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.snappy(duration: 0.2)) { store.deleteMeal(id: m.id) }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(TWColor.ink3.opacity(0.65))
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var trendCard: some View {
        TrendChart(
            title: "摄入热量 · 最近 7 天",
            values: recentLogs.map { $0.kcal ?? 0 },
            labels: dayLabels,
            tint: TWColor.mint,
            unit: "kcal",
            goal: store.dietTarget
        )
        .padding(16)
        .twGlass()
    }

    private var weekCard: some View {
        let recorded = recentLogs.filter { ($0.kcal ?? 0) > 0 }
        let avg = recorded.isEmpty
            ? 0
            : recorded.reduce(0.0) { $0 + ($1.kcal ?? 0) } / Double(recorded.count)
        let kcalHit = recorded.filter { abs(($0.kcal ?? 0) - store.dietTarget) <= store.dietTarget * 0.1 }.count
        let proteinHit = recentLogs.filter { ($0.protein ?? 0) >= 110 }.count

        return HStack(spacing: 0) {
            miniStat(title: "平均", value: avg > 0 ? "\(Int(avg))" : "--", unit: "kcal", tint: TWColor.mint)
            divider
            miniStat(title: "有记录", value: "\(recorded.count)", unit: "天", tint: TWColor.blue)
            divider
            miniStat(title: "热量达标", value: "\(kcalHit)", unit: "天", tint: TWColor.purple)
            divider
            miniStat(title: "蛋白达标", value: "\(proteinHit)", unit: "天", tint: TWColor.coral)
        }
        .padding(.vertical, 14)
        .twGlass(radius: 18)
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.16))
            .frame(width: 0.8, height: 30)
    }

    private func miniStat(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FoodPicker: View {
    var defaultSlot: String = "午餐"
    var onPick: (MealEntry) -> Void
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double = 150
    @State private var selected: FoodPreset = foodPresets[0]
    @State private var slot: String = ""
    @State private var showCustom = false

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]
    private var activeSlot: String { slot.isEmpty ? defaultSlot : slot }

    private var customPresets: [FoodPreset] {
        store.customFoods.map { c in
            FoodPreset(name: c.name, emoji: "🍽️",
                       kcalPer100: c.kcalPer100, proteinPer100: c.proteinPer100,
                       carbPer100: c.carbPer100, fatPer100: c.fatPer100, vegPer100: 0)
        }
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    Text("加一餐")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        showCustom = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("自定义")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundStyle(TWColor.purple)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background {
                            Capsule().fill(TWColor.purple.opacity(0.12))
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)

                HStack(spacing: 7) {
                    ForEach(slots, id: \.self) { s in
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            withAnimation(.snappy(duration: 0.2)) { slot = s }
                        } label: {
                            Text(s)
                                .font(.system(size: 13, weight: activeSlot == s ? .bold : .medium))
                                .foregroundStyle(activeSlot == s ? .white : TWColor.ink2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(activeSlot == s
                                              ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                              : AnyShapeStyle(Color.white.opacity(0.42)))
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)

                ScrollView {
                    VStack(spacing: 8) {
                        if !customPresets.isEmpty {
                            HStack {
                                Text("我的常吃")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            ForEach(customPresets) { f in
                                presetRow(f)
                            }

                            HStack {
                                Text("常见食物")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(TWColor.ink3)
                                Spacer()
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                        }

                        ForEach(foodPresets) { f in
                            presetRow(f)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("分量")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(TWColor.ink2)
                        Spacer()
                        Text("\(Int(grams)) g")
                            .font(.system(size: 15, weight: .heavy))
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
                        veg: selected.vegPer100 * g,
                        slot: activeSlot,
                        time: Date()
                    ))
                    dismiss()
                } label: {
                    Text("记入\(activeSlot)")
                        .font(.system(size: 16, weight: .bold))
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
        .onAppear {
            if slot.isEmpty { slot = defaultSlot }
        }
        .sheet(isPresented: $showCustom) {
            CustomFoodSheet()
                .presentationDetents([.height(420)])
                .presentationCornerRadius(26)
        }
    }

    private func presetRow(_ f: FoodPreset) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { selected = f }
        } label: {
            HStack {
                Text(f.emoji).font(.system(size: 19))
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text("每 100g · \(Int(f.kcalPer100)) kcal · 蛋白 \(String(format: "%.1f", f.proteinPer100))g")
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer()
                if selected.name == f.name {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TWColor.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected.name == f.name ? Color.white.opacity(0.82) : Color.white.opacity(0.34))
            }
        }
        .buttonStyle(.plain)
    }
}

struct ShotResultSheet: View {
    var hits: [FoodHit]
    var defaultSlot: String = "午餐"
    var onAdd: (FoodHit) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []

    private let slots = ["早餐", "午餐", "晚餐", "加餐"]
    @State private var slot: String = ""

    private var activeSlot: String { slot.isEmpty ? defaultSlot : slot }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("识别结果")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(TWColor.ink)

                        Text(hits.isEmpty
                             ? "没看出明显食物，换个角度、把餐盘放正再拍一次"
                             : "共 \(hits.count) 项，勾选要记入的")
                            .font(.system(size: 13))
                            .foregroundStyle(TWColor.ink3)

                        HStack(spacing: 7) {
                            ForEach(slots, id: \.self) { s in
                                Button {
                                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                                    withAnimation(.snappy(duration: 0.2)) { slot = s }
                                } label: {
                                    Text(s)
                                        .font(.system(size: 13, weight: activeSlot == s ? .bold : .medium))
                                        .foregroundStyle(activeSlot == s ? .white : TWColor.ink2)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background {
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .fill(activeSlot == s
                                                      ? AnyShapeStyle(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                                      : AnyShapeStyle(Color.white.opacity(0.42)))
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        ForEach(hits) { h in
                            Button {
                                if selected.contains(h.id) {
                                    selected.remove(h.id)
                                } else {
                                    selected.insert(h.id)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(h.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(TWColor.ink)
                                        Text("\(Int(h.grams))g · \(Int(h.kcal)) kcal · 蛋白 \(Int(h.protein))g")
                                            .font(.system(size: 12))
                                            .foregroundStyle(TWColor.ink3)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: selected.contains(h.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(TWColor.purple)
                                }
                                .padding(14)
                                .background {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(Color.white.opacity(selected.contains(h.id) ? 0.85 : 0.42))
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                }

                Button {
                    for h in hits where selected.contains(h.id) {
                        onAdd(h)
                    }
                    dismiss()
                } label: {
                    Text("记入\(activeSlot)")
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
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            selected = Set(hits.map { $0.id })
            if slot.isEmpty { slot = defaultSlot }
        }
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

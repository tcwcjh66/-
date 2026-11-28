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
                            .font(.tw(24, .heavy))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    smartCard
                    adaptiveCard

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
                                    .font(.tw(13, .bold))
                            }
                            Text(saved ? "已保存" : "保存目标")
                                .font(.tw(16, .bold))
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
                        .font(.tw(11))
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

    /// 依据近两周体重趋势给出的热量修正；差得不多就不出现
    @ViewBuilder
    private var adaptiveCard: some View {
        if let a = store.adaptiveKcalAdvice {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.tw(13, .bold))
                        .foregroundStyle(TWColor.mint)
                    Text("按体重趋势修一下")
                        .font(.tw(14.5, .bold))
                        .foregroundStyle(TWColor.ink)
                    Spacer()
                    GlassPill(text: store.goalModeLabel, tint: TWColor.mint)
                }
                Text(a.reason)
                    .font(.tw(12))
                    .foregroundStyle(TWColor.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text("\(a.target) kcal")
                        .font(.tw(20, .heavy))
                        .foregroundStyle(TWColor.ink)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        kcalText = "\(a.target)"
                        store.dietTarget = Double(a.target)
                        store.persistSoon()
                    } label: {
                        Text("采纳")
                            .font(.tw(12.5, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule().fill(LinearGradient(colors: [TWColor.mint, TWColor.blue],
                                                              startPoint: .leading, endPoint: .trailing))
                            }
                    }
                    .buttonStyle(.plain)
                }
                Text("按近两周体重算的，只看趋势不看单日；采纳后目标立刻生效。")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(14)
            .twGlass()
        }
    }

    private var smartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "function")
                    .font(.tw(13, .bold))
                    .foregroundStyle(TWColor.blue)
                Text("按身体算一个")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("Mifflin-St Jeor")
                    .font(.tw(10))
                    .foregroundStyle(TWColor.ink3)
            }

            if store.bodyWeight <= 0 || store.heightCM <= 0 {
                Text("先去「身体」页填体重和身高，这里才算得出来。粗算需要这两个数。")
                    .font(.tw(12))
                    .foregroundStyle(TWColor.amber)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("基础代谢 \(Int(store.bmr)) kcal　·　\(store.activityLabel) ×\(String(format: "%.3f", store.activityFactor))　·　维持 \(store.maintainKcal) kcal")
                    .font(.tw(11.5))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        miniSeg(["减脂", "维持", "增肌"][i], on: store.goalMode == i,
                                tint: [TWColor.coral, TWColor.mint, TWColor.blue][i]) {
                            store.goalMode = i
                            store.persistSoon()
                        }
                    }
                }

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        miniSeg(["少动", "一般", "常练"][i], on: store.activityLevel == i,
                                tint: TWColor.purple) {
                            store.activityLevel = i
                            store.persistSoon()
                        }
                    }
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Button {
                            store.age = max(12, store.age - 1)
                            store.persistSoon()
                        } label: {
                            Image(systemName: "minus")
                                .font(.tw(11, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 26, height: 26)
                                .background { Circle().fill(TWColor.glass(0.5)) }
                        }
                        .buttonStyle(.plain)

                        Text("\(store.age) 岁")
                            .font(.tw(12.5, .bold))
                            .foregroundStyle(TWColor.ink)
                            .monospacedDigit()
                            .frame(minWidth: 48)

                        Button {
                            store.age = min(90, store.age + 1)
                            store.persistSoon()
                        } label: {
                            Image(systemName: "plus")
                                .font(.tw(11, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 26, height: 26)
                                .background { Circle().fill(TWColor.glass(0.5)) }
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        miniSeg("男", on: store.sexMale, tint: TWColor.blue) {
                            store.sexMale = true
                            store.persistSoon()
                        }
                        miniSeg("女", on: !store.sexMale, tint: TWColor.pink) {
                            store.sexMale = false
                            store.persistSoon()
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text("建议 \(store.recommendedKcal) kcal")
                        .font(.tw(15, .heavy))
                        .foregroundStyle(TWColor.ink)
                        .monospacedDigit()

                    Spacer(minLength: 0)

                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        kcalText = "\(store.recommendedKcal)"
                    } label: {
                        Text("填进每日热量")
                            .font(.tw(12, .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule().fill(LinearGradient(colors: [TWColor.blue, TWColor.purple],
                                                              startPoint: .leading, endPoint: .trailing))
                            }
                    }
                    .buttonStyle(.plain)
                }

                Text("减脂给维持 −400 kcal，增肌给维持 +300 kcal。这只是起点，真实消耗要看两周体重趋势再修。")
                    .font(.tw(10.5))
                    .foregroundStyle(TWColor.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .twGlass(radius: 16)
    }

    private func miniSeg(_ title: String, on: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(.tw(12, on ? .bold : .medium))
                .foregroundStyle(on ? .white : TWColor.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(on ? AnyShapeStyle(tint) : AnyShapeStyle(TWColor.glass(0.45)))
                }
        }
        .buttonStyle(.plain)
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
                .font(.tw(14, .bold))
                .foregroundStyle(TWColor.ink)
            HStack(spacing: 8) {
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .focused($focused, equals: index)
                    .font(.tw(19, .heavy))
                    .foregroundStyle(TWColor.ink)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(TWColor.glass(0.62))
                    }
                Text(unit)
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.ink3)
                    .lineLimit(1)
            }
            Text(note)
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .twGlass()
    }
}

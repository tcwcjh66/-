import SwiftUI
import UIKit

/// 扫到一个本机库和 Open Food Facts 都没有的条码时，填一次。
/// 存进本机条码库，下次扫同一个码直接出数，不再联网、不再等。
struct BarcodeNoteSheet: View {
    let code: String
    var onSave: (BarcodeNote) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var kcal = ""
    @State private var protein = ""
    @State private var carb = ""
    @State private var fat = ""
    @State private var serving = "100"
    @FocusState private var focus: Field?
    @State private var warn = ""

    private enum Field: Hashable { case name, brand, kcal, protein, carb, fat, serving }

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.4))
                        .frame(width: 34, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("给这个条码建个档")
                                .font(.tw(21, .heavy))
                                .foregroundStyle(TWColor.ink)
                            Text(code)
                                .font(.tw(12.5, .semibold))
                                .foregroundStyle(TWColor.purple)
                                .textSelection(.enabled)
                        }
                        Spacer(minLength: 0)
                        Button {
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.tw(13, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.55)) }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("包装背面「营养成分表」里每 100 克的数字，照抄就行。只在这一台手机上存着。")
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)

                    field("名称", text: $name, focus: .name, placeholder: "比如 乐事薯片 原味", kb: .default)
                    field("品牌（可不填）", text: $brand, focus: .brand, placeholder: "比如 乐事", kb: .default)

                    HStack(spacing: 10) {
                        numField("热量 kcal", text: $kcal, focus: .kcal)
                        numField("蛋白 g", text: $protein, focus: .protein)
                    }
                    HStack(spacing: 10) {
                        numField("碳水 g", text: $carb, focus: .carb)
                        numField("脂肪 g", text: $fat, focus: .fat)
                    }
                    field("一包/一份多少克", text: $serving, focus: .serving, placeholder: "100", kb: .decimalPad)

                    if !warn.isEmpty {
                        Text(warn)
                            .font(.tw(12))
                            .foregroundStyle(TWColor.amber)
                    }

                    Button {
                        save()
                    } label: {
                        Text("存进本机条码库")
                            .font(.tw(15.5, .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                            }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)

                    Text("只填热量也能用，蛋白碳水脂肪空着当 0。国产零食在 Open Food Facts 上基本查不到，这条库是给自己攒的。")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(28)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focus = .name }
        }
    }

    private func field(_ title: String, text: Binding<String>, focus f: Field,
                       placeholder: String, kb: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.tw(11.5, .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField(placeholder, text: text)
                .font(.tw(15))
                .keyboardType(kb)
                .focused($focus, equals: f)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TWColor.glass(0.7))
                }
        }
    }

    private func numField(_ title: String, text: Binding<String>, focus f: Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.tw(11, .semibold))
                .foregroundStyle(TWColor.ink3)
            TextField("0", text: text)
                .font(.tw(16, .semibold))
                .keyboardType(.decimalPad)
                .focused($focus, equals: f)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(TWColor.glass(0.7))
                }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else {
            warn = "至少填个名字，不然以后扫出来不知道是什么。"
            return
        }
        let k = Double(kcal.replacingOccurrences(of: "，", with: ".")) ?? 0
        guard k > 0 else {
            warn = "热量要大于 0，不然等于没记。"
            return
        }
        let note = BarcodeNote(
            code: code.trimmingCharacters(in: .whitespacesAndNewlines),
            name: n,
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            kcal100: k,
            protein100: Double(protein) ?? 0,
            carb100: Double(carb) ?? 0,
            fat100: Double(fat) ?? 0,
            servingGrams: max(1, Double(serving) ?? 100),
            fromWeb: false,
            at: Date()
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onSave(note)
        dismiss()
    }
}

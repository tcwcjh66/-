import SwiftUI
import UIKit

struct BodySheet: View {
    @Binding var w: String
    @Binding var h: String
    @Binding var waist: String
    var onSubmit: (Double, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                Text("记录身体数据")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)

                field(title: "体重", text: $w, unit: "kg", placeholder: "如 68.5")
                field(title: "身高", text: $h, unit: "cm", placeholder: "如 175")
                field(title: "腰围", text: $waist, unit: "cm", placeholder: "如 78")

                Text("体重按天记录，同一天再记会覆盖；只填想更新的项也行。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)

                Button {
                    let kg = Double(w) ?? 0
                    let height = Double(h) ?? 0
                    let waistV = Double(waist) ?? 0
                    onSubmit(kg, height, waistV)
                    dismiss()
                } label: {
                    Text("保存")
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
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func field(title: String, text: Binding<String>, unit: String, placeholder: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 44, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.system(size: 17, weight: .semibold))
                .keyboardType(.decimalPad)
                .foregroundStyle(TWColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.62))
                }

            Text(unit)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
                .frame(width: 26, alignment: .leading)
        }
    }
}

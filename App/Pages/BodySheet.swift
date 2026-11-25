import SwiftUI
import UIKit

struct BodySheet: View {
    @Binding var w: String
    @Binding var h: String
    @Binding var waist: String
    @Binding var goal: String
    @Binding var chest: String
    @Binding var arm: String
    @Binding var thigh: String
    @Binding var hip: String
    var onSubmit: (Double, Double, Double, Double, Double, Double, Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 0) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                Text("记录身体数据")
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundStyle(TWColor.ink)
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 11) {
                        sectionTitle("基础")
                        field(title: "体重", text: $w, unit: "kg", placeholder: "如 68.5")
                        field(title: "身高", text: $h, unit: "cm", placeholder: "如 175")
                        field(title: "目标体重", text: $goal, unit: "kg", placeholder: "如 65")

                        sectionTitle("围度")
                            .padding(.top, 4)
                        field(title: "腰围", text: $waist, unit: "cm", placeholder: "如 78")
                        field(title: "胸围", text: $chest, unit: "cm", placeholder: "如 96")
                        field(title: "臂围", text: $arm, unit: "cm", placeholder: "如 34")
                        field(title: "腿围", text: $thigh, unit: "cm", placeholder: "如 56")
                        field(title: "臀围", text: $hip, unit: "cm", placeholder: "如 94")

                        Text("体重按天记录，同一天再记会覆盖；只填想更新的项也行。目标体重会画在体重趋势图上。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TWColor.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    let vals: [Double] = [w, h, waist, goal, chest, arm, thigh, hip].map { Double($0) ?? 0 }
                    onSubmit(vals[0], vals[1], vals[2], vals[3], vals[4], vals[5], vals[6], vals[7])
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
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }

    private func sectionTitle(_ t: String) -> some View {
        HStack {
            Text(t)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TWColor.ink3)
            Spacer()
        }
    }

    private func field(title: String, text: Binding<String>, unit: String, placeholder: String) -> some View {
        HStack(spacing: 9) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
                .frame(width: 58, alignment: .leading)

            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .semibold))
                .keyboardType(.decimalPad)
                .foregroundStyle(TWColor.ink)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(TWColor.glass(0.62))
                }

            Text(unit)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
                .frame(width: 28, alignment: .leading)
        }
    }
}

import SwiftUI
import UIKit

struct PRSheet: View {
    let moveName: String
    var current: String? = nil
    var onSubmit: (Double, Int) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var weight = ""
    @State private var reps = ""

    private var canSave: Bool {
        (Int(reps) ?? 0) > 0
    }

    var body: some View {
        ZStack {
            AuroraBG()
            VStack(spacing: 14) {
                Capsule()
                    .fill(TWColor.ink3.opacity(0.4))
                    .frame(width: 34, height: 4)
                    .padding(.top, 8)

                Text("记录最好成绩")
                    .font(.tw(19, .heavy))
                    .foregroundStyle(TWColor.ink)

                Text(moveName)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink3)

                if let c = current {
                    Text("当前：\(c)")
                        .font(.tw(12, .semibold))
                        .foregroundStyle(TWColor.amber)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("重量")
                            .font(.tw(12, .semibold))
                            .foregroundStyle(TWColor.ink3)
                        HStack(spacing: 6) {
                            TextField("如 70", text: $weight)
                                .font(.tw(20, .heavy))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TWColor.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(TWColor.glass(0.62))
                                }
                            Text("kg")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink3)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("次数")
                            .font(.tw(12, .semibold))
                            .foregroundStyle(TWColor.ink3)
                        HStack(spacing: 6) {
                            TextField("如 5", text: $reps)
                                .font(.tw(20, .heavy))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(TWColor.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(TWColor.glass(0.62))
                                }
                            Text("次")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink3)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Text("重量可以留空，表示自重动作。次数必填，比如引体向上填 8 就是「自重 × 8」。")
                    .font(.tw(11))
                    .foregroundStyle(TWColor.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onSubmit(Double(weight) ?? 0, Int(reps) ?? 0)
                    dismiss()
                } label: {
                    Text("保存")
                        .font(.tw(16, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(LinearGradient(colors: [TWColor.amber, TWColor.coral],
                                                     startPoint: .leading, endPoint: .trailing))
                                .opacity(canSave ? 1 : 0.45)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

import SwiftUI
import UIKit

struct WaterSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var cup: Int = 250
    @State private var target: Int = 8
    @State private var customText = ""

    private let presets = [150, 200, 250, 300, 350, 400]

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    cupCard
                    targetCard
                    totalCard
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            cup = store.cupSize
            target = store.waterTarget
            customText = "\(store.cupSize)"
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(TWColor.ink3.opacity(0.4))
                .frame(width: 34, height: 4)
                .padding(.top, 8)
            Text("饮水设置")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(TWColor.ink)
            Text("按你自己的杯子来算，不用迁就默认的 250ml")
                .font(.system(size: 12))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(.top, 4)
    }

    private var cupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.blue)
                Text("每杯容量")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(cup) ml")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.blue)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 7) {
                ForEach(presets, id: \.self) { v in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.18)) {
                            cup = v
                            customText = "\(v)"
                        }
                    } label: {
                        Text("\(v)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(cup == v ? .white : TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(cup == v
                                          ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                                         startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(TWColor.glass(0.6)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text("自定义")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TWColor.ink3)
                TextField("如 280", text: $customText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TWColor.ink)
                    .frame(width: 90)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(TWColor.glass(0.6))
                    }
                    .onChange(of: customText) { _, newValue in
                        if let v = Int(newValue), v >= 50, v <= 1000 { cup = v }
                    }
                Text("ml")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TWColor.ink3)
                Spacer()
            }
        }
        .padding(16)
        .twGlass()
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                Text("每天几杯")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer()
                Text("\(target) 杯")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.purple)
                    .contentTransition(.numericText())
            }

            HStack(spacing: 14) {
                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) { target = max(2, target - 1) }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 46, height: 42)
                        .background {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(TWColor.glass(0.6))
                        }
                }
                .buttonStyle(.plain)

                HStack(spacing: 3) {
                    ForEach(0..<min(target, 12), id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(i < target
                                  ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                                 startPoint: .bottom, endPoint: .top))
                                  : AnyShapeStyle(TWColor.glass(0.4)))
                            .frame(width: 9, height: 18)
                    }
                }
                .frame(maxWidth: .infinity)

                Button {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.snappy(duration: 0.18)) { target = min(16, target + 1) }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(TWColor.ink2)
                        .frame(width: 46, height: 42)
                        .background {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(TWColor.glass(0.6))
                        }
                }
                .buttonStyle(.plain)
            }

            Text("一般成年人每天 1500–2000 ml，训练日加 500 ml。天热或出汗多就再往上加。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .lineSpacing(2.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .twGlass()
    }

    private var totalCard: some View {
        VStack(spacing: 6) {
            Text("每日目标")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(target * cup)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(TWColor.ink)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("ml")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            Text("\(target) 杯 × \(cup) ml")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(16)
        .twGlass()
    }

    private var saveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            store.cupSize = cup
            store.waterTarget = target
            store.persist()
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                             startPoint: .leading, endPoint: .trailing))
                }
        }
        .buttonStyle(.plain)
    }
}

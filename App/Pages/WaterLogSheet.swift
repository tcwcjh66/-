import SwiftUI
import UIKit

/// 记录任意毫升饮水（一瓶 550、半杯 120 这种）
struct WaterLogSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @FocusState private var focused: Bool

    private let quick = [100, 200, 300, 500, 750]

    private var amount: Int? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let v = Int(raw), v > 0, v <= 2000 else { return nil }
        return v
    }

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
                        headerRow
                        quickCard
                        inputCard
                        previewCard
                        confirmButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 26)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { focused = true }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("记一笔饮水")
                .font(.tw(20, .heavy))
                .foregroundStyle(TWColor.ink)
            Spacer(minLength: 0)
            Button("关闭") { dismiss() }
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink2)
        }
    }

    private var quickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("常见容量")
                .font(.tw(13, .bold))
                .foregroundStyle(TWColor.ink2)
            HStack(spacing: 7) {
                ForEach(quick, id: \.self) { v in
                    Button {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        withAnimation(.snappy(duration: 0.18)) { text = "\(v)" }
                    } label: {
                        Text("\(v)")
                            .font(.tw(12.5, amount == v ? .bold : .medium, .rounded))
                            .foregroundStyle(amount == v ? .white : TWColor.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(amount == v
                                          ? AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                                         startPoint: .leading, endPoint: .trailing))
                                          : AnyShapeStyle(TWColor.glass(0.56)))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("小半杯 120、一罐 330、一瓶 550 都能直接填")
                .font(.tw(11))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(15)
        .twGlass()
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("喝了多少")
                    .font(.tw(14, .bold))
                    .foregroundStyle(TWColor.ink)
                Spacer(minLength: 0)
                Text("ml")
                    .font(.tw(12, .bold))
                    .foregroundStyle(TWColor.ink3)
            }
            TextField("自己填，1–2000", text: $text)
                .font(.tw(28, .heavy, .rounded))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .foregroundStyle(TWColor.ink)
                .focused($focused)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(TWColor.glass(0.62))
                }
        }
        .padding(15)
        .twGlass()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("喝完之后")
                    .font(.tw(12, .semibold))
                    .foregroundStyle(TWColor.ink3)
                Spacer(minLength: 0)
                Text("\(previewTotal) / \(store.waterTargetML) ml")
                    .font(.tw(15, .heavy, .rounded))
                    .foregroundStyle(TWColor.blue)
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(TWColor.ink3.opacity(0.16))
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [TWColor.blue, TWColor.mintSoft],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * previewRatio), height: 8)
                }
            }
            .frame(height: 8)
            Text(previewNote)
                .font(.tw(11.5))
                .foregroundStyle(TWColor.ink3)
        }
        .padding(15)
        .twGlass()
    }

    private var confirmButton: some View {
        Button {
            guard let a = amount else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            store.addWaterML(a)
            dismiss()
        } label: {
            Text(amount == nil ? "先填个数字" : "记入 \(amount!) ml")
                .font(.tw(16, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(amount == nil
                              ? AnyShapeStyle(TWColor.ink3.opacity(0.45))
                              : AnyShapeStyle(LinearGradient(colors: [TWColor.blue, TWColor.mint],
                                                             startPoint: .leading, endPoint: .trailing)))
                }
        }
        .buttonStyle(.plain)
        .disabled(amount == nil)
    }

    private var previewTotal: Int {
        max(0, store.waterML + (amount ?? 0))
    }

    private var previewRatio: Double {
        guard store.waterTargetML > 0 else { return 0 }
        return min(1, Double(previewTotal) / Double(store.waterTargetML))
    }

    private var previewNote: String {
        let total = previewTotal
        let cup = max(1, store.cupSize)
        let cups = total / cup
        let extra = total % cup
        if extra > 0 {
            return "折合 \(cups) 杯 + \(extra) ml（每杯 \(cup) ml）"
        }
        return "折合 \(cups) 杯（每杯 \(cup) ml）"
    }
}

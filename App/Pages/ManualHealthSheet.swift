import SwiftUI
import UIKit

/// 免费证书拿不到 HealthKit，睡眠、静息心率、HRV 只能自己填。
/// 这三项是恢复度的原料，不填的话首页那个分数永远是空的。
struct ManualHealthSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var hours = ""
    @State private var restHR = ""
    @State private var hrvText = ""

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("手动健康数据")
                                .font(.tw(22, .heavy))
                                .foregroundStyle(TWColor.ink)
                            Text("免费签名读不到 HealthKit。这三项填了，首页恢复度才有得算。")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 32, height: 32)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    input("昨晚睡了多久", text: $hours, unit: "小时",
                          hint: "7.5", icon: "bed.double.fill", tint: TWColor.purple)
                    input("今早静息心率", text: $restHR, unit: "bpm",
                          hint: "62", icon: "heart.fill", tint: TWColor.coral)
                    input("HRV（不知道就留空）", text: $hrvText, unit: "ms",
                          hint: "48", icon: "waveform.path.ecg", tint: TWColor.blue)

                    Button {
                        let h = Double(hours.trimmingCharacters(in: .whitespaces)) ?? 0
                        store.manualSleepMin = Int(max(0, min(16, h)) * 60)
                        store.manualRestingHR = Int(restHR.trimmingCharacters(in: .whitespaces)) ?? 0
                        store.manualHRV = Int(hrvText.trimmingCharacters(in: .whitespaces)) ?? 0
                        store.persist()
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.tw(15, .bold))
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

                    Text("这些数字只存在本机，不上传。手表数据接上后会优先用手表实测值，这里的值只补空。")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.manualSleepMin > 0 || store.manualRestingHR > 0 || store.manualHRV > 0 {
                        Button {
                            store.manualSleepMin = 0
                            store.manualRestingHR = 0
                            store.manualHRV = 0
                            store.persist()
                            hours = ""
                            restHR = ""
                            hrvText = ""
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        } label: {
                            Text("清除手填数据")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            hours = store.manualSleepMin > 0 ? String(format: "%.1f", Double(store.manualSleepMin) / 60) : ""
            restHR = store.manualRestingHR > 0 ? "\(store.manualRestingHR)" : ""
            hrvText = store.manualHRV > 0 ? "\(store.manualHRV)" : ""
        }
    }

    private func input(_ title: String, text: Binding<String>, unit: String,
                       hint: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.tw(12, .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.tw(13, .semibold))
                    .foregroundStyle(TWColor.ink2)
            }
            HStack(spacing: 6) {
                TextField(hint, text: text)
                    .font(.tw(20, .bold))
                    .foregroundStyle(TWColor.ink)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                Text(unit)
                    .font(.tw(11.5, .medium))
                    .foregroundStyle(TWColor.ink3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(TWColor.glass(0.45))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .twGlass()
    }
}

import SwiftUI
import UIKit

struct SettingsSheet: View {
    @EnvironmentObject var store: TWStore
    @Environment(\.dismiss) private var dismiss

    @State private var showReset = false
    @State private var showCopied = false
    @State private var showGoal = false
    @State private var exportURL: URL?

    private var versionText: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v)（\(b)）"
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
                        Text("设置")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(TWColor.ink)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(Color.white.opacity(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }

                    overviewCard
                    goalCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showGoal) {
            GoalSheet()
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .onAppear { exportURL = store.exportJSONFile() }
        .confirmationDialog("确定清空全部数据？", isPresented: $showReset, titleVisibility: .visible) {
            Button("清空", role: .destructive) { store.resetAll() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("体重、围度、训练记录、饮食记录、收藏都会删掉，无法恢复。")
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据概览")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TWColor.ink)

            HStack(spacing: 0) {
                metric(title: "有记录", value: "\(store.logs.count)", unit: "天", tint: TWColor.blue)
                divider
                metric(title: "训练", value: "\(store.sessions.count)", unit: "次", tint: TWColor.purple)
                divider
                metric(title: "饮食", value: "\(store.meals.count)", unit: "餐", tint: TWColor.mint)
                divider
                metric(title: "收藏", value: "\(store.favoriteMoves.count)", unit: "个", tint: TWColor.coral)
            }
        }
        .padding(16)
        .twGlass()
    }

    private var goalCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            showGoal = true
        } label: {
            HStack(spacing: 11) {
                Image(systemName: "target")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TWColor.purple)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(TWColor.purple.opacity(0.12))
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("目标设置")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(TWColor.ink)
                    Text("\(Int(store.dietTarget)) kcal · 蛋白 \(Int(store.proteinGoal)) g · 水 \(store.waterTarget) 杯")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TWColor.ink3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .buttonStyle(.plain)
        .padding(16)
        .twGlass()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("数据")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TWColor.ink)

            ShareLink(item: exportURL ?? FileManager.default.temporaryDirectory,
                      subject: Text("天才威数据备份")) {
                HStack(spacing: 11) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TWColor.blue)
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(TWColor.blue.opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("导出全部数据")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("JSON 文件 · 存到「文件」或发给自己")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(TWColor.ink3)
                }
            }
            .buttonStyle(.plain)

            Rectangle().fill(TWColor.ink3.opacity(0.12)).frame(height: 0.7)

            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                showReset = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TWColor.coral)
                        .frame(width: 34, height: 34)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(TWColor.coral.opacity(0.12))
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("清空全部数据")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(TWColor.ink)
                        Text("删除本机所有记录，不可恢复")
                            .font(.system(size: 11.5))
                            .foregroundStyle(TWColor.ink3)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .twGlass()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("关于")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(TWColor.ink)

            infoRow("版本", versionText)
            infoRow("签名方式", "免费 Apple ID 侧载")
            infoRow("数据存储", "只在本机，不上传")
            infoRow("动作库", "\(allMoves.count) 个 · 方案 \(planTemplates.count) 套")
            infoRow("心率来源", "指尖 PPG / 手动 / 快捷指令回传")

            Text("所有身体数据来自 iPhone 自身传感器或你手动输入，不含模拟数据。手表数据需要 HealthKit 授权，免费签名下不可用。")
                .font(.system(size: 11.5))
                .foregroundStyle(TWColor.ink3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .twGlass()
    }

    private var divider: some View {
        Rectangle()
            .fill(TWColor.ink3.opacity(0.16))
            .frame(width: 0.8, height: 28)
    }

    private func metric(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(TWColor.ink3)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(TWColor.ink2)
                .multilineTextAlignment(.trailing)
        }
    }
}

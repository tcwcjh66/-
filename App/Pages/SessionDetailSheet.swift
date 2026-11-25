import SwiftUI
import UIKit

struct SessionDetailSheet: View {
    let session: SessionLog
    @Environment(\.dismiss) private var dismiss

    private var dateText: String {
        let p = session.date.split(separator: "-")
        guard p.count == 3 else { return session.date }
        return "\(p[0]) 年 \(p[1]) 月 \(p[2]) 日"
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

                    Text(session.day.isEmpty ? session.plan : session.day)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(TWColor.ink)

                    Text("\(session.plan) · \(dateText)")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(TWColor.ink3)

                    HStack(spacing: 0) {
                        stat(title: "总组数", value: "\(session.sets)", unit: "组", tint: TWColor.purple)
                        Rectangle().fill(TWColor.ink3.opacity(0.16)).frame(width: 0.8, height: 30)
                        stat(title: "时长", value: "\(session.minutes)", unit: "分钟", tint: TWColor.blue)
                        Rectangle().fill(TWColor.ink3.opacity(0.16)).frame(width: 0.8, height: 30)
                        stat(title: "动作", value: "\(session.moves)", unit: "个", tint: TWColor.mint)
                    }
                    .padding(.vertical, 14)
                    .twGlass(radius: 18)

                    if let names = session.moveNames, !names.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("这次练了什么")
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundStyle(TWColor.ink)
                            ForEach(Array(names.enumerated()), id: \.offset) { pair in
                                HStack(spacing: 9) {
                                    Circle()
                                        .fill(TWColor.mint)
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    Text(pair.element)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(TWColor.ink)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .twGlass()
                    }

                    Text("这次训练帮助：训练 \(session.minutes) 分钟，按每小时约 300 kcal 估算，约消耗 \(session.minutes * 5) kcal。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
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
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func stat(title: String, value: String, unit: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

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
                        .font(.tw(26, .heavy))
                        .foregroundStyle(TWColor.ink)

                    Text("\(session.plan) · \(dateText)")
                        .font(.tw(12.5, .medium))
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

                    if let note = session.note, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("当时写的")
                                .font(.tw(11.5, .semibold))
                                .foregroundStyle(TWColor.ink3)
                            Text(note)
                                .font(.tw(13))
                                .foregroundStyle(TWColor.ink2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .twGlass(radius: 16)
                    }

                    if let names = session.moveNames, !names.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("这次练了什么")
                                .font(.tw(15.5, .bold))
                                .foregroundStyle(TWColor.ink)
                            ForEach(Array(names.enumerated()), id: \.offset) { pair in
                                HStack(spacing: 9) {
                                    Circle()
                                        .fill(TWColor.mint)
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.tw(9, .bold))
                                                .foregroundStyle(.white)
                                        }
                                    Text(pair.element)
                                        .font(.tw(14, .semibold))
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
                        .font(.tw(11.5))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
                            .font(.tw(16, .bold))
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
                .font(.tw(11, .semibold))
                .foregroundStyle(TWColor.ink3)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.tw(20, .heavy))
                    .foregroundStyle(tint)
                Text(unit)
                    .font(.tw(10.5, .medium))
                    .foregroundStyle(TWColor.ink3)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

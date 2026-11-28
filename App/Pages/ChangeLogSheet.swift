import SwiftUI

/// 这一版改了什么：按版本倒序，只写用户能看见的变化。
/// 真机上验功能时对着点，省得凭记忆猜哪条在哪个版本。
struct ChangeLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    private struct Release: Identifiable {
        var id: String { version }
        let version: String
        let date: String
        let title: String
        let items: [String]
    }

    private let releases: [Release] = [
        Release(version: "3.66", date: "11 月 28 日", title: "生态系统接通", items: [
            "通知按钮：休息到点可「再歇 30 秒」或「开始下一组」，训练提醒直接「现在开始」",
            "统一深链：训练直接开练、饮食直接拍照、身体直接记体重、按名字切计划",
            "锁屏实况显示「第 N 组 · 完成 x/y」，训练中也能看到计划进度",
            "Siri 新增「今天练了几组」「这周练了几次」",
            "系统搜索收录训练计划，搜到就切到那套方案",
            "手表看今天练什么、已记几组，抬手点 +1 组直接补记",
            "运行状态页新增系统搜索 / 手表 / 深链三项自检"
        ]),
        Release(version: "3.65", date: "11 月 28 日", title: "语音、备注与减载", items: [
            "Siri 记一组、开始训练、今天练什么",
            "训练备注与计划组数，结算页可写、详情页可看",
            "固定训练日、目标体重 ETA、计划完成率",
            "减载周、动作库器械筛选、练后拉伸"
        ]),
        Release(version: "3.63", date: "11 月 27 日", title: "安全与整理", items: [
            "应用锁：Face ID / 密码才能进",
            "强度百分比表、停滞与过载预警、自适应热量",
            "数据体检一键修复、饮食批量整理、备份提醒"
        ]),
        Release(version: "3.62", date: "11 月 28 日", title: "八条优化一次做完", items: [
            "训练现场快照：中途退出，重开能接着记，超 12 小时作废",
            "PR 自动比对：每组按估算 1RM 比历史最好，破了弹奖杯",
            "按器械筛计划：设置里勾你有的器械，候选只留能做的",
            "口语份量：半碗、两勺、一小把直接折算克数",
            "食物库 +183 条，总数约 965，整串说法命中更稳",
            "图标切换：疾速 P 原色 / 单色线两套，设置里换",
            "照昨天吃：一键把昨天三餐复制到今天",
            "Spotlight 索引：桌面下拉搜动作和食物，直达对应页"
        ]),
        Release(version: "3.60", date: "11 月 27 日", title: "食物识别对上了", items: [
            "新增 FoodRank 匹配：剥掉 70g、500ml、2 袋再比",
            "整串说法也能命中：乐事原味薯片、蜜雪柠檬水",
            "结果行补碳水、脂肪；认不出就给候选和同类估算",
            "读到但没对上号的字单独列出，点一下填进补充框"
        ]),
        Release(version: "3.58", date: "11 月 26 日", title: "补课与收尾", items: [
            "按动作推荐的热身清单补齐",
            "通知锁屏快捷按钮、全局搜索、补录训练",
            "每周每部位组数、蛋白分布"
        ]),
        Release(version: "3.57", date: "11 月 26 日", title: "八条一起上", items: [
            "深色 / 着色图标、体脂估算、每周每部位组数",
            "全局搜索、补录训练、蛋白分布"
        ]),
        Release(version: "3.56", date: "11 月 25 日", title: "换图标、改名字", items: [
            "软件名从「天才威」改成 Persist",
            "新图标「疾速 P」：玫红到黄、右倾、三道速度线"
        ])
    ]

    var body: some View {
        ZStack {
            AuroraBG()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("更新日志")
                                .font(.tw(24, .heavy))
                                .foregroundStyle(TWColor.ink)
                            Text("从 3.56 到现在，只列看得见的变化")
                                .font(.tw(11.5))
                                .foregroundStyle(TWColor.ink3)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.tw(12, .bold))
                                .foregroundStyle(TWColor.ink2)
                                .frame(width: 34, height: 34)
                                .background { Circle().fill(TWColor.glass(0.6)) }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 10)

                    ForEach(releases) { r in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 8) {
                                Text(r.version)
                                    .font(.tw(13, .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background {
                                        Capsule().fill(LinearGradient(colors: [TWColor.purple, TWColor.violet],
                                                                      startPoint: .leading, endPoint: .trailing))
                                    }
                                Text(r.title)
                                    .font(.tw(14, .bold))
                                    .foregroundStyle(TWColor.ink)
                                Spacer(minLength: 0)
                                Text(r.date)
                                    .font(.tw(10.5))
                                    .foregroundStyle(TWColor.ink3)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(r.items.enumerated()), id: \.offset) { pair in
                                    HStack(alignment: .top, spacing: 7) {
                                        Circle()
                                            .fill(TWColor.purple.opacity(0.5))
                                            .frame(width: 4, height: 4)
                                            .padding(.top, 7)
                                        Text(pair.element)
                                            .font(.tw(12.5))
                                            .foregroundStyle(TWColor.ink2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .twGlass()
                    }

                    Text("更早的版本（3.0–3.55）是打地基：饮食识别、训练流程、恢复建议、成就、周报、分享卡、Widget、Live Activity、快捷指令、备份、体检页都是那段时间加的。")
                        .font(.tw(11))
                        .foregroundStyle(TWColor.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }
}

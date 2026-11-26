import SwiftUI

/// 恢复度：用手表回传的 HRV、睡眠，加上本机的训练负荷算一个"今天该使劲还是该歇"。
/// 数据不够就直接不给结论——宁可空着，也不编一个分数。
struct RecoveryScore {
    var value: Int
    var advice: String
    var tint: Color
    var reasons: [String]
}

enum TWRecovery {
    static func today(_ store: TWStore) -> RecoveryScore? {
        // 免费签名拿不到 HealthKit，手填的值优先，恢复度才有得算
        let hrv = store.manualHRV > 0 ? store.manualHRV : store.hrv
        let sleep = store.manualSleepMin > 0 ? store.manualSleepMin : store.watchSleepMin
        let hrvTag = store.manualHRV > 0 ? "（手填）" : ""
        let sleepTag = store.manualSleepMin > 0 ? "（手填）" : ""
        let streak = store.trainingStreak
        // 三项全无：没有 HRV、没有睡眠、也还没练过，那就别评
        guard hrv > 0 || sleep > 0 || streak > 0 else { return nil }

        var score = 58.0
        var reasons: [String] = []

        if hrv > 0 {
            if hrv >= 65 {
                score += 18
                reasons.append("HRV \(hrv) ms\(hrvTag)，恢复得不错")
            } else if hrv >= 45 {
                score += 8
                reasons.append("HRV \(hrv) ms\(hrvTag)，正常区间")
            } else if hrv >= 30 {
                score -= 4
                reasons.append("HRV \(hrv) ms\(hrvTag)，偏低")
            } else {
                score -= 14
                reasons.append("HRV \(hrv) ms\(hrvTag)，明显偏低")
            }
        }

        if sleep > 0 {
            let h = Double(sleep) / 60.0
            if h >= 7.5 {
                score += 10
                reasons.append(String(format: "睡了 %.1f 小时", h) + sleepTag)
            } else if h >= 6.5 {
                score += 4
                reasons.append(String(format: "睡了 %.1f 小时", h) + sleepTag)
            } else if h >= 5 {
                score -= 8
                reasons.append(String(format: "只睡 %.1f 小时", h) + sleepTag)
            } else {
                score -= 16
                reasons.append(String(format: "只睡 %.1f 小时", h) + sleepTag + "，太短")
            }
        }

        if streak >= 6 {
            score -= 12
            reasons.append("已经连练 \(streak) 天")
        } else if streak >= 4 {
            score -= 6
            reasons.append("连练 \(streak) 天")
        } else if streak > 0 {
            score += 2
        }

        // 昨天容量太大，今天别硬顶
        if let last = store.sessions.first, let t = last.tonnage, t > 0 {
            if t > 6000 {
                score -= 8
                reasons.append("上次容量 \(Int(t)) kg，偏大")
            } else if t < 1500 {
                score += 3
            }
        }

        let v = Int(max(0, min(100, score.rounded())))
        let advice: String
        let tint: Color
        if v >= 72 {
            advice = "今天可以上强度"
            tint = TWColor.mint
        } else if v >= 50 {
            advice = "正常练，别硬冲 PR"
            tint = TWColor.amber
        } else {
            advice = "建议轻练或休息"
            tint = TWColor.coral
        }

        return RecoveryScore(value: v, advice: advice, tint: tint, reasons: reasons)
    }
}

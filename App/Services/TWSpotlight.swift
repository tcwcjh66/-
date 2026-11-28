import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// 把动作和食物塞进系统搜索：桌面下拉搜「卧推」「蜜雪」，不用先开 App。
/// 免费签名可用，不需要任何 entitlement。
enum TWSpotlight {
    static let domain = "com.tiancaiwei.spotlight"
    private static let versionKey = "tw.spotlight.version"
    private static let countKey = "tw.spotlight.count"

    /// 运行状态页要显示「已索引多少条」
    static var indexedCount: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    static func indexIfNeeded(force: Bool = false) {
        let version = "v3-\(FoodBase.items.count)-\(allMoves.count)-\(planTemplates.count)"
        if !force, UserDefaults.standard.string(forKey: versionKey) == version { return }
        UserDefaults.standard.set(version, forKey: versionKey)

        let moves = allMoves
        let foods = FoodBase.items
        let plans = planTemplates

        DispatchQueue.global(qos: .utility).async {
            var items: [CSSearchableItem] = []

            for m in moves {
                let a = CSSearchableItemAttributeSet(contentType: .text)
                a.title = m.name
                a.contentDescription = "\(m.group) · \(m.equipment) · \(m.pr)"
                a.keywords = [m.name, m.group, m.equipment, "动作"]
                items.append(CSSearchableItem(uniqueIdentifier: "move:\(m.name)",
                                              domainIdentifier: domain,
                                              attributeSet: a))
            }

            for f in foods {
                let a = CSSearchableItemAttributeSet(contentType: .text)
                a.title = f.name
                a.contentDescription = f.macroLine
                a.keywords = [f.name, f.group] + (f.brand.isEmpty ? [] : [f.brand])
                items.append(CSSearchableItem(uniqueIdentifier: "food:\(f.name)",
                                              domainIdentifier: domain,
                                              attributeSet: a))
            }

            for p in plans {
                let a = CSSearchableItemAttributeSet(contentType: .text)
                a.title = p.name
                let days = p.days.map { "\($0.title)" }.joined(separator: " / ")
                a.contentDescription = "\(p.days.count) 天 · \(days)"
                a.keywords = [p.name, "训练计划", "计划"] + p.days.map { $0.title }
                items.append(CSSearchableItem(uniqueIdentifier: "plan:\(p.name)",
                                              domainIdentifier: domain,
                                              attributeSet: a))
            }

            // 900 多条一次塞会超时，分批来
            let chunk = 200
            var i = 0
            while i < items.count {
                let part = Array(items[i..<min(i + chunk, items.count)])
                CSSearchableIndex.default().indexSearchableItems(part) { _ in }
                i += chunk
            }
            UserDefaults.standard.set(items.count, forKey: countKey)
        }
    }
}

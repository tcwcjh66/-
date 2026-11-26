import Foundation

/// 用户确认过的「读到的字 → 哪款食物」记在本地，下次同一张包装直接命中。
/// 库再全也追不上每个人的零食柜，这一层才是越用越准的关键。
enum FoodLearn {
    private static let key = "tw.foodlearn.v1"

    static func snapshot() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
    }

    static func lookup(_ word: String) -> String? {
        snapshot()[word]
    }

    /// 只在用户真的把这条记进餐食时调用，避免误学
    static func remember(word: String, food: String) {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard w.count >= 2, w.count <= 16, !food.isEmpty else { return }
        var map = snapshot()
        if map[w] == food { return }
        map[w] = food
        UserDefaults.standard.set(map, forKey: key)
    }

    static var count: Int { snapshot().count }

    static func forgetAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

import Foundation

struct FoodScore {
    let food: LocalFood
    let score: Double
    let reason: String
}

/// 用户嘴里说的和库里写的不一样：
/// 「乐事原味薯片 70g」库里叫「乐事薯片原味」，「蜜雪柠檬水」库里叫「蜜雪冰城柠檬水」。
/// 这里先剥掉规格数量，再按「字覆盖 + 包含 + 别名 + 品牌」综合打分，而不是要求一字不差。
enum FoodRank {
    struct Query {
        var name: String
        var grams: Double?
        var packs: Int
    }

    private static let unitMap: [String: Double] = [
        "kg": 1000, "千克": 1000, "公斤": 1000,
        "g": 1, "克": 1,
        "ml": 1, "毫升": 1,
        "l": 1000, "升": 1000,
        "斤": 500, "两": 50
    ]

    static func clean(_ raw: String) -> String {
        var s = raw
        for ch in [" ", "　", "：", ":", "·", "\n", "、", "，", ",", "；", ";",
                   "（", "）", "(", ")", "【", "】", "\t"] {
            s = s.replacingOccurrences(of: ch, with: "")
        }
        return s
    }

    /// 从一句人话里剥出「名字 + 克数 + 几袋」
    static func parse(_ raw: String) -> Query {
        let c = clean(raw)
        guard !c.isEmpty else { return Query(name: "", grams: nil, packs: 1) }

        var name = c
        var grams: Double?
        var packs = 1

        if let re = try? NSRegularExpression(
            pattern: "(\\d+(?:\\.\\d+)?)(kg|千克|公斤|ml|毫升|g|克|升|l|斤|两)",
            options: [.caseInsensitive]) {
            let ns = c as NSString
            for m in re.matches(in: c, range: NSRange(location: 0, length: ns.length)) {
                let num = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let unit = ns.substring(with: m.range(at: 2)).lowercased()
                if grams == nil, num > 0 { grams = num * (unitMap[unit] ?? 1) }
                name = name.replacingOccurrences(of: ns.substring(with: m.range), with: "")
            }
        }

        if let re = try? NSRegularExpression(
            pattern: "(\\d+)(袋|包|瓶|盒|杯|根|片|块|个|份|条|罐|桶)") {
            let ns = c as NSString
            for m in re.matches(in: c, range: NSRange(location: 0, length: ns.length)) {
                if let n = Int(ns.substring(with: m.range(at: 1))), n > 0, n < 20 { packs = n }
                name = name.replacingOccurrences(of: ns.substring(with: m.range), with: "")
            }
        }

        for w in ["净含量", "净重", "规格", "大约", "大概"] {
            name = name.replacingOccurrences(of: w, with: "")
        }
        while name.hasPrefix("的") || name.hasPrefix("约") || name.hasPrefix("一") {
            name.removeFirst()
        }
        while name.hasSuffix("的") || name.hasSuffix("装") {
            name.removeLast()
        }

        if name.count < 2 { name = c }
        return Query(name: name, grams: grams, packs: packs)
    }

    /// 按「用户会怎么说」排序，不要求库里有一模一样的名字
    static func rank(_ raw: String, limit: Int = 8) -> [FoodScore] {
        let q = parse(raw)
        let key = (q.name.isEmpty ? clean(raw) : q.name).lowercased()
        guard key.count >= 2 else { return [] }

        let keyChars = Set(key)
        var out: [FoodScore] = []

        for f in FoodBase.items {
            let name = f.name.lowercased()
            let nameChars = Set(name)
            let inter = nameChars.intersection(keyChars).count
            let cover = Double(inter) / Double(max(1, nameChars.count))
            let prec = Double(inter) / Double(max(1, keyChars.count))
            var s = 0.0
            var why = ""

            if name == key {
                s = 100
                why = "名字对得上"
            } else if let al = f.aliases.first(where: { clean($0).lowercased() == key }) {
                s = 94
                why = "命中别名「\(al)」"
            } else if let al = f.aliases.first(where: {
                let a = clean($0).lowercased()
                return a.count >= 2 && (key.contains(a) || a.contains(key))
            }) {
                // 别名是弱线索（只说了品牌），靠「用户说的字被这一条覆盖多少」区分具体款
                s = (key.count <= 2 ? 60 : 66) + 26 * prec
                why = "命中别名「\(al)」"
            } else if name.contains(key) {
                s = 80 + 8 * prec
                why = "库里名字含这句"
            } else if key.contains(name) {
                s = 50 + 24 * cover + 14 * prec
                why = "这句里有这一条"
            } else if cover >= 0.75, prec >= 0.5 {
                s = 44 + 26 * cover + 12 * prec
                why = "字基本对得上"
            } else {
                continue
            }

            if !f.brand.isEmpty, key.contains(f.brand.lowercased()) { s += 6 }
            // 名字长度越接近越可能是用户要的那一款，泛名排后面
            s += max(0, 6 - Double(abs(name.count - key.count)) * 1.5)

            out.append(FoodScore(food: f, score: min(100, s), reason: why))
        }

        out.sort { a, b in
            if abs(a.score - b.score) < 0.5 { return a.food.name.count < b.food.name.count }
            return a.score > b.score
        }
        return Array(out.prefix(limit))
    }
}

import Foundation

/// 一张门禁卡：卡号是真正有用的信息，物业那边就认这个号
struct AccessCard: Codable, Identifiable, Hashable {
    var id = UUID()
    var code: String
    var alias: String
    var note: String = ""
    var at: Date = Date()
}

final class AccessCardStore: ObservableObject {
    static let shared = AccessCardStore()

    private let key = "tw.accesscards.v1"
    @Published private(set) var cards: [AccessCard] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let list = try? JSONDecoder().decode([AccessCard].self, from: data) {
            cards = list
        }
    }

    @discardableResult
    func add(code: String, alias: String, note: String) -> Bool {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard c.count >= 6 else { return false }
        guard !cards.contains(where: { $0.code == c }) else { return false }
        var list = cards
        list.insert(AccessCard(code: c,
                               alias: alias.trimmingCharacters(in: .whitespaces).isEmpty ? "门禁" : alias,
                               note: note), at: 0)
        cards = list
        persist()
        return true
    }

    func remove(_ id: UUID) {
        cards.removeAll { $0.id == id }
        persist()
    }

    func rename(_ id: UUID, alias: String, note: String) {
        guard let i = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[i].alias = alias
        cards[i].note = note
        persist()
    }

    /// 给物业的申请话术，直接复制发给对方
    func requestText(_ c: AccessCard) -> String {
        var s = "你好，麻烦帮我把门禁卡录入系统：卡号 \(c.code)"
        if c.alias != "门禁" { s += "（\(c.alias)）" }
        if !c.note.isEmpty { s += "，备注：\(c.note)" }
        s += "。谢谢。"
        return s
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cards) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

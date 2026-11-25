import Foundation
import UIKit

/// 联网食物数据：Open Food Facts（开放、免费、不需要 key）。
/// 包装食品有条形码的，这里拿到的就是厂商申报的官方营养成分和配料表 —— 这才是"精确"。
struct RemoteFood: Identifiable, Hashable {
    var id = UUID()
    var code: String
    var name: String
    var brand: String
    var kcal100: Double
    var protein100: Double
    var carb100: Double
    var fat100: Double
    var fiber100: Double
    var sugar100: Double
    var salt100: Double
    var ingredients: String
    var imageURL: String
    var servingGrams: Double
    var quantity: String

    /// 每 100g 概览
    var macroLine: String {
        String(format: "每100g  热量 %.0f kcal · 蛋白 %.1f · 碳水 %.1f · 脂肪 %.1f",
               kcal100, protein100, carb100, fat100)
    }
}

enum FoodWebError: LocalizedError {
    case offline
    case notFound
    case badData

    var errorDescription: String? {
        switch self {
        case .offline:  return "网络不通，先看看 Wi-Fi / 蜂窝"
        case .notFound: return "这个条码在库里没有记录"
        case .badData:  return "返回的数据解析不了"
        }
    }
}

enum FoodWeb {
    private static let base = "https://world.openfoodfacts.org"
    private static let fieldList = "code,product_name,product_name_zh,brands,brands_zh,nutriments,ingredients_text,ingredients_text_zh,serving_quantity,quantity,image_front_small_url,image_small_url"

    // MARK: - 关键词搜索

    static func search(_ keyword: String, pageSize: Int = 24) async throws -> [RemoteFood] {
        let q = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        var comps = URLComponents(string: base + "/cgi/search.pl")!
        comps.queryItems = [
            .init(name: "search_terms", value: q),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: "\(pageSize)"),
            .init(name: "fields", value: fieldList)
        ]
        guard let url = comps.url else { throw FoodWebError.badData }

        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("TianCaiWei/3.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FoodWebError.offline
        }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = root["products"] as? [[String: Any]] else {
            throw FoodWebError.badData
        }

        return list.compactMap { parse($0) }
    }

    // MARK: - 条码

    static func barcode(_ code: String) async throws -> RemoteFood {
        let clean = code.filter { $0.isNumber }
        guard !clean.isEmpty else { throw FoodWebError.badData }

        var comps = URLComponents(string: base + "/api/v2/product/" + clean + ".json")!
        comps.queryItems = [.init(name: "fields", value: fieldList)]
        guard let url = comps.url else { throw FoodWebError.badData }

        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        req.setValue("TianCaiWei/3.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FoodWebError.badData
        }
        guard let p = root["product"] as? [String: Any] else { throw FoodWebError.notFound }
        guard let food = parse(p) else { throw FoodWebError.notFound }
        return food
    }

    // MARK: - 解析

    private static func parse(_ p: [String: Any]) -> RemoteFood? {
        let name = str(p["product_name_zh"]).isEmpty ? str(p["product_name"]) : str(p["product_name_zh"])
        guard !name.isEmpty else { return nil }

        let brand = str(p["brands_zh"]).isEmpty ? str(p["brands"]) : str(p["brands_zh"])
        let n = p["nutriments"] as? [String: Any] ?? [:]

        let kcal = num(n["energy-kcal_100g"]) ?? {
            // 有些产品只给千焦
            if let kj = num(n["energy_100g"]) { return kj / 4.184 }
            return nil
        }() ?? 0

        // 只有带热量或三大营养素的才留下，避免全是空壳
        let protein = num(n["proteins_100g"]) ?? 0
        let carb = num(n["carbohydrates_100g"]) ?? 0
        let fat = num(n["fat_100g"]) ?? 0
        guard kcal > 0 || protein + carb + fat > 0 else { return nil }

        let ingredients = str(p["ingredients_text_zh"]).isEmpty
            ? str(p["ingredients_text"])
            : str(p["ingredients_text_zh"])

        return RemoteFood(
            code: str(p["code"]),
            name: name,
            brand: brand,
            kcal100: kcal,
            protein100: protein,
            carb100: carb,
            fat100: fat,
            fiber100: num(n["fiber_100g"]) ?? 0,
            sugar100: num(n["sugars_100g"]) ?? 0,
            salt100: num(n["salt_100g"]) ?? 0,
            ingredients: ingredients,
            imageURL: str(p["image_front_small_url"]).isEmpty ? str(p["image_small_url"]) : str(p["image_front_small_url"]),
            servingGrams: num(p["serving_quantity"]) ?? 0,
            quantity: str(p["quantity"])
        )
    }

    private static func str(_ v: Any?) -> String {
        if let s = v as? String { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let a = v as? [String] { return a.joined(separator: " / ") }
        return ""
    }

    private static func num(_ v: Any?) -> Double? {
        if let d = v as? Double { return d }
        if let i = v as? Int { return Double(i) }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}

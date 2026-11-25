import Foundation

// MARK: - 一条对话消息
struct AIMsg: Identifiable {
    var id = UUID()
    var role: String          // "system" / "user" / "assistant"
    var text: String
    var at = Date()
}

// MARK: - 服务商
enum AIProvider: String, CaseIterable, Identifiable {
    case doubao, deepseek, openai, moonshot, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .doubao:   return "豆包"
        case .deepseek: return "DeepSeek"
        case .openai:   return "OpenAI"
        case .moonshot: return "Kimi"
        case .custom:   return "自定义"
        }
    }

    var baseURL: String {
        switch self {
        case .doubao:   return "https://ark.cn-beijing.volces.com/api/v3"
        case .deepseek: return "https://api.deepseek.com/v1"
        case .openai:   return "https://api.openai.com/v1"
        case .moonshot: return "https://api.moonshot.cn/v1"
        case .custom:   return ""
        }
    }

    var model: String {
        switch self {
        case .doubao:   return "doubao-seed-2-1-pro-260915"
        case .deepseek: return "deepseek-chat"
        case .openai:   return "gpt-4o-mini"
        case .moonshot: return "moonshot-v1-8k"
        case .custom:   return ""
        }
    }

    var hint: String {
        switch self {
        case .doubao:   return "ark.volcengine.com 控制台创建 API Key，实名后送免费额度"
        case .deepseek: return "platform.deepseek.com 注册即送额度，Key 以 sk- 开头"
        case .openai:   return "platform.openai.com 生成 Key，按用量计费"
        case .moonshot: return "platform.moonshot.cn 生成 Key"
        case .custom:   return "任何兼容 OpenAI /chat/completions 的地址"
        }
    }

    var pricing: String {
        switch self {
        case .doubao:   return "有免费额度 · 之后按 token 计费"
        case .deepseek: return "有免费额度 · 之后约 ¥1 / 百万字"
        case .openai:   return "按量计费 · gpt-4o-mini 约 ¥0.001 / 次"
        case .moonshot: return "注册送额度 · 之后按量计费"
        case .custom:   return "取决于你的服务商"
        }
    }
}

// MARK: - 错误
enum AIError: LocalizedError {
    case notConfigured
    case badURL
    case http(Int, String)
    case decode
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:      return "还没填 API Key"
        case .badURL:             return "接口地址不正确"
        case .http(let c, let m): return "接口返回 \(c)：\(m)"
        case .decode:             return "返回内容解读失败"
        case .network(let m):     return "网络错误：\(m)"
        }
    }
}

// MARK: - 客户端
final class AIClient {
    static let shared = AIClient()

    private let kKey   = "tw.ai.key.v2"
    private let kProv  = "tw.ai.provider.v2"
    private let kURL   = "tw.ai.baseurl.v2"
    private let kModel = "tw.ai.model.v2"

    var provider: AIProvider {
        get { AIProvider(rawValue: UserDefaults.standard.string(forKey: kProv) ?? "") ?? .doubao }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: kProv) }
    }

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: kKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kKey) }
    }

    /// 自定义地址；留空则用所选服务商默认
    var baseURLRaw: String {
        get { UserDefaults.standard.string(forKey: kURL) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kURL) }
    }

    var baseURL: String {
        let custom = baseURLRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? provider.baseURL : custom
    }

    var modelRaw: String {
        get { UserDefaults.standard.string(forKey: kModel) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: kModel) }
    }

    var model: String {
        let custom = modelRaw.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? provider.model : custom
    }

    var ready: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !baseURL.isEmpty
            && !model.isEmpty
    }

    /// 最近一次连通测试结果，nil = 没测过
    var lastProbeNote: String {
        get { UserDefaults.standard.string(forKey: "tw.ai.probe.v2") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tw.ai.probe.v2") }
    }

    func chat(_ msgs: [AIMsg]) async throws -> String {
        guard ready else { throw AIError.notConfigured }

        let base = trimSlash(baseURL)
        guard let url = URL(string: base + "/chat/completions") else { throw AIError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 55
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                     forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": msgs.map { ["role": $0.role, "content": $0.text] },
            "temperature": 0.6,
            "max_tokens": 700
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw AIError.decode }
            guard (200..<300).contains(http.statusCode) else {
                let s = String(data: data, encoding: .utf8) ?? ""
                throw AIError.http(http.statusCode, String(s.prefix(200)))
            }
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = obj["choices"] as? [[String: Any]],
               let first = choices.first,
               let msg = first["message"] as? [String: Any],
               let content = msg["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw AIError.decode
        } catch let e as AIError {
            throw e
        } catch {
            throw AIError.network(error.localizedDescription)
        }
    }

    private func trimSlash(_ s: String) -> String {
        var v = s.trimmingCharacters(in: .whitespacesAndNewlines)
        while v.hasSuffix("/") { v.removeLast() }
        return v
    }
}

// MARK: - 给 AI 的当日上下文
extension TWStore {
    var aiBrief: String {
        var parts: [String] = []
        parts.append("今天已摄入 \(Int(dietKcal)) kcal，目标 \(Int(dietTarget)) kcal，还剩 \(max(0, Int(dietTarget - dietKcal)))")
        parts.append("蛋白 \(Int(protein))g / 碳水 \(Int(carb))g / 脂肪 \(Int(fat))g / 蔬菜 \(Int(veg))g")
        parts.append("饮水 \(waterML) ml，目标 \(waterTargetML) ml")
        if exerciseMin > 0 || moveKcal > 0 {
            parts.append("今日运动 \(Int(exerciseMin)) 分钟，消耗 \(Int(moveKcal)) kcal，站立 \(Int(standHours)) 小时")
        }
        if watchSteps > 0 { parts.append("步数 \(watchSteps)") }
        if let s = lastSleep {
            parts.append("昨晚睡眠 \(s.durationMinutes) 分钟，评分 \(s.score)（\(s.scoreLabel)）")
            parts.append("近 7 天睡眠欠账 \(sleepDebt) 分钟，今晚建议睡 \(sleepTonightMin) 分钟")
        }
        if bodyWeight > 0 {
            parts.append("体重 \(String(format: "%.1f", bodyWeight)) kg，BMI \(String(format: "%.1f", bmi))")
        }
        if measuredHR > 0 { parts.append("最近心率 \(measuredHR) bpm，HRV \(measuredHRV)") }
        parts.append("当前心情 \(mood)")
        return parts.joined(separator: "；")
    }

    var aiSystemPrompt: String {
        """
        你是「天才威」App 里的私人健身营养教练，说话直接、像教练不像客服。
        只能回答健身、营养、饮食、训练动作、恢复、睡眠、体重管理相关的问题；问到无关话题时用一句话礼貌带过，然后拉回训练话题。
        回答要求：中文；不超过 150 字；不要用 Markdown 标题和表格；分点最多 4 条；不要编造数据。
        用户当天真实数据如下：\(aiBrief)
        给建议时要具体到数字（多少克、多少杯、几组几次），不要泛泛地说"注意饮食""多运动"。
        """
    }
}

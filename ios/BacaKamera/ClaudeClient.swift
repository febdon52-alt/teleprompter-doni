import Foundation

enum ClaudeError: LocalizedError {
    case network
    case http(Int, String)
    case refused
    case empty

    var errorDescription: String? {
        switch self {
        case .network: return "Tidak bisa terhubung ke Anthropic. Cek koneksi internet."
        case .refused: return "Claude menolak topik ini. Coba ubah topiknya."
        case .empty: return "Claude tidak memberi jawaban. Coba lagi."
        case .http(let code, let msg):
            switch code {
            case 401: return "API key salah atau sudah dicabut."
            case 403: return "API key tidak punya akses ke model ini."
            case 429: return "Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi."
            case 529: return "Server Claude sedang sibuk. Coba lagi sebentar lagi."
            default: return msg.isEmpty ? "Galat \(code)" : msg
            }
        }
    }
}

/// Memanggil Messages API langsung dari iPhone memakai API key Anda sendiri.
struct ClaudeClient {
    let apiKey: String
    let model: String

    func complete(_ prompt: String, effort: String = "medium", maxTokens: Int = 6000) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "output_config": ["effort": effort],
            "messages": [["role": "user", "content": prompt]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result: (Data, URLResponse)
        do { result = try await URLSession.shared.data(for: req) }
        catch { throw ClaudeError.network }
        let data = result.0
        let resp = result.1

        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(code) else {
            let msg = ((json["error"] as? [String: Any])?["message"] as? String) ?? ""
            throw ClaudeError.http(code, msg)
        }
        if (json["stop_reason"] as? String) == "refusal" { throw ClaudeError.refused }
        let blocks = json["content"] as? [[String: Any]] ?? []
        var joined = ""
        for block in blocks where (block["type"] as? String) == "text" {
            joined += (block["text"] as? String) ?? ""
        }
        let text = joined.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw ClaudeError.empty }
        return text
    }

    func ideas(_ brief: Brief) async throws -> [Idea] {
        let text = try await complete(IdeaEngine.ideaPrompt(brief), effort: "low")
        let list = IdeaEngine.parseIdeas(text, brief: brief)
        if list.isEmpty { throw ClaudeError.empty }
        return list
    }

    func script(_ idea: Idea) async throws -> String {
        let text = try await complete(IdeaEngine.scriptPrompt(idea), effort: "medium")
        return text.replacingOccurrences(of: "**", with: "")
    }
}

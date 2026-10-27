import Foundation

enum AIError: LocalizedError {
    case missingKey(Provider)
    case http(Int, String)
    case refused
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider):
            return "No \(provider.displayName) API key set. Open Settings (⌘,) and paste your key."
        case .http(let code, let body): return "HTTP \(code): \(body)"
        case .refused: return "The model declined to respond to this text."
        case .api(let msg): return msg
        }
    }
}

struct AIClient {
    static func systemPrompt(tone: Tone) -> String { """
    You are a careful proofreader. The user will paste a message they intend to send. \
    Proofread it and suggest improvements.

    Respond in exactly this format:

    **Corrected version**
    <the full message with spelling, grammar, punctuation, and clarity fixes applied. \
    \(tone.instruction)>

    **Suggestions**
    - <short bullet for each notable change or further improvement, and why>

    If the text is already good, say so briefly under Suggestions. \
    Do not add any preamble or closing remarks.
    """ }

    let provider: Provider
    let apiKey: String
    let model: String
    let tone: Tone

    /// Streams the proofreading response, yielding text chunks as they arrive.
    func proofread(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: makeRequest(text))
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status != 200 {
                        var errBody = ""
                        for try await line in bytes.lines { errBody += line }
                        throw AIError.http(status, Self.errorMessage(from: errBody))
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let data = Data(line.dropFirst(6).utf8)
                        guard let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                        if let chunk = try parse(event) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Per-provider request and stream format

    private func makeRequest(_ text: String) throws -> URLRequest {
        let system = Self.systemPrompt(tone: tone)
        var request: URLRequest
        let body: [String: Any]

        switch provider {
        case .anthropic:
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
            request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
            body = [
                "model": model,
                "max_tokens": 16000,
                "stream": true,
                "fallbacks": "default",
                "output_config": ["effort": "low"],
                "system": system,
                "messages": [["role": "user", "content": text]],
            ]

        case .openai:
            request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
            body = [
                "model": model,
                "stream": true,
                "instructions": system,
                "input": text,
            ]

        case .gemini:
            let path = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse"
            request = URLRequest(url: URL(string: path)!)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            body = [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["role": "user", "parts": [["text": text]]]],
            ]
        }

        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Returns the text in one SSE event, nil for events with no text, or throws on a stream error.
    private func parse(_ event: [String: Any]) throws -> String? {
        switch provider {
        case .anthropic:
            switch event["type"] as? String {
            case "content_block_delta":
                let delta = event["delta"] as? [String: Any]
                return delta?["type"] as? String == "text_delta" ? delta?["text"] as? String : nil
            case "message_delta":
                if (event["delta"] as? [String: Any])?["stop_reason"] as? String == "refusal" { throw AIError.refused }
            case "error":
                throw AIError.api((event["error"] as? [String: Any])?["message"] as? String ?? "Unknown error")
            default: break
            }

        case .openai:
            switch event["type"] as? String {
            case "response.output_text.delta":
                return event["delta"] as? String
            case "response.refusal.delta":
                throw AIError.refused
            case "error":
                throw AIError.api(event["message"] as? String ?? "Unknown error")
            case "response.failed":
                let error = (event["response"] as? [String: Any])?["error"] as? [String: Any]
                throw AIError.api(error?["message"] as? String ?? "The request failed.")
            default: break
            }

        case .gemini:
            if let error = event["error"] as? [String: Any] {
                throw AIError.api(error["message"] as? String ?? "Unknown error")
            }
            guard let candidate = (event["candidates"] as? [[String: Any]])?.first else { return nil }
            if candidate["finishReason"] as? String == "SAFETY" { throw AIError.refused }
            let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
            // Skip thought-summary parts; only the answer text is shown.
            let text = parts.filter { $0["thought"] as? Bool != true }.compactMap { $0["text"] as? String }.joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }

    // MARK: - Model listing

    /// Fetches the models available to this key, for the Settings model menu.
    static func listModels(provider: Provider, apiKey: String) async throws -> [String] {
        var request: URLRequest
        switch provider {
        case .anthropic:
            request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1000")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        case .openai:
            request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "authorization")
        case .gemini:
            request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000")!)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw AIError.http(status, errorMessage(from: String(decoding: data, as: UTF8.self)))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        switch provider {
        case .anthropic:
            return (json["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        case .openai:
            // The list includes image, audio, and embedding models; keep the GPT text models.
            return (json["data"] as? [[String: Any]] ?? [])
                .compactMap { $0["id"] as? String }
                .filter { $0.hasPrefix("gpt-") && !["audio", "realtime", "transcribe", "tts", "image", "search"].contains(where: $0.contains) }
                .sorted(by: >)
        case .gemini:
            return (json["models"] as? [[String: Any]] ?? [])
                .filter { ($0["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true }
                .compactMap { ($0["name"] as? String)?.replacingOccurrences(of: "models/", with: "") }
                .filter { $0.hasPrefix("gemini") }
                .sorted(by: >)
        }
    }

    private static func errorMessage(from body: String) -> String {
        // All three providers nest the message under "error"; Gemini's stream endpoint wraps it in an array.
        let json = try? JSONSerialization.jsonObject(with: Data(body.utf8))
        let object = (json as? [String: Any]) ?? (json as? [[String: Any]])?.first
        return (object?["error"] as? [String: Any])?["message"] as? String ?? body
    }
}

import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case anthropic, openai, gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-opus-5-5"
        case .openai: return "gpt-6.1-terra"
        case .gemini: return "gemini-3.6-flash"
        }
    }

    /// Shown in the model menu until the user fetches the live list.
    var suggestedModels: [String] {
        switch self {
        case .anthropic: return ["claude-opus-5-5", "claude-sonnet-5-5", "claude-haiku-5-5"]
        case .openai: return ["gpt-6.1-sol", "gpt-6.1-terra", "gpt-6-luna"]
        case .gemini: return ["gemini-3.6-flash", "gemini-3.5-flash-lite", "gemini-3.1-pro-preview"]
        }
    }

    var envVar: String {
        switch self {
        case .anthropic: return "ANTHROPIC_API_KEY"
        case .openai: return "OPENAI_API_KEY"
        case .gemini: return "GEMINI_API_KEY"
        }
    }

    var keyURL: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    // MARK: - Persisted settings

    static var current: Provider {
        Provider(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "") ?? .anthropic
    }

    var modelDefaultsKey: String { "model.\(rawValue)" }

    var model: String {
        let saved = UserDefaults.standard.string(forKey: modelDefaultsKey) ?? ""
        return saved.isEmpty ? defaultModel : saved
    }

    var apiKey: String? {
        if let key = KeyStore.load(keyName), !key.isEmpty { return key }
        if let key = ProcessInfo.processInfo.environment[envVar], !key.isEmpty { return key }
        return nil
    }

    var keyName: String { rawValue }
}

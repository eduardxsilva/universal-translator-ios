import Foundation

public enum ProviderOption: String, CaseIterable, Codable, Identifiable {
    case autoGTX = "google_gtx"
    case deepl = "deepl"
    case openai = "openai"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .autoGTX: return "AutomÃ¡tico Neural (Sem Chave)"
        case .deepl: return "DeepL API (Free / Pro)"
        case .openai: return "OpenAI (GPT-4o-mini)"
        }
    }
}

public struct LanguageOption: Identifiable, Hashable, Codable {
    public let name: String
    public let code: String
    public var id: String { code }

    public static let supported: [LanguageOption] = [
        LanguageOption(name: "PortuguÃªs (Brasil)", code: "PT-BR"),
        LanguageOption(name: "English (EUA)", code: "EN-US"),
        LanguageOption(name: "English (Reino Unido)", code: "EN-GB"),
        LanguageOption(name: "EspaÃ±ol", code: "ES"),
        LanguageOption(name: "FranÃ§ais", code: "FR"),
        LanguageOption(name: "Deutsch", code: "DE"),
        LanguageOption(name: "Italiano", code: "IT"),
        LanguageOption(name: "æ—¥æœ¬èªž", code: "JA"),
        LanguageOption(name: "ä¸­æ–‡ (Simplificado)", code: "ZH")
    ]

    public static func name(for code: String) -> String {
        let prefix = code.uppercased().split(separator: "-").first.map(String.init) ?? code.uppercased()
        return supported.first(where: { $0.code.uppercased() == code.uppercased() })?.name
            ?? supported.first(where: { $0.code.uppercased().hasPrefix(prefix) })?.name
            ?? "PortuguÃªs (Brasil)"
    }
}

public struct GlossaryItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var sourceTerm: String
    public var targetTerm: String
    public var doNotTranslate: Bool = false
    public var enabled: Bool = true

    public init(id: UUID = UUID(), sourceTerm: String, targetTerm: String, doNotTranslate: Bool = false, enabled: Bool = true) {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.doNotTranslate = doNotTranslate
        self.enabled = enabled
    }
}

public struct TranslationHistoryItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var sourceText: String
    public var translatedText: String
    public var sourceLang: String
    public var targetLang: String
    public var provider: String
    public var cached: Bool
    public var createdAt: Date = Date()
}

public struct TranslationOutput: Codable {
    public let translatedText: String
    public let detectedSourceLang: String
    public let targetLang: String
    public let provider: String
    public let cached: Bool
    public let latencyMs: Double
}


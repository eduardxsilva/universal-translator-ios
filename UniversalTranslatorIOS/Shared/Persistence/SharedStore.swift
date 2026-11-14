import Foundation
import CryptoKit

/// Armazenamento local compartilhado via App Group entre o App iOS, o Teclado Customizado e os Atalhos (AppIntents).
public final class SharedStore: ObservableObject {
    public static let shared = SharedStore()
    public static let appGroupIdentifier = "group.com.universaltranslator.shared"

    private let defaults: UserDefaults

    @Published public var sourceLangCode: String {
        didSet { defaults.set(sourceLangCode, forKey: "sourceLangCode") }
    }
    @Published public var targetLangCode: String {
        didSet { defaults.set(targetLangCode, forKey: "targetLangCode") }
    }
    @Published public var activeProvider: ProviderOption {
        didSet { defaults.set(activeProvider.rawValue, forKey: "activeProvider") }
    }
    @Published public var showFloatingKeyboardBar: Bool {
        didSet { defaults.set(showFloatingKeyboardBar, forKey: "showFloatingKeyboardBar") }
    }
    @Published public var privacyNoHistory: Bool {
        didSet { defaults.set(privacyNoHistory, forKey: "privacyNoHistory") }
    }
    @Published public var glossary: [GlossaryItem] = [] {
        didSet { saveCodable(glossary, forKey: "glossary_v2") }
    }
    @Published public var history: [TranslationHistoryItem] = [] {
        didSet { saveCodable(history, forKey: "history_v2") }
    }

    private var cache: [String: TranslationOutput] = [:]

    private init() {
        self.defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        self.sourceLangCode = defaults.string(forKey: "sourceLangCode") ?? "PT-BR"
        self.targetLangCode = defaults.string(forKey: "targetLangCode") ?? "EN-US"
        let provRaw = defaults.string(forKey: "activeProvider") ?? ProviderOption.autoGTX.rawValue
        self.activeProvider = ProviderOption(rawValue: provRaw) ?? .autoGTX
        self.showFloatingKeyboardBar = defaults.object(forKey: "showFloatingKeyboardBar") as? Bool ?? true
        self.privacyNoHistory = defaults.bool(forKey: "privacyNoHistory")

        if let savedGlossary: [GlossaryItem] = loadCodable(forKey: "glossary_v2"), !savedGlossary.isEmpty {
            self.glossary = savedGlossary
        } else {
            self.glossary = [
                GlossaryItem(sourceTerm: "áreas contaminadas", targetTerm: "contaminated sites"),
                GlossaryItem(sourceTerm: "EQuIS", targetTerm: "EQuIS", doNotTranslate: true),
                GlossaryItem(sourceTerm: "CETESB", targetTerm: "CETESB", doNotTranslate: true)
            ]
        }

        self.history = loadCodable(forKey: "history_v2") ?? []
        self.cache = loadCodable(forKey: "sha256_cache_v2") ?? [:]
    }

    public static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func getCached(_ key: String) -> TranslationOutput? {
        return cache[key]
    }

    public func setCached(_ key: String, output: TranslationOutput) {
        cache[key] = output
        saveCodable(cache, forKey: "sha256_cache_v2")
    }

    public func appendHistory(_ item: TranslationHistoryItem) {
        guard !privacyNoHistory else { return }
        history.insert(item, at: 0)
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
    }

    public func clearHistory() {
        history.removeAll()
    }

    private func saveCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCodable<T: Decodable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

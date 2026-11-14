import Foundation

/// Motor de tradução assíncrono iOS com Glossário, Detector de Idioma, Cache SHA-256 e Multi-Provedor (DeepL, OpenAI e Google GTX Automático).
public final class TranslationEngine {
    public static let shared = TranslationEngine()
    private let store = SharedStore.shared
    private let keychain = KeychainManager.shared

    private init() {}

    // MARK: - Detecção Rápida de Idioma Local (<1ms)
    public func detectLanguage(_ text: String) -> String {
        let lower = text.lowercased()
        if lower.range(of: "[\\u3040-\\u30ff]", options: .regularExpression) != nil { return "JA" }
        if lower.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil { return "ZH" }

        let ptMarkers = ["você", "voce", "não", "nao", "para", "está", "relatório", "amanhã", "hoje", "muito", "lindo", "topa", "sairmos", "dinheiro", "obrigado", "poderia", "áreas", "contaminadas"]
        let enMarkers = ["the", "and", "you", "for", "with", "that", "have", "this", "could", "tomorrow", "report", "would", "please"]
        let esMarkers = ["usted", "mañana", "gracias", "podría", "informe", "buenos", "días", "hola"]

        var ptScore = 0
        var enScore = 0
        var esScore = 0

        for m in ptMarkers where lower.contains(m) { ptScore += 2 }
        for m in enMarkers where lower.contains(m) { enScore += 2 }
        for m in esMarkers where lower.contains(m) { esScore += 2 }

        if lower.contains("ã") || lower.contains("õ") || lower.contains("ç") || lower.contains("ê") {
            ptScore += 4
        }
        if lower.contains("ñ") || lower.contains("¿") {
            esScore += 4
        }

        if ptScore >= enScore && ptScore >= esScore && ptScore > 0 { return "PT-BR" }
        if esScore > enScore && esScore > ptScore { return "ES" }
        return enScore > 0 ? "EN-US" : store.sourceLangCode
    }

    // MARK: - Pré e Pós-Processamento de Glossário
    private func applyGlossaryPreProcess(_ text: String) -> (String, [String: String]) {
        var working = text
        var tokenMap: [String: String] = [:]
        var counter = 0

        for item in store.glossary where item.enabled && !item.sourceTerm.isEmpty {
            let replacement = item.doNotTranslate ? item.sourceTerm : item.targetTerm
            let token = "__UTGLOSS\(counter)__"
            if let range = working.range(of: item.sourceTerm, options: [.caseInsensitive]) {
                working.replaceSubrange(range, with: token)
                tokenMap[token] = replacement
                counter += 1
            }
        }
        return (working, tokenMap)
    }

    private func applyGlossaryPostProcess(_ text: String, tokenMap: [String: String]) -> String {
        var result = text
        for (token, targetValue) in tokenMap {
            result = result.replacingOccurrences(of: token, with: targetValue, options: .caseInsensitive)
        }
        return result
    }

    // MARK: - Tradução Principal com Fallback Automático
    public func translate(
        text: String,
        sourceLang: String? = nil,
        targetLang: String? = nil
    ) async throws -> TranslationOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "UniversalTranslator", code: 400, userInfo: [NSLocalizedDescriptionKey: "Texto vazio."])
        }

        let detectedSource = sourceLang ?? detectLanguage(trimmed)
        let resolvedTarget = targetLang ?? store.targetLangCode
        let (preparedText, tokenMap) = applyGlossaryPreProcess(trimmed)

        let cacheKey = SharedStore.sha256("\(store.activeProvider.rawValue)|\(detectedSource)|\(resolvedTarget)|\(preparedText)")
        if let cached = store.getCached(cacheKey) {
            let finalCached = applyGlossaryPostProcess(cached.translatedText, tokenMap: tokenMap)
            return TranslationOutput(
                translatedText: finalCached,
                detectedSourceLang: detectedSource,
                targetLang: resolvedTarget,
                provider: cached.provider,
                cached: true,
                latencyMs: 0.5
            )
        }

        let start = CFAbsoluteTimeGetCurrent()
        let rawTranslated: String
        var usedProvider = store.activeProvider.rawValue

        let deeplKey = keychain.getSecret(forKey: "deepl_api_key")
        let openaiKey = keychain.getSecret(forKey: "openai_api_key")

        if store.activeProvider == .deepl && !deeplKey.isEmpty {
            do {
                rawTranslated = try await translateWithDeepL(text: preparedText, sourceLang: detectedSource, targetLang: resolvedTarget, apiKey: deeplKey)
            } catch {
                usedProvider = ProviderOption.autoGTX.rawValue
                rawTranslated = try await translateWithGoogleGTX(text: preparedText, sourceLang: detectedSource, targetLang: resolvedTarget)
            }
        } else if store.activeProvider == .openai && !openaiKey.isEmpty {
            do {
                rawTranslated = try await translateWithOpenAI(text: preparedText, targetLang: resolvedTarget, apiKey: openaiKey)
            } catch {
                usedProvider = ProviderOption.autoGTX.rawValue
                rawTranslated = try await translateWithGoogleGTX(text: preparedText, sourceLang: detectedSource, targetLang: resolvedTarget)
            }
        } else {
            usedProvider = ProviderOption.autoGTX.rawValue
            rawTranslated = try await translateWithGoogleGTX(text: preparedText, sourceLang: detectedSource, targetLang: resolvedTarget)
        }

        let latencyMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        let finalTranslated = applyGlossaryPostProcess(rawTranslated, tokenMap: tokenMap)

        let output = TranslationOutput(
            translatedText: finalTranslated,
            detectedSourceLang: detectedSource,
            targetLang: resolvedTarget,
            provider: usedProvider,
            cached: false,
            latencyMs: latencyMs
        )

        store.setCached(cacheKey, output: output)
        store.appendHistory(
            TranslationHistoryItem(
                sourceText: trimmed,
                translatedText: finalTranslated,
                sourceLang: detectedSource,
                targetLang: resolvedTarget,
                provider: usedProvider,
                cached: false
            )
        )
        return output
    }

    // MARK: - Google GTX Neural (Sem Chave)
    private func translateWithGoogleGTX(text: String, sourceLang: String, targetLang: String) async throws -> String {
        let sl = sourceLang.split(separator: "-").first?.lowercased() ?? "auto"
        let tl = targetLang.split(separator: "-").first?.lowercased() ?? "en"

        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sl == tl ? "auto" : sl),
            URLQueryItem(name: "tl", value: tl),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]

        var req = URLRequest(url: components.url!)
        req.timeoutInterval = 12
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              let segments = root.first as? [[Any]] else {
            throw NSError(domain: "UniversalTranslator", code: 500, userInfo: [NSLocalizedDescriptionKey: "Falha ao interpretar resposta neural."])
        }

        let parts = segments.compactMap { $0.first as? String }
        return parts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - DeepL API
    private func translateWithDeepL(text: String, sourceLang: String, targetLang: String, apiKey: String) async throws -> String {
        let endpoint = apiKey.hasSuffix(":fx")
            ? "https://api-free.deepl.com/v2/translate"
            : "https://api.deepl.com/v2/translate"

        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "target_lang", value: targetLang.uppercased())
        ]
        req.httpBody = form.percentEncodedQuery?.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translations = json["translations"] as? [[String: Any]],
              let resultText = translations.first?["text"] as? String else {
            throw NSError(domain: "UniversalTranslator", code: 502, userInfo: [NSLocalizedDescriptionKey: "Erro na resposta DeepL."])
        }
        return resultText
    }

    // MARK: - OpenAI API
    private func translateWithOpenAI(text: String, targetLang: String, apiKey: String) async throws -> String {
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 18
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.1,
            "messages": [
                ["role": "system", "content": "Translate the user's message strictly into \(targetLang). Preserve any __UTGLOSS0__ tokens. Output ONLY the translation."],
                ["role": "user", "content": text]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "UniversalTranslator", code: 502, userInfo: [NSLocalizedDescriptionKey: "Erro na resposta OpenAI."])
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

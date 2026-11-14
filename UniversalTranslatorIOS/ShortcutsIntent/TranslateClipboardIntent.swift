import AppIntents
import UIKit

/// Integração com Atalhos do iOS (Siri / Action Button / Toque Atrás no iPhone 13):
/// Ao selecionar e copiar um texto em qualquer app, dois toques atrás do iPhone traduzem e atualizam a área de transferência instantaneamente.
@available(iOS 16.0, *)
public struct TranslateClipboardIntent: AppIntent {
    public static var title: LocalizedStringResource = "Traduzir Texto Selecionado / Copiado"
    public static var description = IntentDescription("Traduz automaticamente o texto da área de transferência do iPhone para o idioma pretendido.")
    public static var openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let clipText = UIPasteboard.general.string ?? ""
        guard !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .result(value: "")
        }

        let output = try await TranslationEngine.shared.translate(
            text: clipText,
            sourceLang: nil,
            targetLang: SharedStore.shared.targetLangCode
        )
        UIPasteboard.general.string = output.translatedText
        return .result(value: output.translatedText)
    }
}

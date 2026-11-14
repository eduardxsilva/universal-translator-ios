import UIKit
import SwiftUI

/// Extensão de Teclado iOS (Custom Keyboard Extension) — O equivalente nativo no iPhone ao Botão Flutuante!
/// Funciona dentro do WhatsApp, Instagram Direct, Telegram, iMessage, Discord, Slack e Safari:
/// Exibe exatamente:
/// 1. Botão de Idioma Atual
/// 2. Botão de Idioma Pretendido
/// 3. Botão "Traduzir e Substituir" (lê o texto digitado/selecionado no campo via `textDocumentProxy` ou Clipboard e substitui na hora!)
/// 4. Botão "✕ Fechar" (oculta o painel flutuante ou alterna o teclado)
public final class TranslatorKeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardFloatingBarView>?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)

        let barView = KeyboardFloatingBarView(
            onTranslateAndReplace: { [weak self] in
                await self?.performInlineTranslateAndReplace()
            },
            onCloseKeyboardBar: { [weak self] in
                self?.advanceToNextInputMode()
            }
        )

        let host = UIHostingController(rootView: barView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 195)
        ])

        self.hostingController = host
    }

    @MainActor
    private func performInlineTranslateAndReplace() async {
        let proxy = self.textDocumentProxy

        // 1. Captura texto selecionado no campo do app de chat, ou o texto digitado no campo, ou o texto copiado (Ctrl+C / Copiar)
        var textToTranslate = ""
        var deleteCountBefore = 0
        var usedSelectedText = false

        if let selected = proxy.selectedText, !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            textToTranslate = selected
            usedSelectedText = true
        } else {
            let before = proxy.documentContextBeforeInput ?? ""
            let after = proxy.documentContextAfterInput ?? ""
            let combined = (before + after).trimmingCharacters(in: .whitespacesAndNewlines)
            if !combined.isEmpty {
                textToTranslate = before
                deleteCountBefore = before.count
            } else if let clipboard = UIPasteboard.general.string, !clipboard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                textToTranslate = clipboard
            }
        }

        guard !textToTranslate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let detected = TranslationEngine.shared.detectLanguage(textToTranslate)
        SharedStore.shared.sourceLangCode = detected

        do {
            let output = try await TranslationEngine.shared.translate(
                text: textToTranslate,
                sourceLang: detected,
                targetLang: SharedStore.shared.targetLangCode
            )

            // 2. Substitui o texto diretamente no campo de entrada do aplicativo no iPhone!
            if usedSelectedText {
                proxy.insertText(output.translatedText)
            } else if deleteCountBefore > 0 {
                for _ in 0..<deleteCountBefore {
                    proxy.deleteBackward()
                }
                proxy.insertText(output.translatedText)
            } else {
                proxy.insertText(output.translatedText)
            }

            UIPasteboard.general.string = output.translatedText
        } catch {
            // Mantém o texto original intacto em caso de erro de rede
        }
    }
}

public struct KeyboardFloatingBarView: View {
    @ObservedObject private var store = SharedStore.shared
    @State private var isTranslating = false
    @State private var isMinimized = false

    let onTranslateAndReplace: () async -> Void
    let onCloseKeyboardBar: () -> Void

    public var body: some View {
        VStack(spacing: 8) {
            if isMinimized {
                HStack {
                    Spacer()
                    Button(action: { isMinimized = false }) {
                        Text("文")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, height: 52)
                            .background(Color(red: 0.09, green: 0.64, blue: 0.42))
                            .clipShape(Circle())
                    }
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    // 1. Botão de Idioma Atual
                    Menu {
                        ForEach(LanguageOption.supported) { lang in
                            Button(lang.name) {
                                store.sourceLangCode = lang.code
                            }
                        }
                    } label: {
                        HStack {
                            Text("Idioma atual: \(LanguageOption.name(for: store.sourceLangCode)) ▾")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.95, green: 0.96, blue: 0.97))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(red: 0.20, green: 0.25, blue: 0.33), lineWidth: 1)
                        )
                    }

                    // 2. Botão de Idioma Pretendido
                    Menu {
                        ForEach(LanguageOption.supported) { lang in
                            Button(lang.name) {
                                store.targetLangCode = lang.code
                            }
                        }
                    } label: {
                        HStack {
                            Text("Idioma pretendido: \(LanguageOption.name(for: store.targetLangCode)) ▾")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.95, green: 0.96, blue: 0.97))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                        .cornerRadius(7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color(red: 0.20, green: 0.25, blue: 0.33), lineWidth: 1)
                        )
                    }

                    // 3. Botão de Traduzir e Substituir Texto Selecionado
                    Button(action: {
                        Task {
                            isTranslating = true
                            await onTranslateAndReplace()
                            isTranslating = false
                        }
                    }) {
                        HStack {
                            Spacer()
                            Text(isTranslating ? "Traduzindo e substituindo..." : "Traduzir e Substituir")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .background(isTranslating ? Color.orange : Color(red: 0.09, green: 0.64, blue: 0.42))
                        .cornerRadius(7)
                    }
                    .disabled(isTranslating)

                    // 4. Opção de Fechar / Recolher Botão Flutuante
                    HStack(spacing: 8) {
                        Button(action: { isMinimized = true }) {
                            Text("Recolher para Botão 文")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.82, green: 0.84, blue: 0.87))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                                .cornerRadius(6)
                        }

                        Button(action: onCloseKeyboardBar) {
                            Text("✕ Fechar Flutuante")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.99, green: 0.64, blue: 0.61))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red: 0.85, green: 0.18, blue: 0.13), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(12)
            }
        }
        .background(Color(red: 0.06, green: 0.09, blue: 0.16))
    }
}

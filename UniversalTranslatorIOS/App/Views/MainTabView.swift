import SwiftUI
import UIKit

@main
public struct UniversalTranslatorIOSApp: App {
    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainIOSView()
                .preferredColorScheme(.dark)
        }
    }
}

public struct MainIOSView: View {
    @ObservedObject private var store = SharedStore.shared
    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var showFloatingOverlay: Bool = true
    @State private var deeplKey: String = KeychainManager.shared.getSecret(forKey: "deepl_api_key")
    @State private var openaiKey: String = KeychainManager.shared.getSecret(forKey: "openai_api_key")
    @State private var newGlossarySource: String = ""
    @State private var newGlossaryTarget: String = ""
    @State private var statusBanner: String = "Toque em 'Colar e Traduzir' ou use o Botão Flutuante."

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView {
                translatorTab
                    .tabItem {
                        Label("Tradutor", systemImage: "character.bubble.fill")
                    }

                glossaryTab
                    .tabItem {
                        Label("Glossário", systemImage: "book.closed.fill")
                    }

                historyTab
                    .tabItem {
                        Label("Histórico", systemImage: "clock.arrow.circlepath")
                    }

                settingsTab
                    .tabItem {
                        Label("Ajustes & Teclado", systemImage: "gearshape.fill")
                    }
            }
            .accentColor(Color(red: 0.09, green: 0.64, blue: 0.42))

            // Botão Flutuante iOS com opção de expandir/recolher e fechar
            if store.showFloatingKeyboardBar {
                iosFloatingWidget
                    .padding(.trailing, 16)
                    .padding(.bottom, 64)
            }
        }
    }

    // MARK: - Aba 1: Tradutor Principal
    private var translatorTab: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(statusBanner)
                        .font(.footnote)
                        .foregroundColor(Color(red: 0.82, green: 0.84, blue: 0.87))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Texto Selecionado / Copiado:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $inputText)
                            .frame(height: 110)
                            .padding(8)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                            .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tradução Pronta:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextEditor(text: $translatedText)
                            .frame(height: 110)
                            .padding(8)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                            .cornerRadius(8)
                    }

                    HStack(spacing: 10) {
                        Button(action: pasteAndTranslateClipboard) {
                            Label("Colar do iPhone e Traduzir", systemImage: "doc.on.clipboard")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.15, green: 0.39, blue: 0.92))
                                .cornerRadius(8)
                        }

                        if !store.showFloatingKeyboardBar {
                            Button(action: { store.showFloatingKeyboardBar = true }) {
                                Text("Ativar Flutuante")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(Color(red: 0.09, green: 0.64, blue: 0.42))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(red: 0.06, green: 0.09, blue: 0.16).ignoresSafeArea())
            .navigationTitle("Universal Translator iOS")
        }
    }

    // MARK: - Botão Flutuante iOS (Idêntico ao Desktop: Idioma Atual, Idioma Pretendido, Traduzir e Substituir, e Fechar)
    private var iosFloatingWidget: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if showFloatingOverlay {
                VStack(spacing: 8) {
                    Menu {
                        ForEach(LanguageOption.supported) { lang in
                            Button(lang.name) { store.sourceLangCode = lang.code }
                        }
                    } label: {
                        HStack {
                            Text("Idioma atual: \(LanguageOption.name(for: store.sourceLangCode)) ▾")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                        .cornerRadius(7)
                    }

                    Menu {
                        ForEach(LanguageOption.supported) { lang in
                            Button(lang.name) { store.targetLangCode = lang.code }
                        }
                    } label: {
                        HStack {
                            Text("Idioma pretendido: \(LanguageOption.name(for: store.targetLangCode)) ▾")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                        .cornerRadius(7)
                    }

                    Button(action: translateAndReplaceActiveText) {
                        Text(isTranslating ? "Traduzindo..." : "Traduzir e Substituir")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isTranslating ? Color.orange : Color(red: 0.09, green: 0.64, blue: 0.42))
                            .cornerRadius(7)
                    }
                    .disabled(isTranslating)

                    Button(action: {
                        store.showFloatingKeyboardBar = false
                    }) {
                        Text("✕ Fechar Botão Flutuante")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(red: 0.99, green: 0.64, blue: 0.61))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Color(red: 0.11, green: 0.16, blue: 0.22))
                            .cornerRadius(7)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color(red: 0.85, green: 0.18, blue: 0.13), lineWidth: 1)
                            )
                    }
                }
                .padding(12)
                .frame(width: 285)
                .background(Color(red: 0.06, green: 0.09, blue: 0.16))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.20, green: 0.25, blue: 0.33), lineWidth: 1)
                )
                .shadow(radius: 10)
            }

            Button(action: { withAnimation { showFloatingOverlay.toggle() } }) {
                Text("文")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 58, height: 58)
                    .background(Color(red: 0.09, green: 0.64, blue: 0.42))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 0.05, green: 0.50, blue: 0.32), lineWidth: 2))
                    .shadow(radius: 6)
            }
        }
    }

    // MARK: - Aba 2: Glossário
    private var glossaryTab: some View {
        NavigationView {
            List {
                Section(header: Text("Novo Termo do Glossário")) {
                    TextField("Termo original (ex: áreas contaminadas)", text: $newGlossarySource)
                    TextField("Tradução (ex: contaminated sites)", text: $newGlossaryTarget)
                    Button("Adicionar ao Glossário") {
                        guard !newGlossarySource.isEmpty else { return }
                        let tgt = newGlossaryTarget.isEmpty ? newGlossarySource : newGlossaryTarget
                        store.glossary.append(GlossaryItem(sourceTerm: newGlossarySource, targetTerm: tgt))
                        newGlossarySource = ""
                        newGlossaryTarget = ""
                    }
                }
                Section(header: Text("Termos Ativos")) {
                    ForEach(store.glossary) { item in
                        VStack(alignment: .leading) {
                            Text("\(item.sourceTerm) → \(item.targetTerm)").font(.headline)
                            if item.doNotTranslate {
                                Text("Não traduzir").font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete { offsets in
                        store.glossary.remove(atOffsets: offsets)
                    }
                }
            }
            .navigationTitle("Glossário")
        }
    }

    // MARK: - Aba 3: Histórico
    private var historyTab: some View {
        NavigationView {
            List {
                ForEach(store.history) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.sourceLang) → \(item.targetLang) (\(item.provider.uppercased()))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(item.sourceText).font(.subheadline)
                        Text(item.translatedText).font(.headline).foregroundColor(.green)
                    }
                    .onTapGesture {
                        UIPasteboard.general.string = item.translatedText
                        statusBanner = "Tradução copiada do histórico!"
                    }
                }
            }
            .navigationTitle("Histórico")
            .toolbar {
                Button("Limpar") { store.clearHistory() }
            }
        }
    }

    // MARK: - Aba 4: Ajustes, Keychain e Teclado iOS
    private var settingsTab: some View {
        NavigationView {
            Form {
                Section(header: Text("Provedor e Chaves (iOS Keychain)")) {
                    Picker("Provedor", selection: $store.activeProvider) {
                        ForEach(ProviderOption.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    SecureField("Chave API DeepL (Opcional)", text: $deeplKey)
                    SecureField("Chave API OpenAI (Opcional)", text: $openaiKey)
                    Button("Salvar Chaves no iOS Keychain") {
                        KeychainManager.shared.saveSecret(deeplKey, forKey: "deepl_api_key")
                        KeychainManager.shared.saveSecret(openaiKey, forKey: "openai_api_key")
                        statusBanner = "Chaves salvas com segurança no Keychain do iPhone."
                    }
                }

                Section(header: Text("Botão Flutuante e Privacidade")) {
                    Toggle("Mostrar Botão Flutuante (文)", isOn: $store.showFloatingKeyboardBar)
                    Toggle("Modo sem histórico", isOn: $store.privacyNoHistory)
                }

                Section(header: Text("Como usar em qualquer Chat no iPhone")) {
                    Text("1. Ative o teclado 'Universal Translator' em Ajustes > Geral > Teclado > Teclados.\n2. Ou adicione o Atalho 'Traduzir Texto Copiado' ao 'Toque Atrás' (Ajustes > Acessibilidade > Toque > Tocar Atrás).")
                        .font(.footnote)
                }
            }
            .navigationTitle("Ajustes iOS")
        }
    }

    private func pasteAndTranslateClipboard() {
        if let clip = UIPasteboard.general.string, !clip.isEmpty {
            inputText = clip
            translateAndReplaceActiveText()
        }
    }

    private func translateAndReplaceActiveText() {
        let source = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (UIPasteboard.general.string ?? "")
            : inputText

        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusBanner = "Selecione ou copie um texto primeiro."
            return
        }

        inputText = source
        isTranslating = true
        Task {
            do {
                let res = try await TranslationEngine.shared.translate(
                    text: source,
                    sourceLang: nil,
                    targetLang: store.targetLangCode
                )
                await MainActor.run {
                    store.sourceLangCode = res.detectedSourceLang
                    translatedText = res.translatedText
                    inputText = res.translatedText
                    UIPasteboard.general.string = res.translatedText
                    statusBanner = "Traduzido e copiado (\(res.detectedSourceLang) → \(res.targetLang))! Pronto para colar."
                    isTranslating = false
                }
            } catch {
                await MainActor.run {
                    statusBanner = "Erro: \(error.localizedDescription)"
                    isTranslating = false
                }
            }
        }
    }
}

# Universal Translator Pro — Edição iOS (iPhone)

Este pacote entrega **duas formas completas** de usar o Universal Translator no seu iPhone (incluindo o iPhone 13) a partir do seu PC Windows:

---

## Opção 1: Uso Imediato no iPhone sem precisar de Mac (PWA + Atalho "Toque Atrás")

1. No seu Windows, dê dois cliques em **`INICIAR_SERVIDOR_IOS.bat`**.
2. Ele mostrará na tela o endereço na sua rede Wi-Fi (ex.: `http://192.168.15.10:8765`).
3. No **Safari do iPhone**, abra esse endereço, toque no ícone **Compartilhar** e escolha **"Adicionar à Tela de Início"**.
4. O aplicativo abre em tela cheia no iPhone com o mesmo **Botão Flutuante (`文`)** contendo:
   - **Idioma atual**
   - **Idioma pretendido**
   - **Traduzir e Substituir**
   - **✕ Fechar Botão Flutuante**
5. **Para traduzir dentro do WhatsApp / Instagram / Telegram no iPhone com 2 toques atrás**:
   - Abra o app **Atalhos (Shortcuts)** do iPhone → Crie um novo Atalho chamado **"Traduzir Copiado"**:
     1. Ação **"Obter Área de Transferência"**.
     2. Ação **"Obter Conteúdo de URL"** → URL `http://SEU_IP:8765/api/v1/shortcut`, Método `POST`, Corpo JSON `{"text": [Área de Transferência], "target_lang": "EN-US"}`.
     3. Ação **"Obter Valor de Dicionário"** → chave `translated_text`.
     4. Ação **"Copiar para a Área de Transferência"**.
   - Vá em **Ajustes > Acessibilidade > Toque > Tocar Atrás > Toque Duplo** e selecione **"Traduzir Copiado"**.

---

## Opção 2: App iOS Nativo em SwiftUI + Extensão de Teclado (`UniversalTranslatorIOS/`)

A pasta `UniversalTranslatorIOS/` contém o projeto nativo em **Swift 5.10 / SwiftUI** com:
- **Extensão de Teclado Customizada (`TranslatorKeyboardViewController.swift`)**: funciona dentro de qualquer chat (WhatsApp, Instagram, iMessage, Telegram) usando `UITextDocumentProxy` para ler o texto digitado, traduzir e substituir diretamente no campo de mensagem!
- **iOS Keychain (`KeychainManager.swift`)**: armazenamento seguro via `Security.framework`.
- **Compilador Automático na Nuvem (`.github/workflows/build_ios_ipa.yml`)**: basta subir a pasta para um repositório privado no GitHub; o GitHub Actions (`macos-14`) compila automaticamente o arquivo **`UniversalTranslatorIOS.ipa`** para instalar via Sideloadly ou AltStore sem precisar de um Mac físico.

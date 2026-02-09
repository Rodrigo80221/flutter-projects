# Projeto Flutter para Android TV com Leitor de Código de Barras

Este projeto foi configurado para funcionar em Android TV, com suporte a navegação por controle remoto (D-Pad) e leitura de código de barras via USB (modo HID).

## Como configurar o ambiente

Como o comando `flutter create` não pôde ser executado automaticamente, siga os passos abaixo para completar a configuração:

1.  **Inicialize o projeto Android**:
    Abra o terminal na pasta raiz deste projeto (`QrCodeScanTV`) e execute:
    ```bash
    flutter create . --platforms android
    ```
    Isso criará a pasta `android/` e outros arquivos de configuração necessários.

2.  **Configure o Android Manifest para TV**:
    Após criar o projeto, abra o arquivo `android/app/src/main/AndroidManifest.xml`.
    Adicione as seguintes linhas para declarar suporte a TV e o Leanback Launcher:

    ```xml
    <manifest xmlns:android="http://schemas.android.com/apk/res/android" ...>
        <!-- ADICIONE ISSO: Declaração de recursos de TV -->
        <uses-feature android:name="android.software.leanback" android:required="false" />
        <uses-feature android:name="android.hardware.touchscreen" android:required="false" />

        <application ...>
            <activity ...>
                <intent-filter>
                    <action android:name="android.intent.action.MAIN"/>
                    <category android:name="android.intent.category.LAUNCHER"/>
                    
                    <!-- ADICIONE ISSO: Categoria para aparecer no Launcher da TV -->
                    <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
                </intent-filter>
            </activity>
        </application>
    </manifest>
    ```

3.  **Execute o projeto**:
    Conecte sua Android TV (ou emulador) e execute:
    ```bash
    flutter run
    ```

## Funcionalidades Implementadas

*   **Navegação D-Pad**: A interface utiliza widgets padrão do Flutter que suportam foco e navegação por controle remoto.
*   **Leitor de Código de Barras (HID)**:
    *   Implementado com `RawKeyboardListener` na tela principal.
    *   Captura a entrada do teclado (scanner) sem precisar de um campo de texto focado (`TextField`).
    *   Filtra teclas de navegação (setas) para não interferir na leitura.
    *   Exibe o código lido centralizado na tela.

## Dicas

*   Se o leitor de código de barras não estiver enviando "Enter" ao final, você pode precisar configurar o sufixo no próprio leitor ou ajustar a lógica em `lib/main.dart` (método `_handleKey`).
*   O foco inicial é gerenciado automaticamente para garantir que o listener capture as teclas.

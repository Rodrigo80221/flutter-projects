import pyautogui
import time
import sys

# A URL fixa que o "leitor" vai digitar
CODIGO_FIXO = "7894900010015"

print("=== AUTO-SCANNER INICIADO ===")
print("Este script vai digitar a URL fixa automaticamente.")
print(f"Dados: {CODIGO_FIXO[:50]}... (URL Completa)")
print("\n--> ATENÇÃO: CLIQUE NA JANELA DO APP FLUTTER AGORA!")

# Contagem regressiva de 4 segundos
for i in range(4, 0, -1):
    print(f"Iniciando em {i} segundos...")
    time.sleep(1)

print("\n--> ENVIANDO DADOS RAPIDAMENTE...")

# Digita a URL. 
# Diminui o interval para 0.01 para ser mais rápido, pois a URL é muito longa.
pyautogui.write(CODIGO_FIXO, interval=0.01)

# Pressiona ENTER no final
pyautogui.press('enter')

print("\n--> SUCESSO! Código enviado.")
print("Esta janela fechará automaticamente em 5 segundos.")

# Espera um pouco para você conseguir ler a mensagem de sucesso antes da janela fechar
time.sleep(5)
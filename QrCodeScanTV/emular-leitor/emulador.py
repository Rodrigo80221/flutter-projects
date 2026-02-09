import pyautogui
import time
import sys

print("=== EMULADOR DE LEITOR DE CÓDIGO DE BARRAS ===")
print("Este script vai digitar o código como se fosse um scanner USB.")
print("Para sair, pressione Ctrl+C no terminal.\n")

try:
    while True:
        # 1. Pede o código para você digitar no terminal
        barcode = input("Digite o código de barras para testar: ")
        
        if not barcode:
            continue

        print(f"--> Preparando para enviar '{barcode}'...")
        print("--> VOCÊ TEM 3 SEGUNDOS PARA CLICAR NA JANELA DO APP FLUTTER!")
        
        # 2. Dá tempo de você focar a janela do Flutter
        for i in range(3, 0, -1):
            print(f"{i}...")
            time.sleep(1)

        print("--> ENVIANDO DADOS...")
        
        # 3. Digita o código caractere por caractere (simula o HID)
        pyautogui.write(barcode, interval=0.05)
        
        # 4. Pressiona ENTER no final (sinaliza o fim da leitura)
        pyautogui.press('enter')
        
        print("--> Concluído! Verifique o app.\n")

except KeyboardInterrupt:
    print("\nEncerrando emulador.")
    sys.exit()
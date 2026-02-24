@echo off
echo ==========================================================
echo ATENCAO: ESTA ACAO VAI ATUALIZAR O SITE INTEIRO!
echo ==========================================================
echo.
echo O comando a seguir fara o upload de todos os arquivos 
echo da pasta QrCodeScan para a nuvem da Azure, substituindo 
echo totalmente a versao do site que esta no ar agora.
echo.

set /p confirmacao="Voce tem certeza que deseja continuar? (Digite 'sim' para prosseguir): "

if /i "%confirmacao%"=="sim" (
    echo.
    echo Navegando para o diretorio do site...
    cd website
    
    echo Iniciando o envio dos arquivos para o Azure...
    swa deploy .\QrCodeScan --deployment-token 02405663ebfbb6e51d21f28470f46c446cabe2e1873b2c4852f6e3bc67d2cec504-113d15c5-4d35-41ec-ac67-fb65b89eadb900f0913043f3e70f --env production
    
    echo.
    echo Retornando ao diretorio principal...
    cd ..
    
    echo.
    echo Processo de deploy finalizado! Os arquivos ja estao online.
) else (
    echo.
    echo Operacao cancelada. O site nao foi modificado.
)

echo.
pause
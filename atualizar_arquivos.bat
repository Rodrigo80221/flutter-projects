@echo off
setlocal enabledelayedexpansion

echo Copiando o arquivo APK para a pasta do site...
copy /Y ".\QrCodeScanTV\build\app\outputs\apk\release\app-release.apk" ".\website\QrCodeScan\atualizacao-totem\app-release.apk"

echo.
echo Lendo a versao direto do projeto Flutter...
for /f "tokens=2 delims=: " %%a in ('findstr /R "^version:" ".\QrCodeScanTV\pubspec.yaml"') do set RAW_VERSION=%%a

:: Remove o numero de build do Flutter (exemplo: converte 1.0.5+1 para 1.0.5)
for /f "tokens=1 delims=+" %%b in ("%RAW_VERSION%") do set APP_VERSION=%%b

echo Versao detectada: %APP_VERSION%

echo.
echo Recriando o arquivo versao.xml com a versao %APP_VERSION%...
set XML_PATH=".\website\QrCodeScan\atualizacao-totem\versao.xml"

echo ^<?xml version="1.0" encoding="UTF-8"?^> > %XML_PATH%
echo ^<atualizacao^> >> %XML_PATH%
echo     ^<versao^>%APP_VERSION%^</versao^> >> %XML_PATH%
echo ^</atualizacao^> >> %XML_PATH%

echo.
echo Processo concluido com sucesso!
pause
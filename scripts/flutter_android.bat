@echo off
REM Script batch pour gérer Flutter avec Android
REM Usage: scripts\flutter_android.bat [command]

setlocal enabledelayedexpansion

echo 🐦 Flutter Android Manager
echo ================================

if "%1"=="" (
    echo 📱 Appareils connectés:
    flutter devices
    goto :end
)

if "%1"=="devices" (
    echo 📱 Appareils connectés:
    flutter devices
    goto :end
)

if "%1"=="emulators" (
    echo 📱 Émulateurs disponibles:
    flutter emulators
    goto :end
)

if "%1"=="start-emulator" (
    echo 🚀 Démarrage de l'émulateur...
    flutter emulators --launch Pixel_7_API_34
    goto :end
)

if "%1"=="run" (
    echo ▶️  Lancement de l'app sur Android...
    flutter run -d android
    goto :end
)

if "%1"=="clean" (
    echo 🧹 Nettoyage du projet...
    flutter clean
    goto :end
)

if "%1"=="get" (
    echo 📦 Récupération des dépendances...
    flutter pub get
    goto :end
)

if "%1"=="analyze" (
    echo 🔍 Analyse du code...
    flutter analyze
    goto :end
)

if "%1"=="doctor" (
    echo 🏥 Diagnostic Flutter...
    flutter doctor
    goto :end
)

echo ❌ Commande inconnue: %1
echo Commandes disponibles: devices, emulators, start-emulator, run, clean, get, analyze, doctor

:end
echo ================================ 
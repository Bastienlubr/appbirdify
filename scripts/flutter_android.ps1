# Script PowerShell pour gérer Flutter avec Android
# Usage: .\scripts\flutter_android.ps1 [command]

param(
    [Parameter(Position=0)]
    [ValidateSet("devices", "emulators", "start-emulator", "run", "clean", "get", "analyze", "doctor")]
    [string]$Command = "devices"
)

Write-Host "🐦 Flutter Android Manager" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

switch ($Command) {
    "devices" {
        Write-Host "📱 Appareils connectés:" -ForegroundColor Yellow
        flutter devices
    }
    
    "emulators" {
        Write-Host "📱 Émulateurs disponibles:" -ForegroundColor Yellow
        flutter emulators
    }
    
    "start-emulator" {
        Write-Host "🚀 Démarrage de l'émulateur..." -ForegroundColor Yellow
        $emulators = flutter emulators
        if ($emulators -match "Pixel_7_API_34") {
            flutter emulators --launch Pixel_7_API_34
        } else {
            Write-Host "❌ Aucun émulateur Pixel_7_API_34 trouvé. Créez-en un dans Android Studio." -ForegroundColor Red
        }
    }
    
    "run" {
        Write-Host "▶️  Lancement de l'app sur Android..." -ForegroundColor Yellow
        flutter run -d android
    }
    
    "clean" {
        Write-Host "🧹 Nettoyage du projet..." -ForegroundColor Yellow
        flutter clean
    }
    
    "get" {
        Write-Host "📦 Récupération des dépendances..." -ForegroundColor Yellow
        flutter pub get
    }
    
    "analyze" {
        Write-Host "🔍 Analyse du code..." -ForegroundColor Yellow
        flutter analyze
    }
    
    "doctor" {
        Write-Host "🏥 Diagnostic Flutter..." -ForegroundColor Yellow
        flutter doctor
    }
}

Write-Host "================================" -ForegroundColor Green 
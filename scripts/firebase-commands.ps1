# Script Firebase pour Birdify
# Utilisation : .\scripts\firebase-commands.ps1

Write-Host "🔥 Firebase Commands pour Birdify" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green

# Vérifier si Firebase CLI est installé
try {
    $firebaseVersion = firebase --version
    Write-Host "✅ Firebase CLI détecté : $firebaseVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Firebase CLI non installé. Installez-le avec : npm install -g firebase-tools" -ForegroundColor Red
    exit 1
}

# Menu des commandes
Write-Host "`n📋 Commandes disponibles :" -ForegroundColor Yellow
Write-Host "1. Démarrer les emulators (firebase emulators:start)" -ForegroundColor Cyan
Write-Host "2. Déployer les règles Firestore (firebase deploy --only firestore:rules)" -ForegroundColor Cyan
Write-Host "3. Déployer les index Firestore (firebase deploy --only firestore:indexes)" -ForegroundColor Cyan
Write-Host "4. Déployer tout (firebase deploy)" -ForegroundColor Cyan
Write-Host "5. Ouvrir l'interface des emulators" -ForegroundColor Cyan
Write-Host "6. Quitter" -ForegroundColor Red

do {
    $choice = Read-Host "`nChoisissez une option (1-6)"
    
    switch ($choice) {
        "1" {
            Write-Host "🚀 Démarrage des emulators Firebase..." -ForegroundColor Green
            firebase emulators:start
        }
        "2" {
            Write-Host "📝 Déploiement des règles Firestore..." -ForegroundColor Green
            firebase deploy --only firestore:rules
        }
        "3" {
            Write-Host "🔍 Déploiement des index Firestore..." -ForegroundColor Green
            firebase deploy --only firestore:indexes
        }
        "4" {
            Write-Host "🚀 Déploiement complet..." -ForegroundColor Green
            firebase deploy
        }
        "5" {
            Write-Host "🌐 Ouverture de l'interface des emulators..." -ForegroundColor Green
            Start-Process "http://localhost:4000"
        }
        "6" {
            Write-Host "👋 Au revoir !" -ForegroundColor Green
            break
        }
        default {
            Write-Host "❌ Option invalide. Choisissez 1-6." -ForegroundColor Red
        }
    }
} while ($choice -ne "6")

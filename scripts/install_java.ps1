# Script d'installation Java OpenJDK pour Birdify
# Utilisation : .\scripts\install_java.ps1

Write-Host "☕ Installation Java OpenJDK pour Firebase Emulators" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

# Vérifier si Java est déjà installé
try {
    $javaVersion = java -version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Java est déjà installé :" -ForegroundColor Green
        Write-Host $javaVersion[0] -ForegroundColor Cyan
        Write-Host "`n🎯 Vous pouvez maintenant tester l'émulateur :" -ForegroundColor Yellow
        Write-Host "   npm run emu:start" -ForegroundColor Cyan
        exit 0
    }
} catch {
    Write-Host "ℹ️ Java non détecté, installation nécessaire..." -ForegroundColor Yellow
}

# Configuration
$javaVersion = "17.0.8"
$javaBuild = "7"
$javaUrl = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-$javaVersion%2B$javaBuild/OpenJDK17U-jdk_x64_windows_hotspot_$javaVersion`_$javaBuild.msi"
$javaInstaller = "OpenJDK17.msi"

Write-Host "📥 Téléchargement d'OpenJDK $javaVersion..." -ForegroundColor Cyan

try {
    # Télécharger l'installateur
    Invoke-WebRequest -Uri $javaUrl -OutFile $javaInstaller -UseBasicParsing
    
    if (Test-Path $javaInstaller) {
        Write-Host "✅ Téléchargement terminé : $javaInstaller" -ForegroundColor Green
        $fileSize = (Get-Item $javaInstaller).Length / 1MB
        Write-Host "📁 Taille : $fileSize MB" -ForegroundColor Cyan
        
        Write-Host "`n🚀 Installation en cours..." -ForegroundColor Yellow
        Write-Host "   (L'installateur va s'ouvrir, suivez les instructions)" -ForegroundColor Cyan
        
        # Lancer l'installateur
        Start-Process -FilePath $javaInstaller -Wait
        
        # Nettoyer le fichier téléchargé
        Remove-Item $javaInstaller -Force
        
        Write-Host "`n✅ Installation terminée !" -ForegroundColor Green
        Write-Host "`n⚠️ IMPORTANT : Redémarrez PowerShell pour que les changements prennent effet" -ForegroundColor Yellow
        Write-Host "   Puis testez avec : java -version" -ForegroundColor Cyan
        
    } else {
        throw "Fichier d'installation non trouvé après téléchargement"
    }
    
} catch {
    Write-Host "❌ Erreur lors de l'installation :" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    Write-Host "`n🔄 Solution alternative :" -ForegroundColor Yellow
    Write-Host "   1. Téléchargez manuellement depuis : https://adoptium.net/" -ForegroundColor Cyan
    Write-Host "   2. Installez OpenJDK 17 LTS" -ForegroundColor Cyan
    Write-Host "   3. Ajoutez Java au PATH système" -ForegroundColor Cyan
    
    exit 1
}

Write-Host "`n📋 Prochaines étapes après redémarrage de PowerShell :" -ForegroundColor Yellow
Write-Host "   1. java -version (vérifier l'installation)" -ForegroundColor Cyan
Write-Host "   2. npm run emu:start (démarrer l'émulateur)" -ForegroundColor Cyan
Write-Host "   3. npm run emu:ping (tester la connexion)" -ForegroundColor Cyan

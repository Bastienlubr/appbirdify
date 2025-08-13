# Script pour télécharger et installer OpenJDK 11 manuellement
Write-Host "Telechargement et installation d'OpenJDK 11..." -ForegroundColor Cyan

# Créer un dossier temporaire
$tempDir = "C:\temp\java11"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

# URL de téléchargement OpenJDK 11 (version Windows x64)
$javaUrl = "https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.12%2B7/OpenJDK11U-jdk_x64_windows_hotspot_11.0.12_7.zip"
$zipPath = "$tempDir\openjdk11.zip"
$extractPath = "C:\Program Files\OpenJDK11"

Write-Host "Telechargement d'OpenJDK 11..." -ForegroundColor Yellow
Write-Host "URL: $javaUrl" -ForegroundColor Gray

try {
    # Télécharger le fichier
    Invoke-WebRequest -Uri $javaUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Telechargement termine!" -ForegroundColor Green
    
    # Extraire le fichier
    Write-Host "Extraction en cours..." -ForegroundColor Yellow
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
    
    # Trouver le dossier Java
    $javaFolder = Get-ChildItem $extractPath -Directory | Where-Object { $_.Name -like "*jdk*" } | Select-Object -First 1
    
    if ($javaFolder) {
        $javaBinPath = "$($javaFolder.FullName)\bin"
        $javaHome = $javaFolder.FullName
        
        # Configurer les variables d'environnement
        $env:PATH = "$javaBinPath;$env:PATH"
        $env:JAVA_HOME = $javaHome
        
        Write-Host "Java 11 installe et configure!" -ForegroundColor Green
        Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow
        
        # Tester l'installation
        Write-Host "Test de Java 11:" -ForegroundColor Cyan
        java -version
        
        Write-Host "Nettoyage des fichiers temporaires..." -ForegroundColor Yellow
        Remove-Item $tempDir -Recurse -Force
        
        Write-Host "Java 11 est maintenant pret pour Firebase Emulators!" -ForegroundColor Green
        Write-Host "Vous pouvez maintenant executer: npm run emu:start" -ForegroundColor Cyan
    } else {
        Write-Host "Erreur: Impossible de trouver le dossier Java dans l'extraction" -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur lors du telechargement: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Essayez de telecharger manuellement depuis: $javaUrl" -ForegroundColor Yellow
}

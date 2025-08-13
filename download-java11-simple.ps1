# Script simplifié pour télécharger Java 11
Write-Host "Telechargement d'OpenJDK 11 depuis Eclipse Temurin..." -ForegroundColor Cyan

# URL plus récente d'Eclipse Temurin
$javaUrl = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.21%2B9/OpenJDK11U-jdk_x64_windows_hotspot_11.0.21_9.zip"
$zipPath = "C:\temp\java11.zip"
$extractPath = "C:\Program Files\OpenJDK11"

# Créer le dossier temporaire
if (!(Test-Path "C:\temp")) {
    New-Item -ItemType Directory -Path "C:\temp" -Force | Out-Null
}

Write-Host "Telechargement en cours..." -ForegroundColor Yellow
Write-Host "Cela peut prendre quelques minutes..." -ForegroundColor Gray

try {
    # Télécharger
    Invoke-WebRequest -Uri $javaUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Telechargement termine!" -ForegroundColor Green
    
    # Extraire
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
        
        Write-Host "Java 11 installe avec succes!" -ForegroundColor Green
        Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow
        
        # Tester
        Write-Host "Test de Java 11:" -ForegroundColor Cyan
        java -version
        
        # Nettoyer
        Remove-Item $zipPath -Force
        
        Write-Host "Java 11 est pret pour Firebase Emulators!" -ForegroundColor Green
    } else {
        Write-Host "Erreur: Dossier Java non trouve" -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Alternative: Telechargez manuellement depuis https://adoptium.net/" -ForegroundColor Yellow
}

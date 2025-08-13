# Script pour installer Java 11 dans le dossier utilisateur
Write-Host "Installation d'OpenJDK 11 dans le dossier utilisateur..." -ForegroundColor Cyan

# Utiliser le dossier utilisateur pour éviter les problèmes de permissions
$userJavaPath = "$env:USERPROFILE\Java11"
$zipPath = "$env:TEMP\java11.zip"

# URL d'Eclipse Temurin
$javaUrl = "https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.21%2B9/OpenJDK11U-jdk_x64_windows_hotspot_11.0.21_9.zip"

Write-Host "Telechargement en cours..." -ForegroundColor Yellow
Write-Host "Cela peut prendre quelques minutes..." -ForegroundColor Gray

try {
    # Télécharger
    Invoke-WebRequest -Uri $javaUrl -OutFile $zipPath -UseBasicParsing
    Write-Host "Telechargement termine!" -ForegroundColor Green
    
    # Créer le dossier de destination
    if (Test-Path $userJavaPath) {
        Remove-Item $userJavaPath -Recurse -Force
    }
    New-Item -ItemType Directory -Path $userJavaPath -Force | Out-Null
    
    # Extraire
    Write-Host "Extraction en cours..." -ForegroundColor Yellow
    Expand-Archive -Path $zipPath -DestinationPath $userJavaPath -Force
    
    # Trouver le dossier Java
    $javaFolder = Get-ChildItem $userJavaPath -Directory | Where-Object { $_.Name -like "*jdk*" } | Select-Object -First 1
    
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
        Write-Host "Vous pouvez maintenant executer: npm run emu:start" -ForegroundColor Cyan
    } else {
        Write-Host "Erreur: Dossier Java non trouve" -ForegroundColor Red
    }
} catch {
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Alternative: Telechargez manuellement depuis https://adoptium.net/" -ForegroundColor Yellow
}

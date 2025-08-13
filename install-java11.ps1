# Script pour installer OpenJDK 11 via Chocolatey
Write-Host "Installation d'OpenJDK 11 pour Firebase Emulators..." -ForegroundColor Cyan

# Vérifier si Chocolatey est installé
try {
    $chocoVersion = choco --version
    Write-Host "Chocolatey detecte: version $chocoVersion" -ForegroundColor Green
} catch {
    Write-Host "Chocolatey non detecte. Installation en cours..." -ForegroundColor Yellow
    
    # Installer Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    Write-Host "Chocolatey installe avec succes!" -ForegroundColor Green
}

# Installer OpenJDK 11
Write-Host "Installation d'OpenJDK 11..." -ForegroundColor Yellow
choco install openjdk11 -y

# Configurer les variables d'environnement
Write-Host "Configuration des variables d'environnement..." -ForegroundColor Yellow

# Trouver le chemin d'installation
$javaPath = Get-ChildItem "C:\Program Files\OpenJDK" -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*11*" } | Select-Object -First 1
if ($javaPath) {
    $javaBinPath = "$($javaPath.FullName)\bin"
    $javaHome = $javaPath.FullName
    
    # Ajouter au PATH de la session actuelle
    $env:PATH = "$javaBinPath;$env:PATH"
    $env:JAVA_HOME = $javaHome
    
    Write-Host "Java 11 configure temporairement" -ForegroundColor Green
    Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow
    
    # Tester l'installation
    Write-Host "Test de Java 11:" -ForegroundColor Cyan
    java -version
    
    Write-Host "Java 11 est maintenant pret pour Firebase Emulators!" -ForegroundColor Green
    Write-Host "Vous pouvez maintenant executer: npm run emu:start" -ForegroundColor Cyan
} else {
    Write-Host "Erreur: Impossible de trouver OpenJDK 11 installe" -ForegroundColor Red
}

# Script pour configurer Java de manière permanente
Write-Host "Configuration permanente de Java 11..." -ForegroundColor Cyan

# Chemins Java
$javaPath = "C:\Users\basti\Java11\jdk-11.0.21+9\bin"
$javaHome = "C:\Users\basti\Java11\jdk-11.0.21+9"

# Ajouter au PATH utilisateur (permanent)
Write-Host "Ajout de Java au PATH utilisateur..." -ForegroundColor Yellow
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$javaPath*") {
    $newUserPath = "$javaPath;$userPath"
    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
    Write-Host "Java ajoute au PATH utilisateur" -ForegroundColor Green
} else {
    Write-Host "Java deja dans le PATH utilisateur" -ForegroundColor Yellow
}

# Définir JAVA_HOME utilisateur (permanent)
Write-Host "Configuration de JAVA_HOME..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
Write-Host "JAVA_HOME configure: $javaHome" -ForegroundColor Green

# Configurer pour la session actuelle
$env:PATH = "$javaPath;$env:PATH"
$env:JAVA_HOME = $javaHome

Write-Host "`nConfiguration terminee!" -ForegroundColor Green
Write-Host "Java sera disponible dans toutes les nouvelles sessions PowerShell" -ForegroundColor Cyan
Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow

# Tester
Write-Host "`nTest de Java:" -ForegroundColor Cyan
java -version

Write-Host "`nPour utiliser Java dans une nouvelle session, redemarrez PowerShell" -ForegroundColor Yellow
Write-Host "Ou utilisez le script setup-java.ps1 pour une configuration temporaire" -ForegroundColor Gray

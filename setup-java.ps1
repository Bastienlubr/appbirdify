# Script pour configurer Java dans la session PowerShell actuelle
$javaPath = "C:\Program Files (x86)\Java\latest\jre-1.8\bin"
$javaHome = "C:\Program Files (x86)\Java\latest\jre-1.8"

# Ajouter Java au PATH de la session actuelle
$env:PATH = "$javaPath;$env:PATH"
$env:JAVA_HOME = $javaHome

Write-Host "Java configuré temporairement pour cette session PowerShell" -ForegroundColor Green
Write-Host "JAVA_HOME: $env:JAVA_HOME" -ForegroundColor Yellow
Write-Host "Java ajouté au PATH" -ForegroundColor Yellow

# Tester Java
Write-Host "`nTest de Java:" -ForegroundColor Cyan
& "$javaPath\java.exe" -version

Write-Host "`nVous pouvez maintenant utiliser 'java' directement dans cette session" -ForegroundColor Green

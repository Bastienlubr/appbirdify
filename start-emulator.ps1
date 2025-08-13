# Script pour démarrer l'émulateur Firebase en arrière-plan
Write-Host "Demarrage de l'emulateur Firebase..." -ForegroundColor Cyan

# Configurer Java
$env:PATH = "C:\Users\basti\Java11\jdk-11.0.21+9\bin;$env:PATH"
$env:JAVA_HOME = "C:\Users\basti\Java11\jdk-11.0.21+9"

Write-Host "Java configure: $env:JAVA_HOME" -ForegroundColor Green

# Démarrer l'émulateur en arrière-plan
Write-Host "Demarrage de l'emulateur Firestore..." -ForegroundColor Yellow
Start-Process -FilePath "npm" -ArgumentList "run", "emu:start" -WindowStyle Hidden

Write-Host "Attente du demarrage de l'emulateur..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Vérifier que l'émulateur est démarré
$port8080 = netstat -an | findstr ":8080"
if ($port8080) {
    Write-Host "Emulateur Firestore demarre sur le port 8080!" -ForegroundColor Green
    Write-Host "Interface web disponible sur: http://127.0.0.1:4000/" -ForegroundColor Cyan
    Write-Host "Vous pouvez maintenant tester avec: npm run emu:ping" -ForegroundColor Yellow
} else {
    Write-Host "Emulateur pas encore pret, attendez un peu plus..." -ForegroundColor Yellow
}

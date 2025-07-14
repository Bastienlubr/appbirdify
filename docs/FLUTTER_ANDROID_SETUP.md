# 🐦 Configuration Flutter Android dans Cursor

## 📋 Prérequis

- ✅ Flutter SDK installé
- ✅ Android Studio installé
- ✅ Cursor configuré avec l'extension Flutter/Dart

## 🚀 Configuration rapide

### 1. Vérification de l'environnement

```powershell
# Vérifier que tout est bien configuré
flutter doctor

# Lister les appareils disponibles
flutter devices

# Lister les émulateurs
flutter emulators
```

### 2. Création d'un émulateur Android

Si aucun émulateur n'est disponible :

1. Ouvrir **Android Studio**
2. Aller dans **Tools > AVD Manager**
3. Cliquer sur **Create Virtual Device**
4. Choisir **Pixel 7** (ou autre téléphone)
5. Sélectionner **API 34** (Android 14)
6. Cliquer sur **Finish**

### 3. Utilisation dans Cursor

#### Méthode 1 : Via le menu Debug (Recommandé)
1. Appuyer sur `F5` ou aller dans **Run > Start Debugging**
2. Sélectionner **Flutter - Android Emulator** ou **Flutter - Android Device**
3. L'app se lance automatiquement sur l'émulateur/téléphone

#### Méthode 2 : Via les tâches
1. `Ctrl+Shift+P` → **Tasks: Run Task**
2. Sélectionner **Flutter: Run on Android**

#### Méthode 3 : Via le script PowerShell
```powershell
# Démarrer l'émulateur
.\scripts\flutter_android.ps1 start-emulator

# Lancer l'app
.\scripts\flutter_android.ps1 run
```

## 📱 Connexion d'un téléphone Android réel

### Via USB
1. Activer le **Mode développeur** sur votre téléphone
2. Activer le **Débogage USB**
3. Connecter le téléphone via USB
4. Autoriser le débogage sur le téléphone
5. Vérifier avec `flutter devices`

### Via Wi-Fi (Android 11+)
1. Connecter le téléphone en USB d'abord
2. Activer le **Débogage sans fil** dans les options développeur
3. Débrancher le câble USB
4. Le téléphone apparaîtra dans `flutter devices`

## 🔧 Configuration avancée

### Raccourcis clavier personnalisés

Ajouter dans `.vscode/keybindings.json` :

```json
[
    {
        "key": "ctrl+shift+f5",
        "command": "dart.flutter.run",
        "args": {
            "deviceId": "android"
        }
    },
    {
        "key": "ctrl+shift+f6",
        "command": "dart.flutter.hotReload"
    }
]
```

### Variables d'environnement

Créer un fichier `.env` à la racine :

```env
FLUTTER_DEVICE_ID=android
FLUTTER_MODE=debug
```

## 🛠️ Commandes utiles

```powershell
# Lister tous les appareils
flutter devices

# Démarrer un émulateur spécifique
flutter emulators --launch Pixel_7_API_34

# Lancer sur Android spécifiquement
flutter run -d android

# Mode hot reload
flutter run -d android --hot

# Mode profile (performance)
flutter run -d android --profile

# Mode release
flutter run -d android --release

# Nettoyer le projet
flutter clean

# Récupérer les dépendances
flutter pub get

# Analyser le code
flutter analyze
```

## 🎯 Avantages de cette configuration

- ✅ **Plus de Chrome** : Test direct sur mobile
- ✅ **Interface téléphone** : Rendu fidèle à la réalité
- ✅ **Hot reload** : Développement rapide
- ✅ **Debugging** : Débogage complet avec breakpoints
- ✅ **Performance** : Test des performances réelles

## 🔍 Dépannage

### Problème : Aucun émulateur détecté
```powershell
# Vérifier Android Studio
flutter doctor --android-licenses

# Redémarrer le service ADB
adb kill-server
adb start-server
```

### Problème : Téléphone non détecté
1. Vérifier que le débogage USB est activé
2. Changer de câble USB
3. Réinstaller les drivers USB
4. Redémarrer ADB : `adb kill-server && adb start-server`

### Problème : Erreur de build
```powershell
flutter clean
flutter pub get
flutter run -d android
```

## 📚 Ressources

- [Documentation Flutter](https://flutter.dev/docs)
- [Guide Android Studio](https://developer.android.com/studio)
- [Extension Flutter pour VS Code](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter) 
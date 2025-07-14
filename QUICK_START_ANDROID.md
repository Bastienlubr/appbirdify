# 🚀 Guide de démarrage rapide - Flutter Android

## ⚡ Démarrage en 3 étapes

### 1. Créer un émulateur Android (si pas déjà fait)

1. Ouvrir **Android Studio**
2. **Tools** → **AVD Manager**
3. **Create Virtual Device**
4. Choisir **Pixel 7** → **API 34** → **Finish**

### 2. Démarrer l'émulateur

```bash
# Option 1: Via le script
scripts\flutter_android.bat start-emulator

# Option 2: Directement
flutter emulators --launch Pixel_7_API_34
```

### 3. Lancer l'app dans Cursor

#### Méthode A : Raccourci clavier (Recommandé)
- `Ctrl+Shift+F5` : Lancer sur Android
- `Ctrl+Shift+F6` : Hot reload
- `Ctrl+Shift+F7` : Hot restart

#### Méthode B : Menu Debug
- `F5` → Sélectionner **Flutter - Android Emulator**

#### Méthode C : Script
```bash
scripts\flutter_android.bat run
```

## 📱 Connexion téléphone réel

### Via USB
1. Activer **Mode développeur** (taper 7 fois sur "Numéro de build")
2. Activer **Débogage USB**
3. Connecter le câble USB
4. Autoriser le débogage sur le téléphone

### Vérifier la connexion
```bash
scripts\flutter_android.bat devices
```

## 🎯 Commandes utiles

```bash
# Lister les appareils
scripts\flutter_android.bat devices

# Nettoyer le projet
scripts\flutter_android.bat clean

# Récupérer les dépendances
scripts\flutter_android.bat get

# Analyser le code
scripts\flutter_android.bat analyze

# Diagnostic complet
scripts\flutter_android.bat doctor
```

## 🔧 Dépannage rapide

### Problème : Aucun émulateur détecté
```bash
flutter doctor --android-licenses
adb kill-server && adb start-server
```

### Problème : Erreur de build
```bash
scripts\flutter_android.bat clean
scripts\flutter_android.bat get
scripts\flutter_android.bat run
```

### Problème : Téléphone non détecté
1. Vérifier le débogage USB
2. Changer de câble USB
3. Redémarrer ADB : `adb kill-server && adb start-server`

## ✅ Avantages

- 🚫 **Plus de Chrome** : Test direct sur mobile
- 📱 **Interface téléphone** : Rendu fidèle
- ⚡ **Hot reload** : Développement rapide
- 🐛 **Debugging complet** : Breakpoints, variables
- 📊 **Performance réelle** : Test des performances

---

**🎉 Vous êtes prêt ! Votre app Flutter s'affichera maintenant en format téléphone !** 
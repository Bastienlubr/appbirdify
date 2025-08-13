# 🔥 Configuration Firebase pour Birdify

## 📋 Prérequis

### 1. Installation Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Connexion Firebase
```bash
firebase login
```

### 3. Vérification du projet
```bash
firebase projects:list
```

## 🚀 Utilisation des Emulators

### Démarrer les emulators
```bash
firebase emulators:start
```

**Ports utilisés :**
- **Firestore** : `localhost:8080`
- **Auth** : `localhost:9099`
- **UI** : `localhost:4000`

### Interface des emulators
Ouvrez `http://localhost:4000` dans votre navigateur pour accéder à l'interface des emulators.

## 📝 Déploiement des Règles

### Déployer uniquement les règles Firestore
```bash
firebase deploy --only firestore:rules
```

### Déployer uniquement les index Firestore
```bash
firebase deploy --only firestore:indexes
```

### Déployer tout
```bash
firebase deploy
```

## 🛠️ Scripts PowerShell

### Utiliser le script automatisé
```powershell
.\scripts\firebase-commands.ps1
```

Ce script propose un menu interactif pour :
- Démarrer les emulators
- Déployer les règles
- Déployer les index
- Ouvrir l'interface des emulators

## 📁 Structure des Fichiers

```
appbirdify/
├── firebase.json          # Configuration Firebase
├── .firebaserc           # ID du projet Firebase
├── firestore.rules       # Règles de sécurité Firestore
├── firestore.indexes.json # Index Firestore
└── scripts/
    └── firebase-commands.ps1 # Script PowerShell
```

## 🔒 Règles de Sécurité Implémentées

### Collections Publiques
- **`missionsPubliques/{missionId}`** : Lecture si `statut == "approuvee"`
- **`missions/{missionId}`** : Même logique (compatibilité)
- **`sons_oiseaux/{id}`** : Lecture pour utilisateurs connectés

### Données Utilisateur
- **`utilisateurs/{uid}`** : Lecture/écriture par le propriétaire uniquement
- **Sous-collections** : Toutes protégées par le propriétaire

### Historique Quiz
- **`tentativesQuiz/{attemptId}`** : Création et lecture par le propriétaire uniquement

## 🧪 Test des Règles

### 1. Démarrer les emulators
```bash
firebase emulators:start
```

### 2. Tester les règles
- Créez des documents de test
- Vérifiez les permissions d'accès
- Testez les différents scénarios d'authentification

### 3. Vérifier les logs
Les emulators affichent les tentatives d'accès et les violations de règles.

## 🚨 Dépannage

### Erreur "Project not found"
```bash
firebase use --add
# Sélectionnez votre projet
```

### Erreur de permissions
```bash
firebase login --reauth
```

### Emulators ne démarrent pas
```bash
firebase emulators:start --only firestore
```

## 📚 Ressources

- [Documentation Firebase Emulators](https://firebase.google.com/docs/emulator-suite)
- [Règles de Sécurité Firestore](https://firebase.google.com/docs/firestore/security/get-started)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

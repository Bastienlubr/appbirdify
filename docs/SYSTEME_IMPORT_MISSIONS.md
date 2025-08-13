# 🚀 Système d'Import des Missions - Documentation Complète

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Structure des Données](#structure-des-données)
4. [Scripts Disponibles](#scripts-disponibles)
5. [Guide d'Utilisation](#guide-dutilisation)
6. [Gestion des Erreurs](#gestion-des-erreurs)
7. [Maintenance et Sauvegarde](#maintenance-et-sauvegarde)
8. [Troubleshooting](#troubleshooting)

## 🌟 Vue d'ensemble

Le système d'import des missions est un ensemble de scripts Node.js qui permet d'importer automatiquement des missions et des oiseaux dans Firebase Firestore pour l'application Birdify. Il gère l'import des données CSV, la validation, et la création des relations entre missions et oiseaux.

### 🎯 Fonctionnalités Principales

- **Import automatique** des missions depuis des fichiers CSV
- **Import des oiseaux** avec leurs sons et métadonnées
- **Gestion des biomes** (urbain, forestier, agricole, etc.)
- **Système de sauvegarde** et rollback automatique
- **Validation des données** avant import
- **Tests complets** du système

## 🔧 Prérequis

### Logiciels Requis

- **Node.js** (version 16 ou supérieure)
- **npm** ou **yarn** pour la gestion des dépendances
- **Firebase CLI** (optionnel, pour la gestion du projet)

### Configuration Firebase

1. **Clé de service** : Assurez-vous que le fichier `serviceAccountKey.json` est présent à la racine du projet
2. **Permissions** : La clé de service doit avoir les droits d'écriture sur Firestore
3. **Règles Firestore** : Vérifiez que les règles permettent l'écriture

### Installation des Dépendances

```bash
# Installer les dépendances Node.js
npm install

# Ou avec yarn
yarn install
```

## 📊 Structure des Données

### Format des Missions

Les missions doivent être au format CSV avec les colonnes suivantes :

```csv
id_mission,titre,description,image_url
U1,Mission Urbaine 1,Description de la mission urbaine,https://example.com/image.jpg
F2,Mission Forestière 2,Description de la mission forestière,https://example.com/image2.jpg
```

**Convention de nommage des missions :**
- **U** = Urbain
- **F** = Forestier  
- **A** = Agricole
- **H** = Humide
- **M** = Montagnard
- **L** = Littoral

Le numéro après la lettre indique le niveau de difficulté.

### Format des Questions

Chaque mission doit avoir un fichier CSV de questions :

```csv
question,bonne_reponse,mauvaise_reponse1,mauvaise_reponse2,mauvaise_reponse3
Quel oiseau chante ainsi ?,Choucas des tours,Moineau domestique,Rougequeue noir,Merle noir
```

### Structure des Oiseaux

```csv
nom_francais,nom_latin,biome,url_son,url_image
Choucas des tours,Corvus monedula,urbain,https://example.com/son.mp3,https://example.com/image.jpg
```

## 🛠️ Scripts Disponibles

### 1. **import-all.mjs** - Import Complet
Script principal qui importe toutes les données en une seule fois.

```bash
node scripts/import-all.mjs
```

**Fonctionnalités :**
- Sauvegarde automatique avant import
- Import des oiseaux et missions
- Gestion des erreurs avec rollback
- Nettoyage automatique en cas d'échec

### 2. **import-missions.mjs** - Import des Missions Seulement
Import uniquement des missions et de leurs questions.

```bash
node scripts/import-missions.mjs
```

### 3. **import-oiseaux.mjs** - Import des Oiseaux Seulement
Import uniquement des oiseaux et de leurs sons.

```bash
node scripts/import-oiseaux.mjs
```

### 4. **test-complete-system.mjs** - Test Complet du Système
Script de test qui vérifie toutes les fonctionnalités.

```bash
node scripts/test-complete-system.mjs
```

### 5. **test-missions-import.mjs** - Test des Missions
Test spécifique à l'import des missions.

```bash
node scripts/test-missions-import.mjs
```

## 📖 Guide d'Utilisation

### 🚀 Import Initial (Première Utilisation)

1. **Préparer les données** :
   - Placer les fichiers CSV des missions dans le dossier approprié
   - Placer les fichiers CSV des oiseaux dans le dossier approprié
   - Vérifier que tous les fichiers sont au bon format

2. **Vérifier la configuration** :
   ```bash
   # Vérifier que la clé de service Firebase est présente
   ls serviceAccountKey.json
   
   # Vérifier que les dépendances sont installées
   npm list
   ```

3. **Lancer l'import complet** :
   ```bash
   node scripts/import-all.mjs
   ```

4. **Vérifier les résultats** :
   - Consulter les logs dans la console
   - Vérifier dans Firebase Console que les données sont présentes

### 🔄 Import Incrémental

Pour ajouter de nouvelles missions ou oiseaux :

1. **Ajouter les nouveaux fichiers CSV**
2. **Lancer l'import spécifique** :
   ```bash
   # Pour de nouvelles missions
   node scripts/import-missions.mjs
   
   # Pour de nouveaux oiseaux
   node scripts/import-oiseaux.mjs
   ```

### 🧪 Tests et Validation

Avant de déployer en production :

1. **Tester le système complet** :
   ```bash
   node scripts/test-complete-system.mjs
   ```

2. **Vérifier les données importées** :
   - Contrôler les relations entre missions et oiseaux
   - Vérifier la cohérence des biomes
   - Tester les fonctionnalités de l'application

## ⚠️ Gestion des Erreurs

### Types d'Erreurs Courantes

1. **Erreur de connexion Firebase** :
   - Vérifier la clé de service
   - Contrôler les permissions
   - Vérifier la connectivité réseau

2. **Erreur de format CSV** :
   - Vérifier la structure des colonnes
   - Contrôler l'encodage des fichiers
   - Vérifier la présence de données manquantes

3. **Erreur de validation** :
   - Vérifier la cohérence des biomes
   - Contrôler les relations entre missions et oiseaux

### Procédure de Récupération

En cas d'erreur lors de l'import :

1. **Le système sauvegarde automatiquement** l'état précédent
2. **Un rollback automatique** est effectué
3. **Les logs détaillés** sont affichés dans la console
4. **Corriger les erreurs** et relancer l'import

## 💾 Maintenance et Sauvegarde

### Sauvegarde Automatique

Le système crée automatiquement des sauvegardes avant chaque import :
- **Timestamp** de la sauvegarde
- **État complet** des collections
- **Possibilité de restauration** en cas de problème

### Nettoyage des Données

En cas d'échec complet :
```bash
# Le système nettoie automatiquement les collections
# et restaure l'état précédent
```

### Sauvegarde Manuelle

Pour créer une sauvegarde manuelle :
```bash
# Utiliser le script de test pour créer un utilisateur de test
node scripts/test-complete-system.mjs
```

## 🔍 Troubleshooting

### Problèmes Fréquents

#### 1. **Erreur "app/duplicate-app"**
```
✅ Normal : L'application Firebase est déjà initialisée
```

#### 2. **Fichiers CSV non trouvés**
```
❌ Vérifier les chemins des fichiers
❌ Contrôler la structure des dossiers
```

#### 3. **Erreur de permissions Firebase**
```
❌ Vérifier la clé de service
❌ Contrôler les règles Firestore
❌ Vérifier les permissions du projet
```

#### 4. **Données corrompues**
```
✅ Le système détecte automatiquement les problèmes
✅ Rollback automatique en cas d'erreur
✅ Logs détaillés pour diagnostic
```

### Commandes de Diagnostic

```bash
# Vérifier l'environnement
node scripts/check_environment.mjs

# Tester la connexion Firebase
node scripts/test-firebase.mjs

# Vérifier les oiseaux existants
node scripts/check-oiseaux.mjs
```

## 📱 Intégration avec l'Application

### Collections Firestore Créées

1. **`missions`** : Missions avec questions et métadonnées
2. **`sons_oiseaux`** : Oiseaux avec sons et images
3. **`utilisateurs`** : Profils utilisateurs et progression

### Relations Automatiques

- **Missions ↔ Oiseaux** : Liens automatiques basés sur les questions
- **Biomes** : Classification automatique des missions et oiseaux
- **Niveaux** : Extraction automatique depuis l'ID de mission

## 🚀 Déploiement en Production

### Checklist de Déploiement

- [ ] Tests complets réussis
- [ ] Validation des données importées
- [ ] Vérification des relations
- [ ] Test des fonctionnalités de l'application
- [ ] Sauvegarde de l'état actuel

### Monitoring Post-Déploiement

1. **Vérifier les logs** d'erreur
2. **Contrôler les performances** de l'application
3. **Valider les données** affichées
4. **Tester les fonctionnalités** critiques

## 📞 Support et Contact

En cas de problème ou de question :

1. **Consulter les logs** détaillés dans la console
2. **Vérifier la documentation** Firebase
3. **Contrôler la configuration** du projet
4. **Tester avec des données** de test

---

## 🎯 Résumé des Commandes Principales

```bash
# Import complet (recommandé pour la première utilisation)
node scripts/import-all.mjs

# Import spécifique
node scripts/import-missions.mjs
node scripts/import-oiseaux.mjs

# Tests et validation
node scripts/test-complete-system.mjs
node scripts/test-missions-import.mjs

# Diagnostic
node scripts/check_environment.mjs
node scripts/test-firebase.mjs
```

---

*Documentation mise à jour le : $(Get-Date -Format "dd/MM/yyyy")*
*Version du système : 1.0.0*

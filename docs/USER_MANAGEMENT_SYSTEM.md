# 🚀 Système de Gestion des Utilisateurs Birdify

## 📋 Vue d'ensemble

Le système de gestion des utilisateurs Birdify est un système complet qui gère **toutes les données personnelles** d'un utilisateur, avec synchronisation en temps réel et persistance multi-appareils.

## 🎯 Fonctionnalités Principales

### ✅ **Profil Utilisateur Complet**
- **Informations de base** : nom, email, avatar
- **Statistiques globales** : niveau, XP, score total, missions terminées
- **Système de vies** : gestion des vies avec recharge automatique
- **Séries quotidiennes** : suivi des jours consécutifs de jeu
- **Biomes débloqués** : progression dans l'exploration des environnements

### ❤️ **Gestion des Favoris**
- **Oiseaux favoris** : liste des espèces préférées
- **Métadonnées** : biome, date d'ajout, dernière vue
- **Synchronisation** : disponible sur tous les appareils

### 🏆 **Système de Badges**
- **Niveaux** : bronze, argent, or, diamant
- **Sources** : missions, progression, exploration, collection
- **Déblocage automatique** : basé sur les actions de l'utilisateur

### 🎯 **Progression des Missions**
- **Suivi détaillé** : étoiles, meilleur score, tentatives
- **Déverrouillage** : progression dans les biomes
- **Récompenses** : XP, badges, nouveaux contenus

### 📊 **Sessions de Quiz**
- **Historique complet** : toutes les parties jouées
- **Statistiques détaillées** : temps, réponses, scores
- **Commentaires audio** : enregistrements vocaux des utilisateurs

### ⚙️ **Préférences et Paramètres**
- **Personnalisation** : langue, thème, son, notifications
- **Accessibilité** : sous-titres, audio descriptif, réduction de mouvement
- **Confidentialité** : contrôle du partage des données

## 🏗️ Architecture Technique

### **Services Principaux**

#### 1. `UserProfileService` - Gestion des Données
```dart
// Créer ou mettre à jour un profil
await UserProfileService.createOrUpdateUserProfile(
  uid: 'user123',
  displayName: 'Nom Utilisateur',
  email: 'user@example.com',
);

// Ajouter un oiseau aux favoris
await UserProfileService.addToFavorites('user123', 'oiseau456');

// Débloquer un badge
await UserProfileService.unlockBadge('user123', 'badge_id', 'bronze');
```

#### 2. `UserSyncService` - Synchronisation en Temps Réel
```dart
// Démarrer la synchronisation
await UserSyncService.startSync();

// Accéder aux données actuelles
final profile = UserSyncService.currentProfile;
final favorites = UserSyncService.currentFavorites;
final badges = UserSyncService.currentBadges;

// Écouter les changements
UserSyncService.addProfileCallback(() {
  // Profil mis à jour
});
```

#### 3. `UserProfileWidget` - Interface Utilisateur
```dart
// Widget complet du profil
UserProfileWidget()
```

### **Structure des Données Firestore**

#### Collection `utilisateurs/{uid}`
```json
{
  "uid": "user123",
  "profil": {
    "nomAffichage": "Nom Utilisateur",
    "email": "user@example.com",
    "urlAvatar": "https://...",
    "derniereMiseAJour": "2024-01-01T00:00:00Z"
  },
  "vies": {
    "compte": 5,
    "max": 5,
    "prochaineRecharge": "2024-01-01T00:00:00Z"
  },
  "serie": {
    "jours": 3,
    "dernierJourActif": "2024-01-01T00:00:00Z",
    "plusLongueSerie": 7,
    "serieActuelle": 3
  },
  "totaux": {
    "scoreTotal": 1250,
    "missionsTerminees": 8,
    "xpTotal": 450,
    "niveau": 3,
    "tempsTotalJeu": 1800,
    "questionsRepondues": 120,
    "bonnesReponses": 96,
    "tauxReussite": 80
  },
  "parametres": {
    "langue": "fr",
    "sonActive": true,
    "notifications": true,
    "theme": "system"
  },
  "biomesUnlocked": ["milieu urbain", "milieu forestier"],
  "biomeActuel": "milieu urbain",
  "creeLe": "2024-01-01T00:00:00Z",
  "derniereConnexion": "2024-01-01T00:00:00Z"
}
```

#### Sous-collection `utilisateurs/{uid}/favoris/{oiseauId}`
```json
{
  "oiseauId": "oiseau456",
  "nom": "Choucas des tours",
  "biome": "urbain",
  "ajouteLe": "2024-01-01T00:00:00Z",
  "derniereVue": "2024-01-01T00:00:00Z"
}
```

#### Sous-collection `utilisateurs/{uid}/badges/{badgeId}`
```json
{
  "badgeId": "premiere_mission",
  "niveau": "bronze",
  "source": "mission",
  "description": "Terminer sa première mission",
  "obtenuLe": "2024-01-01T00:00:00Z",
  "visible": true
}
```

#### Sous-collection `utilisateurs/{uid}/progression_missions/{missionId}`
```json
{
  "idMission": "U01",
  "etoiles": 3,
  "meilleurScore": 95,
  "tentatives": 2,
  "deverrouille": true,
  "tempsMeilleur": 180,
  "dernierePartieLe": "2024-01-01T00:00:00Z",
  "recompenses": ["xp_100", "badge_premiere_mission"]
}
```

#### Sous-collection `utilisateurs/{uid}/sessions/{sessionId}`
```json
{
  "idMission": "U01",
  "score": 9,
  "totalQuestions": 10,
  "pourcentage": 90,
  "tempsTotal": 180,
  "reponses": [
    {
      "idQuestion": "q1",
      "reponseUtilisateur": "Choucas des tours",
      "correcte": true,
      "tempsReponse": 15
    }
  ],
  "commentaireAudio": "audio_123",
  "commenceLe": "2024-01-01T00:00:00Z",
  "termineLe": "2024-01-01T00:00:00Z",
  "difficulte": "facile",
  "biome": "urbain"
}
```

## 🚀 Utilisation dans l'Application

### **1. Initialisation au Démarrage**
```dart
class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeUserSync();
  }

  Future<void> _initializeUserSync() async {
    try {
      await UserSyncService.startSync();
    } catch (e) {
      // Gérer l'erreur
    }
  }
}
```

### **2. Affichage du Profil**
```dart
// Dans une page de profil
Scaffold(
  body: UserProfileWidget(),
)
```

### **3. Gestion des Favoris**
```dart
// Ajouter aux favoris
ElevatedButton(
  onPressed: () async {
    await UserProfileService.addToFavorites(
      userId, 
      oiseauId
    );
  },
  child: Text('Ajouter aux favoris'),
)

// Vérifier si favori
if (UserSyncService.isFavorite(oiseauId)) {
  // Afficher icône cœur plein
}
```

### **4. Suivi de la Progression**
```dart
// Obtenir la progression d'une mission
final progress = UserSyncService.getMissionProgress('U01');
if (progress != null) {
  final etoiles = progress['etoiles'] ?? 0;
  final score = progress['meilleurScore'] ?? 0;
  // Afficher les informations
}
```

### **5. Écouter les Changements**
```dart
class _ProfileListener extends StatefulWidget {
  @override
  _ProfileListenerState createState() => _ProfileListenerState();
}

class _ProfileListenerState extends State<_ProfileListener> {
  @override
  void initState() {
    super.initState();
    UserSyncService.addProfileCallback(() {
      if (mounted) {
        setState(() {
          // Reconstruire le widget
        });
      }
    });
  }

  @override
  void dispose() {
    UserSyncService.removeProfileCallback(() {});
    super.dispose();
  }
}
```

## 🔧 Configuration et Déploiement

### **1. Dépendances Requises**
```yaml
dependencies:
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_core: ^2.24.2
```

### **2. Configuration Firebase**
- Activer Authentication (Email/Password)
- Activer Firestore Database
- Configurer les règles de sécurité

### **3. Règles Firestore Recommandées**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Utilisateurs peuvent lire/écrire leurs propres données
    match /utilisateurs/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Sous-collections
      match /{collection}/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## 📱 Intégration avec l'Interface

### **Widgets Disponibles**

#### **UserProfileWidget**
- Affichage complet du profil
- Édition des informations
- Statistiques en temps réel
- Gestion des favoris et badges

#### **FavoritesSection**
- Liste des oiseaux favoris
- Ajout/suppression
- Navigation vers les détails

#### **BadgesSection**
- Affichage des badges débloqués
- Progression vers les suivants
- Explication des conditions

#### **MissionProgressSection**
- Progression de toutes les missions
- Scores et étoiles
- Déverrouillage des biomes

#### **SessionsSection**
- Historique des parties
- Statistiques détaillées
- Commentaires audio

## 🔄 Synchronisation et Performance

### **Stratégies de Synchronisation**
1. **Démarrage automatique** : au login de l'utilisateur
2. **Streams en temps réel** : mise à jour instantanée
3. **Cache local** : données disponibles hors ligne
4. **Synchronisation forcée** : rechargement manuel

### **Optimisations**
- **Limitation des streams** : 50 dernières sessions
- **Pagination** : chargement progressif des données
- **Compression** : données optimisées pour le réseau
- **Mise en cache** : réduction des appels Firestore

## 🧪 Tests et Validation

### **Scripts de Test Disponibles**
```bash
# Test du service de profil
node scripts/test-user-profile.mjs

# Test du système complet
node scripts/test-complete-system.mjs

# Test des missions
node scripts/test-missions-import.mjs
```

### **Validation des Données**
- **Structure** : vérification du format JSON
- **Cohérence** : validation des relations entre collections
- **Performance** : tests de charge et de synchronisation
- **Sécurité** : vérification des règles d'accès

## 🚨 Gestion des Erreurs

### **Types d'Erreurs Courantes**
1. **Connexion perdue** : retry automatique
2. **Données corrompues** : validation et nettoyage
3. **Permissions insuffisantes** : vérification des droits
4. **Limites de quota** : gestion de la bande passante

### **Stratégies de Récupération**
```dart
try {
  await UserProfileService.updateUserProfile(...);
} catch (e) {
  if (e.code == 'permission-denied') {
    // Demander les permissions
  } else if (e.code == 'unavailable') {
    // Retry après délai
    await Future.delayed(Duration(seconds: 5));
    await UserProfileService.updateUserProfile(...);
  }
}
```

## 🔮 Évolutions Futures

### **Fonctionnalités Prévues**
- **Système d'amis** : partage et comparaison
- **Classements** : compétition entre utilisateurs
- **Challenges** : défis quotidiens et hebdomadaires
- **Récompenses** : système de points et récompenses
- **Analytics** : statistiques détaillées et graphiques

### **Améliorations Techniques**
- **Offline-first** : synchronisation bidirectionnelle
- **Push notifications** : rappels et notifications
- **Multi-plateforme** : synchronisation cross-platform
- **API publique** : accès aux données via REST

## 📚 Ressources et Support

### **Documentation**
- [Guide Firebase](https://firebase.google.com/docs)
- [Flutter Firestore](https://firebase.flutter.dev/docs/firestore/overview/)
- [Architecture des données](https://firebase.google.com/docs/firestore/data-modeling)

### **Support**
- Issues GitHub : [Repository Birdify](https://github.com/...)
- Documentation technique : [Docs Birdify](https://...)
- Communauté : [Discord/Slack](https://...)

---

## 🎯 Résumé

Le système de gestion des utilisateurs Birdify offre une **solution complète et robuste** pour :

✅ **Gérer toutes les données personnelles** de l'utilisateur  
✅ **Synchroniser en temps réel** entre tous les appareils  
✅ **Persister les données** de manière fiable  
✅ **Offrir une expérience fluide** et responsive  
✅ **Évoluer facilement** avec de nouvelles fonctionnalités  

Ce système constitue la **base solide** de l'application Birdify et garantit que chaque utilisateur peut profiter de son expérience personnalisée, peu importe l'appareil utilisé ! 🚀

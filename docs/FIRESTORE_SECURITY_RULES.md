# Règles de Sécurité Firestore - Birdify

## Vue d'ensemble

Ces règles de sécurité garantissent que seuls les utilisateurs authentifiés peuvent accéder à leurs propres données dans la collection `users`.

## Règles recommandées

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Collection users - Seul l'utilisateur connecté peut accéder à son propre document
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Collection test - Pour les tests de diagnostic (à supprimer en production)
    match /test/{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Toutes les autres collections - Accès refusé par défaut
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Explication des règles

### Collection `users/{userId}`
- **`request.auth != null`** : L'utilisateur doit être authentifié
- **`request.auth.uid == userId`** : L'utilisateur ne peut accéder qu'à son propre document
- **`allow read, write`** : Lecture et écriture autorisées

### Collection `test`
- Permet les tests de diagnostic
- À supprimer en production

### Sécurité par défaut
- Toutes les autres collections sont inaccessibles

## Vérification des règles

### Test 1: Utilisateur authentifié accédant à son propre document
```javascript
// ✅ AUTORISÉ
// Utilisateur connecté avec UID "user123" accédant à users/user123
request.auth.uid == "user123" && resource.id == "user123"
```

### Test 2: Utilisateur authentifié accédant au document d'un autre
```javascript
// ❌ REFUSÉ
// Utilisateur connecté avec UID "user123" accédant à users/user456
request.auth.uid == "user123" && resource.id == "user456"
```

### Test 3: Utilisateur non authentifié
```javascript
// ❌ REFUSÉ
// Aucun utilisateur connecté
request.auth == null
```

## Implémentation dans l'application

L'application utilise maintenant des méthodes sécurisées :

```dart
// Vérification d'authentification
static bool _validateAuthentication(String uid) {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return false;
  return currentUser.uid == uid;
}

// Référence sécurisée
static DocumentReference? _getSecureUserDocument(String uid) {
  if (!_validateAuthentication(uid)) return null;
  return _firestore.collection('users').doc(uid);
}
```

## Déploiement des règles

1. **Console Firebase** :
   - Aller dans Firestore Database
   - Onglet "Règles"
   - Coller les règles ci-dessus
   - Cliquer "Publier"

2. **CLI Firebase** :
   ```bash
   firebase deploy --only firestore:rules
   ```

## Tests de sécurité

### Test de diagnostic
L'application inclut un diagnostic qui vérifie :
- ✅ Authentification Firebase
- ✅ Permissions Firestore
- ✅ Accès au document utilisateur

### Test manuel
```dart
// Dans l'écran de connexion, appuyer sur "Diagnostic Auth"
// Vérifier que les tests Firestore passent
```

## Dépannage

### Erreur PERMISSION_DENIED
**Cause** : Règles de sécurité trop restrictives ou utilisateur non authentifié

**Solutions** :
1. Vérifier que l'utilisateur est connecté
2. Vérifier que l'UID correspond
3. Vérifier les règles Firestore

### Erreur d'authentification
**Cause** : Firebase Auth non initialisé ou utilisateur déconnecté

**Solutions** :
1. Vérifier l'initialisation Firebase
2. Rediriger vers l'écran de connexion
3. Vérifier la configuration Firebase

## Monitoring

### Logs de sécurité
```dart
if (kDebugMode) {
  debugPrint('🔒 Accès sécurisé au document: $uid');
  debugPrint('   - Utilisateur connecté: ${_auth.currentUser?.uid}');
  debugPrint('   - Accès autorisé: ${_auth.currentUser?.uid == uid}');
}
```

### Métriques recommandées
- Nombre de tentatives d'accès non autorisées
- Temps de réponse des requêtes Firestore
- Taux d'erreur PERMISSION_DENIED

## Conclusion

Ces règles garantissent que :
- ✅ Seuls les utilisateurs authentifiés accèdent aux données
- ✅ Chaque utilisateur ne voit que ses propres données
- ✅ La sécurité est maintenue même en cas d'erreur d'application
- ✅ Les tests de diagnostic fonctionnent correctement 
# 🔍 Guide de Diagnostic - Système de Vies

## 🚨 **Problème Identifié**
Le bouton "💚 Restaurer 5 vies" dans l'onglet dev ne fonctionne pas malgré les logs positifs.

## 🔧 **Cause Racine Identifiée**
**Incohérence dans la structure des données de vies entre les services :**

### **DevToolsService.restoreLives()** (ANCIEN) :
```dart
'vies.compte': 5,           // ← Structure imbriquée
'vies.max': 5,              // ← Structure imbriquée
'vies.prochaineRecharge': FieldValue.serverTimestamp(),
```

### **LifeSyncService** (MODERNE) :
```dart
'livesRemaining': 5,        // ← Structure plate
'dailyResetDate': DateTime, // ← Structure plate
'lastUpdated': FieldValue.serverTimestamp(),
```

## 📊 **Structure des Données dans Firestore**

### **Structure Ancienne (incohérente) :**
```json
{
  "vies": {
    "compte": 5,
    "max": 5,
    "prochaineRecharge": "timestamp"
  }
}
```

### **Structure Moderne (cohérente) :**
```json
{
  "livesRemaining": 5,
  "dailyResetDate": "timestamp",
  "lastUpdated": "timestamp"
}
```

## 🛠️ **Solution Appliquée**

### **1. Harmonisation de DevToolsService.restoreLives()**
```dart
// AVANT (incohérent)
await _firestore.collection('utilisateurs').doc(user.uid).update({
  'vies.compte': 5,
  'vies.max': 5,
  'vies.prochaineRecharge': FieldValue.serverTimestamp(),
});

// APRÈS (cohérent)
await _firestore.collection('utilisateurs').doc(user.uid).set({
  'livesRemaining': 5,
  'dailyResetDate': DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  'lastUpdated': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
```

### **2. Utilisation de `set()` au lieu de `update()`**
- **`update()`** : Met à jour les champs existants
- **`set()` avec `merge: true`** : Crée ou met à jour les champs, plus robuste

## 🧪 **Tests de Validation**

### **Test 1 : Vérification de la Structure**
Exécutez le script de diagnostic :
```bash
node scripts/test_vies_structure.mjs
```

**Résultats attendus :**
```
📊 Structure actuelle des vies...
   👤 Utilisateur: [UID]
      📋 Structure des vies:
         - livesRemaining: 5
         - vies.compte: undefined
         - dailyResetDate: [timestamp]
         - lastUpdated: [timestamp]
      ✅ Structure moderne: livesRemaining
```

### **Test 2 : Test de Restauration**
1. Ouvrir l'onglet dev
2. Cliquer sur "💚 Restaurer 5 vies"
3. Vérifier les logs :
```
💚 Restauration des vies pour [UID]...
✅ Vies restaurées à 5 (structure harmonisée)
   📍 Champ utilisé: livesRemaining (comme LifeSyncService)
```

### **Test 3 : Vérification dans Firestore**
Après restauration, vérifier que :
- `livesRemaining` = 5
- `dailyResetDate` = timestamp actuel
- `lastUpdated` = timestamp actuel

## 🔍 **Points de Vérification**

### **1. Logs de DevToolsService**
- ✅ "💚 Restauration des vies pour [UID]..."
- ✅ "✅ Vies restaurées à 5 (structure harmonisée)"
- ✅ "📍 Champ utilisé: livesRemaining (comme LifeSyncService)"

### **2. Logs de LifeSyncService**
- ✅ "🔄 Vérification de la réinitialisation quotidienne..."
- ✅ "📊 Vies actuelles dans Firestore: 5"
- ✅ "✅ Pas de réinitialisation nécessaire, vies actuelles: 5"

### **3. Interface Utilisateur**
- ✅ Affichage des vies mis à jour (5 vies)
- ✅ Bouton de restauration fonctionnel
- ✅ Pas d'erreur dans la console

## 🚀 **Prochaines Étapes**

### **Étape 1 : Test de la Correction**
1. Compiler l'application
2. Tester le bouton "Restaurer 5 vies"
3. Vérifier les logs et l'interface

### **Étape 2 : Validation Complète**
1. Exécuter le script de diagnostic
2. Vérifier la structure dans Firestore
3. Tester le cycle complet (perte de vie → restauration)

### **Étape 3 : Nettoyage (Optionnel)**
Si nécessaire, nettoyer les anciennes structures :
```bash
node scripts/cleanup_firestore_final.mjs
```

## 📋 **Checklist de Diagnostic**

- [ ] **Structure harmonisée** : `livesRemaining` au lieu de `vies.compte`
- [ ] **Logs cohérents** : DevToolsService et LifeSyncService utilisent les mêmes champs
- [ ] **Interface mise à jour** : Affichage des vies correct après restauration
- [ ] **Firestore cohérent** : Structure unifiée pour tous les services
- [ ] **Pas d'erreurs** : Console propre, logs positifs

---

**💡 Conseil** : Le problème était une incohérence de structure. Maintenant que les services utilisent les mêmes champs (`livesRemaining`), le bouton devrait fonctionner correctement !

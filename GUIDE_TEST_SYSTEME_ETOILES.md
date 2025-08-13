# 🧪 Guide de Test - Système d'Étoiles Progressif

## 🎯 **Objectif du Test**
Vérifier que le système d'étoiles suit bien la logique progressive :
- **1ère étoile** : ≥ 8/10 (si pas d'étoile)
- **2ème étoile** : ≥ 8/10 (si 1 étoile déjà)
- **3ème étoile** : **UNIQUEMENT** 10/10 (si 2 étoiles déjà)

## 🔧 **Correction Appliquée**
La méthode `calculateStars` a été corrigée pour empêcher l'obtention directe de 3 étoiles avec 10/10.

## 📋 **Scénarios de Test**

### **Test 1 : Première Mission (U01) - 0 étoiles initiales**

#### **Scénario 1.1 : Score 7/10 (< 8/10)**
- **Attendu** : 0 étoiles (score insuffisant)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=7/10, ratio=0.70, étoiles actuelles=0
   ❌ Score insuffisant (<8/10), garde 0 étoiles
```

#### **Scénario 1.2 : Score 8/10 (≥ 8/10)**
- **Attendu** : 1 étoile (première étoile)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=8/10, ratio=0.80, étoiles actuelles=0
   ✅ 1ère étoile obtenue (≥8/10)
```

#### **Scénario 1.3 : Score 9/10 (≥ 8/10)**
- **Attendu** : 1 étoile (première étoile)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=9/10, ratio=0.90, étoiles actuelles=0
   ✅ 1ère étoile obtenue (≥8/10)
```

#### **Scénario 1.4 : Score 10/10 (≥ 8/10)**
- **Attendu** : 1 étoile (première étoile, pas 3 !)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=10/10, ratio=1.00, étoiles actuelles=0
   ✅ 1ère étoile obtenue (≥8/10)
```

### **Test 2 : Deuxième Tentative (U01) - 1 étoile actuelle**

#### **Scénario 2.1 : Score 7/10 (< 8/10)**
- **Attendu** : 1 étoile (garde l'étoile existante)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=7/10, ratio=0.70, étoiles actuelles=1
   ❌ Score insuffisant (<8/10), garde 1 étoiles
```

#### **Scénario 2.2 : Score 8/10 (≥ 8/10)**
- **Attendu** : 2 étoiles (deuxième étoile)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=8/10, ratio=0.80, étoiles actuelles=1
   ✅ 2ème étoile obtenue (≥8/10)
```

#### **Scénario 2.3 : Score 9/10 (≥ 8/10)**
- **Attendu** : 2 étoiles (deuxième étoile)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=9/10, ratio=0.90, étoiles actuelles=1
   ✅ 2ème étoile obtenue (≥8/10)
```

#### **Scénario 2.4 : Score 10/10 (≥ 8/10)**
- **Attendu** : 2 étoiles (deuxième étoile, pas 3 !)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=10/10, ratio=1.00, étoiles actuelles=1
   ✅ 2ème étoile obtenue (≥8/10)
```

### **Test 3 : Troisième Tentative (U01) - 2 étoiles actuelles**

#### **Scénario 3.1 : Score 7/10 (< 8/10)**
- **Attendu** : 2 étoiles (garde les étoiles existantes)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=7/10, ratio=0.70, étoiles actuelles=2
   ❌ Score insuffisant (<8/10), garde 2 étoiles
```

#### **Scénario 3.2 : Score 8/10 (≥ 8/10)**
- **Attendu** : 2 étoiles (garde les étoiles existantes)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=8/10, ratio=0.80, étoiles actuelles=2
   ⏸️ Garde les étoiles actuelles (2)
```

#### **Scénario 3.3 : Score 9/10 (≥ 8/10)**
- **Attendu** : 2 étoiles (garde les étoiles existantes)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=9/10, ratio=0.90, étoiles actuelles=2
   ⏸️ Garde les étoiles actuelles (2)
```

#### **Scénario 3.4 : Score 10/10 (parfait)**
- **Attendu** : 3 étoiles (troisième étoile, seulement avec 10/10)
- **Logs attendus** :
```
🎯 Calcul étoiles: score=10/10, ratio=1.00, étoiles actuelles=2
   ✅ 3ème étoile obtenue (10/10 parfait)
```

## 🚀 **Comment Tester**

### **Étape 1 : Préparation**
1. Utilisez le bouton "⭐ Remettre toutes les étoiles à 0" pour réinitialiser
2. Vérifiez que U01 a 0 étoiles

### **Étape 2 : Test Progressif**
1. **Test 1.2** : Faites 8/10 sur U01 → Vérifiez 1 étoile
2. **Test 2.2** : Faites 8/10 sur U01 → Vérifiez 2 étoiles
3. **Test 3.2** : Faites 8/10 sur U01 → Vérifiez 2 étoiles (pas de progression)
4. **Test 3.4** : Faites 10/10 sur U01 → Vérifiez 3 étoiles

### **Étape 3 : Vérification des Logs**
Observez les logs dans la console pour confirmer la logique progressive.

## ✅ **Résultats Attendus**

- **8/10 avec 0 étoiles** → 1 étoile ✅
- **8/10 avec 1 étoile** → 2 étoiles ✅
- **8/10 avec 2 étoiles** → 2 étoiles (pas de progression) ✅
- **10/10 avec 2 étoiles** → 3 étoiles ✅
- **10/10 avec 0 étoiles** → 1 étoile (pas 3 !) ✅

## 🔍 **Points de Vérification**

1. **Logs de debug** montrent le calcul correct
2. **Étoiles affichées** correspondent à la logique
3. **Déverrouillage** de la mission suivante après 2 étoiles
4. **Pas de saut** direct à 3 étoiles avec 10/10

---

**💡 Conseil** : Testez étape par étape pour vérifier que chaque niveau d'étoiles est obtenu progressivement !

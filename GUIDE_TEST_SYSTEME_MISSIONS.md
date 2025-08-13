# 🧪 Guide de Test - Système de Missions

## 🎯 **Objectif**
Vérifier que le nouveau système de gestion des missions fonctionne correctement et crée bien les statistiques dans Firestore.

## 📱 **Étapes de Test**

### **1. Préparation**
- ✅ L'application est compilée avec succès
- ✅ Vous êtes connecté à votre compte Firebase
- ✅ Firestore est accessible

### **2. Test de Base - Mission U01**

#### **Étape 1 : Lancer une Mission**
1. **Ouvrez l'application**
2. **Allez sur l'écran d'accueil** (HomeScreen)
3. **Sélectionnez le biome Urbain** (U)
4. **Cliquez sur la mission U01** (doit être déverrouillée)

#### **Étape 2 : Jouer au Quiz**
1. **Répondez aux questions** (essayez d'obtenir 8/10 ou plus)
2. **Terminez le quiz**
3. **Vérifiez la page de fin** (QuizEndPage)

#### **Étape 3 : Vérifier les Logs**
Dans la console de débogage, vous devriez voir :
```
🚀 Début de la mise à jour de la progression pour U01
   Score: 8/10
   Mission ID: U01
📊 Appel du service MissionManagementService...
🔧 MissionManagementService.updateMissionProgress appelé
   Mission ID: U01
   Score: 8/10
   Durée: 300s
👤 Utilisateur connecté: [votre_uid]
🎯 Aucune progression existante, création d'une nouvelle pour U01...
✅ Nouvelle progression créée pour U01
📝 Session créée pour U01 (score: 8/10)
✅ Mission U01 mise à jour complètement
   Score: 8/10 (80%)
   Étoiles: 2
   Tentatives: 1
   Moyenne: 80.0%
   Temps moyen: 300.0s
```

### **3. Vérification dans Firestore**

#### **Collection `progression_missions/U01`**
Après le quiz, vous devriez voir :
```json
{
  "etoiles": 2,
  "meilleurScore": 80,
  "tentatives": 1,
  "deverrouille": true,
  "biome": "U",
  "index": 1,
  "deverrouilleLe": [timestamp],
  "creeLe": [timestamp],
  "derniereMiseAJour": [timestamp],
  "scoresHistorique": [80],
  "moyenneScores": 80.0,
  "tempsHistorique": [300],
  "tempsMoyen": 300.0,
  "derniereDuree": 300,
  "totalQuestions": 10,
  "reponsesCorrectes": 8,
  "reponsesIncorrectes": 2,
  "tauxReussite": 80.0
}
```

#### **Collection `sessions`**
Une nouvelle session devrait être créée :
```json
{
  "idMission": "U01",
  "score": 8,
  "totalQuestions": 10,
  "scorePourcentage": 80,
  "reponses": [...],
  "dureePartie": 300,
  "commenceLe": [timestamp],
  "termineLe": [timestamp],
  "reponsesCorrectes": 8,
  "reponsesIncorrectes": 2,
  "tauxReussite": 80.0
}
```

### **4. Test de Déverrouillage - Mission U02**

#### **Étape 1 : Vérifier le Déverrouillage**
1. **Retournez à l'écran d'accueil**
2. **U02 devrait maintenant être déverrouillée** (car U01 a 2+ étoiles)
3. **Vérifiez dans Firestore** qu'un document `progression_missions/U02` a été créé

#### **Étape 2 : Jouer à U02**
1. **Cliquez sur U02**
2. **Jouez au quiz** (essayez d'obtenir 8/10 ou plus)
3. **Vérifiez que les statistiques se mettent à jour**

### **5. Test des Statistiques**

#### **Étape 1 : Vérifier l'Affichage**
1. **Sur l'écran d'accueil**, les étoiles devraient être visibles
2. **Les missions déverrouillées** devraient avoir leur statut "available"
3. **Les missions verrouillées** devraient avoir leur statut "locked"

#### **Étape 2 : Vérifier les Données**
1. **Ouvrez Firestore Console**
2. **Allez dans `utilisateurs/[votre_uid]/progression_missions`**
3. **Vérifiez que chaque mission a ses statistiques complètes**

## 🔍 **Diagnostic des Problèmes**

### **Si aucune statistique n'est créée :**

#### **Problème 1 : Utilisateur non connecté**
```
⚠️ Aucun utilisateur connecté
```
**Solution :** Vérifiez que vous êtes bien connecté à Firebase Auth

#### **Problème 2 : Erreur dans le service**
```
❌ Erreur lors de la mise à jour de la progression: [erreur]
```
**Solution :** Vérifiez les logs complets pour identifier l'erreur

#### **Problème 3 : Mission non trouvée**
```
⚠️ Aucune mission fournie
```
**Solution :** Vérifiez que `widget.mission` n'est pas null dans QuizEndPage

### **Si les statistiques sont créées mais incomplètes :**

#### **Problème 1 : Données manquantes**
Vérifiez que tous les champs sont bien remplis dans le service

#### **Problème 2 : Erreur de calcul**
Vérifiez que les calculs de moyennes et pourcentages sont corrects

## 📊 **Vérification Finale**

Après avoir joué à plusieurs missions, vous devriez avoir :

1. **Collection `progression_missions`** avec :
   - U01 : statistiques complètes
   - U02 : statistiques complètes (si déverrouillée)
   - Aucune mission verrouillée

2. **Collection `sessions`** avec :
   - Une session par partie jouée
   - Toutes les données remplies correctement

3. **Logs de débogage** clairs et informatifs

## 🚨 **En Cas de Problème**

1. **Vérifiez les logs** dans la console de débogage
2. **Vérifiez Firestore** pour voir ce qui a été créé
3. **Relancez l'application** si nécessaire
4. **Vérifiez la connexion Firebase**

## 🎉 **Succès**

Si tout fonctionne, vous devriez voir :
- ✅ **Statistiques créées** dans Firestore
- ✅ **Sessions enregistrées** avec toutes les données
- ✅ **Missions déverrouillées** automatiquement
- ✅ **Logs clairs** dans la console

---

**Maintenant, testez et dites-moi ce que vous voyez dans les logs et dans Firestore !** 🚀

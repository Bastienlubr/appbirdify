# 🌟 Guide du Système d'Étoiles Progressif

## 🎯 Logique du Système

### **Progression des Étoiles**
1. **1ère étoile** : Minimum 8/10 (80%)
2. **2ème étoile** : Minimum 8/10 (80%) - **après avoir obtenu la 1ère**
3. **3ème étoile** : **Uniquement** avec 10/10 parfait (100%)

### **Règles Importantes**
- ✅ **Les étoiles s'accumulent** (pas de régression)
- ✅ **8/10 ou 9/10** = 1 ou 2 étoiles selon progression
- ✅ **10/10 parfait** = 3 étoiles maximum
- ✅ **Score < 8/10** = Aucune étoile, garde les étoiles actuelles

## 🔓 Déblocage des Missions

### **Déblocage Automatique**
- **2ème étoile obtenue** → Mission suivante déverrouillée automatiquement
- **Exemple** : U01 avec 2 étoiles → U02 déverrouillée

### **Ordre de Déverrouillage**
1. **U01** : Déverrouillée par défaut
2. **U02** : Déverrouillée après 2 étoiles sur U01
3. **U03** : Déverrouillée après 2 étoiles sur U02
4. **U04** : Déverrouillée après 2 étoiles sur U03

## 🧪 Tests à Effectuer

### **Test 1 : Première Étoile**
1. Jouer à U01
2. Obtenir **8/10** ou **9/10**
3. **Résultat attendu** : 1 étoile
4. **Vérifier** : U02 reste verrouillée

### **Test 2 : Deuxième Étoile**
1. Rejouer à U01 (avec 1 étoile déjà)
2. Obtenir **8/10** ou **9/10**
3. **Résultat attendu** : 2 étoiles
4. **Vérifier** : U02 est maintenant déverrouillée

### **Test 3 : Troisième Étoile**
1. Rejouer à U01 (avec 2 étoiles déjà)
2. Obtenir **10/10 parfait**
3. **Résultat attendu** : 3 étoiles
4. **Vérifier** : U02 reste déverrouillée

### **Test 4 : Score Insuffisant**
1. Jouer à U01 (avec étoiles déjà)
2. Obtenir **7/10** ou moins
3. **Résultat attendu** : Garde les étoiles actuelles
4. **Vérifier** : Aucune nouvelle étoile gagnée

## 📊 Vérification dans Firestore

### **Collection `progression_missions`**
```json
{
  "U01": {
    "etoiles": 2,           // Nombre d'étoiles actuelles
    "tentatives": 3,        // Nombre de tentatives
    "moyenneScores": 85.3,  // Moyenne des scores en %
    "scoresHistorique": {   // Oiseaux manqués et fréquence
      "Rouge-gorge": 2,
      "Choucas": 1
    },
    "scoresPourcentagesPasses": [80, 90, 85], // Historique des scores
    "deverrouille": true,
    "deverrouilleLe": "timestamp"
  },
  "U02": {
    "etoiles": 0,
    "deverrouille": true,   // Déverrouillée par U01
    "deverrouillePar": "U01"
  }
}
```

### **Collection `sessions`**
- **Supprimée** complètement (nettoyage effectué)
- Plus de stockage des sessions individuelles

## 🚀 Comment Tester

1. **Lancer l'application**
2. **Jouer à U01** avec différents scores
3. **Observer les logs** dans la console Flutter
4. **Vérifier Firestore** après chaque partie
5. **Tester la progression** des étoiles

## 📝 Logs Attendus

### **1ère Étoile (8/10)**
```
🌟 Nouvelles étoiles gagnées pour U01: 0 → 1
   🎯 1ère étoile obtenue ! (8/10 minimum)
```

### **2ème Étoile (8/10)**
```
🌟 Nouvelles étoiles gagnées pour U01: 1 → 2
   🎯 2ème étoile obtenue ! (8/10 minimum)
   🔓 La mission suivante sera déverrouillée !
🔓 Déverrouillage automatique de la mission suivante (2ème étoile obtenue)
🔓 Mission suivante U02 déverrouillée automatiquement
```

### **3ème Étoile (10/10)**
```
🌟 Nouvelles étoiles gagnées pour U01: 2 → 3
   🎯 3ème étoile obtenue ! (10/10 parfait requis)
```

## ⚠️ Points d'Attention

- **Les étoiles ne régressent jamais**
- **Le déblocage se fait uniquement à la 2ème étoile**
- **10/10 est requis pour la 3ème étoile**
- **Les statistiques sont mises à jour en temps réel**

---

**🎯 Objectif** : Tester que le système respecte exactement cette logique progressive !

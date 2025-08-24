# Guide d'alignement des images d'oiseaux

## Vue d'ensemble

Le système d'alignement intelligent permet de positionner parfaitement chaque oiseau dans la page de détail pour éviter que la tête soit coupée lors du zoom.

## Modes de fonctionnement

### 🔧 Mode Développement (Calibration)
- **Interfaces de calibration visibles**
- Possibilité d'ajuster l'alignement de chaque espèce
- Sauvegarde automatique des réglages
- Aperçu en temps réel des modifications

### 🔒 Mode Production (Verrouillé)
- **Interfaces de calibration masquées**
- Alignements verrouillés et optimisés
- Performance maximale
- Expérience utilisateur finale

## Comment calibrer les alignements

### 1. Calibration individuelle
1. **Ouvrez une fiche d'oiseau** en mode développement
2. **Cliquez sur l'indicateur d'alignement** (badge coloré en haut à droite)
3. **Ajustez avec le curseur** - l'image se met à jour en temps réel
4. **Validez** - l'alignement est sauvegardé automatiquement

### 2. Contrôles disponibles
- **Curseur précis** : -1.0 (très à gauche) à +1.0 (très à droite)
- **Aperçu temps réel** : l'image de fond change pendant l'ajustement
- **Reset** : retour aux valeurs par défaut de la famille
- **Annuler** : retour à l'alignement original

### 3. Panel d'administration
- **Triple-clic** sur l'indicateur d'alignement
- **Statistiques complètes** des espèces calibrées
- **Verrouillage/déverrouillage** du système
- **Basculement mode dev/production**

## Workflow recommandé

### Phase 1 : Calibration (Mode Développement)
```
1. Parcourir toutes les espèces d'oiseaux
2. Identifier celles avec des têtes coupées
3. Calibrer individuellement chaque espèce problématique
4. Vérifier l'alignement sur différentes tailles d'écran
5. Répéter jusqu'à satisfaction complète
```

### Phase 2 : Verrouillage (Mode Production)
```
1. Triple-clic sur un indicateur d'alignement
2. Vérifier les statistiques dans le panel admin
3. Cliquer "Verrouiller en mode production"
4. Confirmer l'action
5. Les interfaces de calibration disparaissent
6. Les alignements sont sauvegardés définitivement
```

## Stockage des données

### Persistance
- **SharedPreferences** : stockage local permanent
- **Sauvegarde automatique** à chaque calibration
- **Cache temporaire** pendant la session de calibration
- **Export/import** possible pour backup

### Priorités d'alignement
1. **Alignements sauvegardés** (persistants)
2. **Alignements temporaires** (session de calibration)
3. **Défauts de famille** (genre d'oiseau)
4. **Centré par défaut**

## Interface utilisateur

### Indicateur d'alignement
- **Couleur** : 🔵 Gauche | 🟢 Centre | 🟠 Droite
- **Description** : "TRÈS À GAUCHE", "CENTRÉ", "LÉGÈREMENT À DROITE", etc.
- **Valeur numérique** : -0.75, 0.00, +0.42, etc.
- **Simple clic** : ouvrir calibration
- **Triple clic** : panel d'administration

### Dialog de calibration
- **Image de l'oiseau** en arrière-plan pour référence
- **Curseur précis** avec 40 graduations
- **Légendes** : "Très à gauche" ↔ "Très à droite"
- **Boutons** : Reset, Annuler, Valider
- **Feedback** : notification de sauvegarde

### Panel d'administration
- **Statut actuel** : mode et état de verrouillage
- **Statistiques** : nombre d'espèces calibrées par position
- **Actions** : verrouiller/déverrouiller le système
- **Confirmation** : dialogs de sécurité pour les actions critiques

## Exemples d'utilisation

### Oiseau avec tête coupée à droite
```
Problème : La tête de l'oiseau disparaît sur le côté droit
Solution : Alignement vers la gauche (-0.3 à -0.7)
Résultat : L'oiseau glisse vers la gauche, tête visible
```

### Oiseau avec bec coupé à gauche
```
Problème : Le bec long de l'oiseau est tronqué à gauche
Solution : Alignement vers la droite (+0.2 à +0.5)
Résultat : L'oiseau glisse vers la droite, bec complet
```

### Oiseau bien centré
```
Situation : L'oiseau est parfaitement visible au centre
Action : Aucune calibration nécessaire
Alignement : 0.0 (centré par défaut)
```

## Migration vers la production

### Quand verrouiller ?
- ✅ Toutes les espèces problématiques sont calibrées
- ✅ Les alignements sont testés et validés
- ✅ Pas d'autres ajustements prévus
- ✅ Application prête pour la livraison

### Comment déverrouiller ?
- Si vous devez faire des ajustements après verrouillage
- Triple-clic → Panel admin → "Réactiver le mode développement"
- Les interfaces de calibration réapparaissent
- Tous les alignements sauvegardés restent intacts

## Bonnes pratiques

### Pour la calibration
- 🎯 **Testez sur différents oiseaux** de la même famille
- 👀 **Vérifiez sur mobile et tablet** via le responsive
- 🔄 **Utilisez l'aperçu temps réel** pour l'ajustement fin
- 💾 **Sauvegardez fréquemment** (automatique à chaque validation)

### Pour la maintenance
- 📊 **Consultez les statistiques** régulièrement
- 🔐 **Verrouillez seulement** quand tout est parfait  
- 📱 **Testez l'expérience finale** en mode production
- 🔄 **Gardez une copie** des alignements si nécessaire

---

**Le système est maintenant prêt pour la phase de calibration !** 🚀

Calibrez toutes les espèces qui en ont besoin, puis verrouillez le système quand vous serez satisfait du résultat.

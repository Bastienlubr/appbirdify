## Scripts Missions (Node ESM)

### Pré-requis
- Node 18+
- Dépendances installées (`npm i`)
- Identifiants Firebase Admin: variable `GOOGLE_APPLICATION_CREDENTIALS` ou fichier `serviceAccountKey.json` à la racine.

### Commande principale
```bash
npx node scripts/missions/creer_ou_completer_progression_utilisateur.mjs --uid=<USER_ID> [--biome=urbain|forestier|...] [--apply] [--limit=20]
```

- Sans `--apply` = dry-run (aucune écriture). Avec `--apply` = écrit dans Firestore.
- `--biome` filtre par biome (détecté via CSV/JSON ou préfixe d'ID).
- `--limit` borne le nombre de missions traitées.

### Sources utilisées
- `assets/Missionhome/etoile mission/missions_data.csv`
- `assets/firebase-import/missions_data.json`

Le script fusionne CSV et JSON par `id`, complète les champs manquants et génère un "seed" minimal pour `progression_missions` en respectant:
- `deverrouille=true` pour l'index 1 du biome
- Champs minimaux: `etoiles`, `tentatives`, `biome`, `index`, `scoresHistorique`, `moyenneScores`

### Sorties
- Résumé en console (created/updated/would-*)
- Export JSON: `data/exports/progression_seed_<uid>.json`

### Notes
- Le script utilise `firebase-admin` côté serveur (pas besoin d’émulateur).
- Respecte la structure `utilisateurs/{uid}/progression_missions/{missionId}`.



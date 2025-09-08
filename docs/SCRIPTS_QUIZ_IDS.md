## Compléter les IDs espèces dans les CSV de Quiz

### Principe
- Source de vérité des espèces: `assets/data/Bank son oiseauxV4.csv` (colonnes: `id_oiseaux`, `Nom_scientifique`, `Nom_anglais`, `Nom_français`, ...)
- Cibles: tous les fichiers CSV de `assets/Quiz/*.csv`.
- Le script remplit uniquement l'ID de la bonne réponse à partir des noms d'espèces (français/scientifique/anglais):
  - `bonne_reponse` → `id_oiseaux`

### Utilisation
- Dry-run (ne modifie pas les fichiers):
```bash
npm run quiz:fill-ids
```
- Appliquer les modifications:
```bash
npm run quiz:fill-ids:apply
```
- Limiter le nombre de fichiers traités:
```bash
node scripts/quiz/fill_species_ids.mjs --limit=5
```

### Détails
- Normalisation des noms: suppression des accents, minuscules, nettoyage ponctuation basique.
- Si l’ID cible est déjà renseigné, il n’est pas remplacé.
- Le writer CSV préserve l’ordre des colonnes existant.



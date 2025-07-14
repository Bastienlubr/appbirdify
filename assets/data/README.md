# Fichiers Audio pour Birdify

Ce dossier contient les fichiers audio pour le quiz sonore de Birdify.

## Structure recommandée

- `bird_sound.mp3` - Son d'oiseau pour le quiz (à créer)
- `oiseaux_nom_en_fr_scientifique_unique.csv` - Base de données des oiseaux
- `birds_test.csv` - Données de test

## Comment ajouter des fichiers audio

1. Placez vos fichiers audio (.mp3, .wav) dans ce dossier
2. Assurez-vous que le nom du fichier correspond à celui utilisé dans `quiz_page.dart`
3. Les fichiers audio doivent être de bonne qualité mais pas trop volumineux (< 5MB)

## Format recommandé

- Format: MP3
- Qualité: 128-192 kbps
- Durée: 5-15 secondes par son d'oiseau
- Nommage: `nom_oiseau.mp3` (ex: `merle_noir.mp3`)

## Test

Pour tester l'application sans fichier audio, vous pouvez :
1. Créer un fichier audio de test nommé `bird_sound.mp3`
2. Ou modifier le chemin dans `quiz_page.dart` vers un fichier existant 
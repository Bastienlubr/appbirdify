# Polices Inter

Ce dossier doit contenir les fichiers de police Inter de Google Fonts.

## Téléchargement

1. Allez sur [Google Fonts - Inter](https://fonts.google.com/specimen/Inter)
2. Téléchargez les variantes suivantes :
   - Inter-Regular.ttf
   - Inter-Medium.ttf
   - Inter-Bold.ttf

## Installation

1. Placez les fichiers .ttf dans ce dossier
2. Les polices sont déjà configurées dans `pubspec.yaml`
3. Redémarrez l'application

## Utilisation

Les polices sont automatiquement utilisées dans l'application via la constante `AppConstants.fontFamily`.

## Alternative

Si vous ne souhaitez pas utiliser Inter, vous pouvez :
1. Modifier `AppConstants.fontFamily` dans `lib/utils/constants.dart`
2. Mettre à jour `pubspec.yaml` avec vos polices
3. Supprimer les références à Inter dans le code 
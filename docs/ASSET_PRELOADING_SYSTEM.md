# Système de Préchargement des Assets - Birdify

## Vue d'ensemble

Le système de préchargement des assets de Birdify garantit que toutes les images et audios nécessaires à une mission sont chargés et prêts avant le lancement du quiz. Cela élimine les effets de flash et les chargements différés pendant l'expérience utilisateur.

## Architecture

### Services Principaux

#### 1. AssetPreloaderService
Service centralisé pour le préchargement fiable des assets (images et audio).

**Fonctionnalités :**
- Préchargement automatique des images et audios pour une mission
- Gestion robuste des erreurs et timeouts
- Support des images locales et Firebase
- Cache intelligent avec statut de préchargement
- Chargement concurrent limité pour optimiser les performances

**Méthodes principales :**
```dart
// Précharger tous les assets d'une mission
Future<AssetPreloadResult> preloadMissionAssets({
  required String missionId,
  required BuildContext context,
  Duration? imageTimeout,
  Duration? audioTimeout,
  int? maxConcurrentLoads,
})

// Vérifier si une image est préchargée
bool isImagePreloaded(String birdName)

// Récupérer une image préchargée
ImageProvider? getPreloadedImage(String birdName)

// Récupérer un audio préchargé
AudioPlayer? getPreloadedAudio(String birdName)
```

#### 2. LocalImageService
Service pour gérer les images locales et fournir des fallbacks.

**Fonctionnalités :**
- Mapping automatique des noms d'oiseaux vers les images locales
- Support de multiples formats d'image (.png, .jpg, .jpeg, .webp)
- Fallback vers les images Firebase si les locales ne sont pas disponibles
- Cache des mappings pour optimiser les performances

**Méthodes principales :**
```dart
// Initialiser le service
Future<void> initialize()

// Vérifier si une image locale existe
bool hasLocalImage(String birdName)

// Récupérer le chemin d'une image locale
String? getLocalImagePath(String birdName)

// Récupérer une ImageProvider avec fallback
ImageProvider getImageProviderWithFallback(String birdName)
```

### Widgets

#### 1. PreloadedImageWidget
Widget spécialisé pour afficher les images préchargées sans effet de flash.

**Fonctionnalités :**
- Affichage fluide des images préchargées
- Animation de fade-in personnalisable
- Gestion des états de chargement et d'erreur
- Support des images locales et Firebase
- Placeholders et indicateurs d'erreur personnalisables

**Utilisation :**
```dart
PreloadedImageWidget(
  birdName: 'Bergeronnette grise',
  width: 280,
  height: 200,
  fit: BoxFit.contain,
  borderRadius: BorderRadius.circular(20),
  fadeInDuration: const Duration(milliseconds: 300),
  showLoadingIndicator: true,
)
```

#### 2. MissionLoadingScreen
Écran de chargement amélioré avec affichage du progrès en temps réel.

**Fonctionnalités :**
- Affichage du progrès de préchargement en temps réel
- Animations fluides et feedback visuel
- Résumé détaillé du chargement (images, audios, durée)
- Gestion des erreurs avec options de retry

### Classes de Données

#### AssetPreloadResult
Résultat détaillé du préchargement des assets.

**Propriétés :**
- `successfulImages`: Liste des images préchargées avec succès
- `failedImages`: Liste des images qui ont échoué
- `successfulAudios`: Liste des audios préchargés avec succès
- `failedAudios`: Liste des audios qui ont échoué
- `duration`: Durée totale du préchargement
- `isSuccess`: Indique si le préchargement a réussi
- `currentStep`: Étape actuelle du processus
- `progress`: Progression (0.0 à 1.0)

## Utilisation

### 1. Préchargement d'une Mission

```dart
final preloaderService = AssetPreloaderService();

final result = await preloaderService.preloadMissionAssets(
  missionId: 'A01',
  context: context,
  imageTimeout: const Duration(seconds: 10),
  audioTimeout: const Duration(seconds: 8),
  maxConcurrentLoads: 3,
);

if (result.isSuccess) {
  // Mission prête, lancer le quiz
  Navigator.push(context, MaterialPageRoute(
    builder: (context) => QuizPage(missionId: 'A01'),
  ));
} else {
  // Gérer les erreurs
  print('Échec du préchargement: ${result.error}');
}
```

### 2. Affichage d'Images Préchargées

```dart
// Dans un widget
PreloadedImageWidget(
  birdName: 'Bergeronnette grise',
  width: 200,
  height: 150,
  fit: BoxFit.cover,
  placeholder: Container(
    color: Colors.grey[200],
    child: Icon(Icons.image, color: Colors.grey[400]),
  ),
  errorWidget: Container(
    color: Colors.red[100],
    child: Icon(Icons.error, color: Colors.red),
  ),
)
```

### 3. Écran de Chargement

```dart
MissionLoadingScreen(
  missionId: 'A01',
  onPreloadComplete: () {
    // Navigation vers le quiz
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (context) => QuizPage(missionId: 'A01'),
    ));
  },
  onPreloadError: () {
    // Gérer l'erreur
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur lors du chargement')),
    );
  },
)
```

## Configuration

### Timeouts
- **Images**: 8 secondes par défaut
- **Audios**: 5 secondes par défaut
- **Données**: 3 secondes par défaut

### Chargement Concurrent
- **Maximum**: 3 chargements simultanés par défaut
- **Configurable** via le paramètre `maxConcurrentLoads`

### Formats d'Images Supportés
- PNG (.png)
- JPEG (.jpg, .jpeg)
- WebP (.webp)

## Gestion des Erreurs

### Types d'Erreurs
1. **Images manquantes**: Images Firebase indisponibles ou images locales non trouvées
2. **Timeouts**: Délais d'attente dépassés
3. **Erreurs réseau**: Problèmes de connectivité
4. **Erreurs de contexte**: BuildContext invalide

### Stratégies de Fallback
1. **Images locales** (priorité 1)
2. **Images Firebase** (priorité 2)
3. **Image par défaut** (priorité 3)

### Logging
Le système utilise des logs détaillés pour le débogage :
- `🔄` : Début d'opération
- `✅` : Succès
- `❌` : Erreur
- `⚠️` : Avertissement
- `📸` : Image locale
- `🗑️` : Nettoyage de cache

## Performance

### Optimisations
- **Cache intelligent**: Évite les rechargements inutiles
- **Chargement concurrent limité**: Évite la surcharge
- **Timeouts configurables**: Évite les blocages
- **Images locales prioritaires**: Chargement plus rapide

### Métriques
- **Temps de préchargement**: Mesuré et affiché
- **Taux de succès**: Suivi des échecs
- **Utilisation mémoire**: Gestion automatique du cache

## Maintenance

### Nettoyage du Cache
```dart
// Nettoyer le cache audio
AssetPreloaderService().clearAudioCache();

// Nettoyer tout le cache
AssetPreloaderService().clearAllCache();
```

### Debug
```dart
// Afficher les mappings d'images locales
LocalImageService().debugImageMappings();

// Vérifier le statut de préchargement
bool isPreloaded = AssetPreloaderService().isImagePreloaded('Bergeronnette grise');
```

## Migration

### Depuis l'Ancien Système
1. Remplacer `MissionPreloader` par `AssetPreloaderService`
2. Remplacer `ResourceManager` par le nouveau système
3. Utiliser `PreloadedImageWidget` au lieu de `Image.network`
4. Mettre à jour les imports

### Exemple de Migration
```dart
// Avant
final result = await MissionPreloader.preloadMissionWithContext(missionId, context);

// Après
final result = await AssetPreloaderService().preloadMissionAssets(
  missionId: missionId,
  context: context,
);
```

## Support

Pour toute question ou problème avec le système de préchargement, consulter :
1. Les logs de débogage dans la console
2. La documentation des services
3. Les exemples d'utilisation dans le code 
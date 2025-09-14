import 'dart:async';

/// Types de récompenses d'étoiles disponibles
enum TypeEtoile {
  uneEtoile,
  deuxEtoiles,
  troisEtoiles
}

/// Types de récompenses utiles secondaires disponibles
enum TypeRecompenseSecondaire {
  coeur,
}

/// Service gérant le système de récompenses utiles
/// Concentré sur les étoiles pour l'avancement progressif du jeu
class RecompensesUtilesService {
  static final RecompensesUtilesService _instance = RecompensesUtilesService._internal();
  factory RecompensesUtilesService() => _instance;
  RecompensesUtilesService._internal();

  final StreamController<Map<String, dynamic>> _recompensesController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get recompensesStream => _recompensesController.stream;

  /// Récompenses actuelles de l'utilisateur
  Map<String, dynamic> _recompensesActuelles = {
    'etoiles_totales': 0,
    'missions_completees': [],
    'animations_disponibles': [],
    // État secondaire
    'secondaire_disponible': false,
    'derniere_secondaire_type': null,
    'animations_secondaires': [],
    'secondaire_vies': 0,
  };

  /// Getter pour les récompenses actuelles
  Map<String, dynamic> get recompensesActuelles => Map.from(_recompensesActuelles);

  /// Obtenir le nombre total d'étoiles
  int get etoilesTotales => _recompensesActuelles['etoiles_totales'] ?? 0;

  /// Obtenir les missions complétées
  List<String> get missionsCompletees => 
      List<String>.from(_recompensesActuelles['missions_completees'] ?? []);

  /// Indique si une récompense secondaire est disponible (à afficher)
  bool get secondaireDisponible => _recompensesActuelles['secondaire_disponible'] == true;

  /// Ajouter des étoiles suite à une mission
  Future<void> ajouterEtoiles(String missionId, TypeEtoile typeEtoile) async {
    int nombreEtoiles = _getNombreEtoiles(typeEtoile);
    
    _recompensesActuelles['etoiles_totales'] = etoilesTotales + nombreEtoiles;
    
    List<String> missions = List<String>.from(missionsCompletees);
    if (!missions.contains(missionId)) {
      missions.add(missionId);
      _recompensesActuelles['missions_completees'] = missions;
    }

    // Ajouter l'animation correspondante
    String animationPath = _getAnimationPath(typeEtoile);
    List<String> animations = List<String>.from(_recompensesActuelles['animations_disponibles'] ?? []);
    if (!animations.contains(animationPath)) {
      animations.add(animationPath);
      _recompensesActuelles['animations_disponibles'] = animations;
    }

    _recompensesController.add(recompensesActuelles);
  }

  /// Ajouter une récompense utile secondaire (ex: coeur)
  Future<void> ajouterRecompenseSecondaire(TypeRecompenseSecondaire type, {int lives = 0}) async {
    _recompensesActuelles['secondaire_disponible'] = true;
    _recompensesActuelles['derniere_secondaire_type'] = type;
    _recompensesActuelles['secondaire_vies'] = lives;

    final String animationPath = _getAnimationPathSecondaire(type);
    final List<String> animations = List<String>.from(_recompensesActuelles['animations_secondaires'] ?? []);
    if (!animations.contains(animationPath)) {
      animations.add(animationPath);
      _recompensesActuelles['animations_secondaires'] = animations;
    }

    _recompensesController.add(recompensesActuelles);
  }

  /// Obtenir le nombre d'étoiles selon le type
  int _getNombreEtoiles(TypeEtoile type) {
    switch (type) {
      case TypeEtoile.uneEtoile:
        return 1;
      case TypeEtoile.deuxEtoiles:
        return 2;
      case TypeEtoile.troisEtoiles:
        return 3;
    }
  }

  /// Obtenir le chemin de l'animation selon le type d'étoiles
  String _getAnimationPath(TypeEtoile type) {
    switch (type) {
      case TypeEtoile.uneEtoile:
        return 'assets/PAGE/Recompenses utiles/1etoile.json';
      case TypeEtoile.deuxEtoiles:
        return 'assets/PAGE/Recompenses utiles/2etoile.json';
      case TypeEtoile.troisEtoiles:
        return 'assets/PAGE/Recompenses utiles/3etoile.json';
    }
  }

  /// Obtenir le chemin de l'animation d'une récompense secondaire
  String _getAnimationPathSecondaire(TypeRecompenseSecondaire type) {
    switch (type) {
      case TypeRecompenseSecondaire.coeur:
        return 'assets/PAGE/Recompenses utiles secondaire/coeur.json';
    }
  }

  /// Obtenir l'animation pour un type d'étoiles
  String getAnimationPourEtoiles(TypeEtoile type) {
    return _getAnimationPath(type);
  }

  /// Obtenir l'animation pour une récompense secondaire
  String getAnimationPourSecondaire(TypeRecompenseSecondaire type) {
    return _getAnimationPathSecondaire(type);
  }

  /// Vérifier si une animation est disponible
  bool isAnimationDisponible(String animationPath) {
    List<String> animations = List<String>.from(_recompensesActuelles['animations_disponibles'] ?? []);
    return animations.contains(animationPath);
  }

  /// Vérifier si une animation secondaire est disponible
  bool isAnimationSecondaireDisponible(String animationPath) {
    List<String> animations = List<String>.from(_recompensesActuelles['animations_secondaires'] ?? []);
    return animations.contains(animationPath);
  }

  /// Initialiser les récompenses (charge depuis la sauvegarde)
  Future<void> initialiserRecompenses() async {
    // TODO: Charger depuis la persistance (Firestore ou local)
    // Pour l'instant, on initialise seulement si aucune donnée n'existe
    if (_recompensesActuelles.isEmpty) {
      _recompensesActuelles = {
        'etoiles_totales': 0,
        'missions_completees': [],
        'animations_disponibles': [],
        'derniere_recompense_type': TypeEtoile.uneEtoile, // Type de la dernière récompense
        // Secondaire
        'secondaire_disponible': false,
        'derniere_secondaire_type': null,
        'animations_secondaires': [],
        'secondaire_vies': 0,
      };
    }
    
    // debugPrint('🔄 Initialisation: ${_recompensesActuelles.isNotEmpty ? "données existantes préservées" : "valeurs par défaut"}');
    // debugPrint('📊 État actuel: $_recompensesActuelles');
    
    _recompensesController.add(recompensesActuelles);
  }

  /// Simuler l'obtention d'étoiles pour les tests DevTools
  Future<void> simulerEtoiles(TypeEtoile typeEtoile, {String missionId = 'TEST'}) async {
    int nombreEtoiles = _getNombreEtoiles(typeEtoile);
    
    _recompensesActuelles['etoiles_totales'] = nombreEtoiles;
    _recompensesActuelles['derniere_recompense_type'] = typeEtoile;
    
    List<String> missions = ['$missionId-${typeEtoile.name}'];
    _recompensesActuelles['missions_completees'] = missions;

    // Ajouter l'animation correspondante
    String animationPath = _getAnimationPath(typeEtoile);
    _recompensesActuelles['animations_disponibles'] = [animationPath];

    // debugPrint('🎯 SIMULATION: $typeEtoile');
    // debugPrint('🎬 Animation path: $animationPath');
    // debugPrint('⭐ Nombre étoiles: $nombreEtoiles');
    // debugPrint('📊 État final: $_recompensesActuelles');

    _recompensesController.add(recompensesActuelles);
  }

  /// Obtenir le type de la dernière récompense
  TypeEtoile get derniereRecompenseType => 
      _recompensesActuelles['derniere_recompense_type'] ?? TypeEtoile.uneEtoile;

  /// Obtenir le type de la dernière récompense secondaire
  TypeRecompenseSecondaire? get derniereRecompenseSecondaireType => 
      _recompensesActuelles['derniere_secondaire_type'] as TypeRecompenseSecondaire?;

  /// Marquer la récompense secondaire comme consommée (après affichage)
  void consommerRecompenseSecondaire() {
    _recompensesActuelles['secondaire_disponible'] = false;
    _recompensesActuelles['secondaire_vies'] = 0;
    _recompensesController.add(recompensesActuelles);
  }

  /// Sauvegarder les récompenses
  Future<void> sauvegarderRecompenses() async {
    // TODO: Implémenter la sauvegarde persistante
    // Sauvegarde des récompenses: $_recompensesActuelles (en dev)
  }

  /// Nettoyer les ressources
  void dispose() {
    _recompensesController.close();
  }
}

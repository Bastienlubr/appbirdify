import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/bird.dart';
import '../../ui/responsive/responsive.dart';
import '../../models/fiche_oiseau.dart';
import '../../services/Perchoir/fiche_oiseau_service.dart';
import '../../data/bird_image_alignments.dart';
import '../../data/bird_alignment_storage.dart';
import '../../widgets/alignment_calibration_dialog.dart';
import '../../widgets/alignment_admin_panel.dart';

// (supprimé) _RoundedTopClipper non utilisé

// -----------------------------------------------------------------------------
// Physique personnalisée pour un carrousel stable (limite l'inertie et l'effet
// ping-pong). On part de PageScrollPhysics pour garder le comportement natif,
// mais on resserre le ressort + plafonne la vélocité.
// -----------------------------------------------------------------------------
class StableCarouselPhysics extends PageScrollPhysics {
  const StableCarouselPhysics({super.parent});

  @override
  StableCarouselPhysics applyTo(ScrollPhysics? ancestor) {
    return StableCarouselPhysics(parent: buildParent(ancestor));
  }

    @override
  SpringDescription get spring => const SpringDescription(
        mass: 8.0,           // Équilibré pour fluidité constante
        stiffness: 1800.0,   // Rigidité optimisée pour tous les modes
        damping: 10.0,       // Amortissement parfait pour la fluidité
       );

  @override
  double carriedMomentum(double existingVelocity) {
    // Momentum ultra-réduit pour des transitions parfaitement contrôlées
    return existingVelocity * 0.01;
  }

  @override
  double get maxFlingVelocity => 120.0;  // Vitesse très limitée pour plus de contrôle

  @override
  double get minFlingVelocity => 500.0;  // Seuil élevé pour éviter les micro-mouvements
}

// -----------------------------------------------------------------------------
// BIRD DETAIL PAGE
// -----------------------------------------------------------------------------
class BirdDetailPage extends StatefulWidget {
  final Bird bird;
  
  const BirdDetailPage({super.key, required this.bird});

  @override
  State<BirdDetailPage> createState() => _BirdDetailPageState();
}

class _BirdDetailPageState extends State<BirdDetailPage>
    with TickerProviderStateMixin {
  // Controllers d'animation
  late final AnimationController _panelController;
  late final Animation<double> _panelAnimation;
  
  // Controllers de pages
  late final PageController _contentController;
  late final PageController _tabController;

  // État UI
  int _selectedTabIndex = 0;
  int _previousTabIndex = 0;
  bool _programmaticAnimating = false;
  bool _showBackground = false;
  bool _isReturning = false;
  bool _isDevMode = true; // Mode dev par défaut
  int _adminTapCount = 0;
  bool _alignmentJustSaved = false;

  // Données et état
  FicheOiseau? _fiche;
  bool _ficheLoading = false;
  int? _familySpeciesCount;
  
  // Alignement optimal pour cette espèce d'oiseau
  late Alignment _optimalImageAlignment;
  
  // Gestion des streams optimisée
  final List<StreamSubscription<FicheOiseau?>> _subscriptions = [];
  Timer? _centeringTimer;

  // Onglets (id, titre, icône, couleur)
  static const List<Map<String, dynamic>> _tabs = [
    {
      'id': 'identification',
      'title': 'Identification',
      'icon': Icons.search,
      'color': Color(0xFF606D7C),
    },
    {
      'id': 'habitat',
      'title': 'Habitat',
      'icon': Icons.landscape,
      'color': Color(0xFFABC270),
    },
    {
      'id': 'alimentation',
      'title': 'Alimentation',
      'icon': Icons.restaurant,
      'color': Color(0xFFFC826A),
    },
    {
      'id': 'reproduction',
      'title': 'Reproduction',
      'icon': Icons.favorite,
      'color': Color(0xFFF899D9),
    },
    {
      'id': 'repartition',
      'title': 'Protection et état actuel',
      'icon': Icons.security,
      'color': Color(0xFFFEC868),
    },
  ];

  int get _nTabs => _tabs.length;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _calculateOptimalImageAlignment();
    _checkDevMode();
    _scheduleInitialAnimations();
    _precacheMainImage();
  }

  /// Initialise tous les controllers d'animation et de page
  void _initializeControllers() {
    _panelController = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _panelAnimation = CurvedAnimation(
      parent: _panelController,
      curve: Curves.easeInOutCubic,
    );
    _panelAnimation.addListener(_onPanelPositionChanged);

    // Initialisation des PageControllers avec seed pour navigation bidirectionnelle
    final seed = _nTabs * 1000;
    _contentController = PageController(initialPage: seed);
    _tabController = PageController(
      initialPage: seed,
      viewportFraction: 0.2,
    );
  }

  /// Calcule l'alignement optimal pour cette espèce d'oiseau
  void _calculateOptimalImageAlignment() {
    // Utiliser l'alignement disponible immédiatement (cache + défauts)
    _optimalImageAlignment = BirdImageAlignments.getOptimalAlignment(
      widget.bird.genus,
      widget.bird.species,
    );
    
    // Charger l'alignement sauvegardé de manière asynchrone si disponible
    _loadSavedAlignment();
    
    // Log pour debug
    assert(() {
      final fineValue = BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species);
      final alignmentDesc = BirdImageAlignments.getAlignmentDescription(widget.bird.genus, widget.bird.species);
      debugPrint('🎯 Alignement initial ${widget.bird.genus} ${widget.bird.species}: $alignmentDesc (${fineValue.toStringAsFixed(2)})');
      debugPrint('🎯 _optimalImageAlignment: ${_optimalImageAlignment.x.toStringAsFixed(2)}');
      return true;
    }());
  }
  
  /// Charge l'alignement sauvegardé de manière asynchrone
  void _loadSavedAlignment() {
    BirdAlignmentStorage.loadAlignment(widget.bird.genus, widget.bird.species).then((savedAlignment) {
      assert(() {
        debugPrint('🔍 Chargement alignement pour ${widget.bird.nomFr}: ${savedAlignment?.toStringAsFixed(2) ?? 'null'}');
        return true;
      }());
      
      if (savedAlignment != null && mounted) {
        setState(() {
          _optimalImageAlignment = Alignment(savedAlignment, 0.0);
        });
        
        assert(() {
          debugPrint('📥 Alignement sauvegardé appliqué: ${widget.bird.nomFr} → ${savedAlignment.toStringAsFixed(2)}');
          debugPrint('📥 _optimalImageAlignment mis à jour: ${_optimalImageAlignment.x.toStringAsFixed(2)}');
          return true;
        }());
      }
    }).catchError((e) {
      assert(() {
        debugPrint('❌ Erreur chargement alignement sauvegardé: $e');
        return true;
      }());
    });
  }
  
  /// Vérifie le mode développement
  void _checkDevMode() {
    BirdImageAlignments.isDevModeEnabled().then((isDevMode) {
      if (mounted) {
        setState(() {
          _isDevMode = isDevMode;
        });
      }
    });
  }

  /// Programme les animations initiales de manière séquencée
  void _scheduleInitialAnimations() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _panelController.value = 0.0; // Panel fermé initialement
      
      // Séquence d'initialisation optimisée - timing équilibré
      Future.delayed(const Duration(milliseconds: 280), _initializeTabCentering);
      Future.delayed(const Duration(milliseconds: 480), _showBackgroundUI);
      Future.delayed(const Duration(milliseconds: 580), _animateInitialPanel);
    });
  }

  /// Initialise le centrage des onglets et démarre l'écoute Firestore
  void _initializeTabCentering() async {
    if (!mounted) return;
    _forceRecenterSelectedTab();
    _startPeriodicCenteringCheck();
    _startWatchingFiche();
  }

  /// Affiche l'arrière-plan UI
  void _showBackgroundUI() {
    if (mounted) {
      setState(() => _showBackground = true);
    }
  }

  /// Anime le panel vers sa position initiale
  void _animateInitialPanel() {
    if (mounted) {
      _panelController.animateTo(
        0.5,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutBack,
      );
    }
  }

  /// Précharge l'image principale pour éviter les flashes
  void _precacheMainImage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.bird.urlImage.isEmpty) return;
      
      precacheImage(
        CachedNetworkImageProvider(widget.bird.urlImage),
        context,
      ).catchError((_) {
        // Ignorer silencieusement les erreurs de préchargement
      });
    });
  }

  // État partagé pour éviter les réceptions multiples
  bool _hasReceivedFicheData = false;

  /// Démarre l'écoute optimisée des données Firestore avec priorité par source
  void _startWatchingFiche() {
    if (_ficheLoading) return;
    
    setState(() => _ficheLoading = true);
    _cancelAllSubscriptions();
    _hasReceivedFicheData = false; // Reset de l'état

    final birdData = _extractBirdData();

    // Configuration des streams avec priorité
    _subscriptions.addAll([
      _createAppIdStream(birdData.appId),
      _createScientificNameStream(birdData.scientific),
      _createFrenchNameStream(birdData.french),
    ]);
  }

  /// Extrait les données de l'oiseau de manière structurée
  ({String appId, String scientific, String french}) _extractBirdData() {
    return (
      appId: '${widget.bird.genus.toLowerCase()}_${widget.bird.species.toLowerCase()}',
      scientific: '${widget.bird.genus} ${widget.bird.species}',
      french: widget.bird.nomFr,
    );
  }

  /// Crée le stream prioritaire par appId
  StreamSubscription<FicheOiseau?> _createAppIdStream(String appId) {
    return FicheOiseauService.watchFicheByAppId(appId).listen(
      (fiche) => _handleFicheReceived(fiche, 'appId=$appId'),
      onError: (_) => _handleFicheError(),
    );
  }

  /// Crée le stream de fallback par nom scientifique
  StreamSubscription<FicheOiseau?> _createScientificNameStream(String scientific) {
    return FicheOiseauService.watchFicheByNomScientifique(scientific).listen(
      (fiche) => _handleFicheReceived(fiche, 'nomSci=$scientific'),
      onError: (_) => _handleFicheError(),
    );
  }

  /// Crée le stream de fallback par nom français
  StreamSubscription<FicheOiseau?> _createFrenchNameStream(String french) {
    return FicheOiseauService.watchFicheByNomFrancais(french).listen(
      (fiche) => _handleFicheReceived(fiche, 'nomFr=$french'),
      onError: (_) => _handleFicheError(),
    );
  }

  /// Gère la réception d'une fiche avec logging optimisé
  void _handleFicheReceived(FicheOiseau? fiche, String source) {
    if (!mounted || fiche == null || _hasReceivedFicheData) return;

    _logFicheReception(fiche, source);
    _hasReceivedFicheData = true;

    setState(() {
      _fiche = fiche;
      _ficheLoading = false;
    });
    
    _maybeLoadFamilyCount();
  }

  /// Gère les erreurs de réception de fiche
  void _handleFicheError() {
    if (mounted) {
      setState(() => _ficheLoading = false);
    }
  }

  /// Log optimisé de la réception de fiche
  void _logFicheReception(FicheOiseau fiche, String source) {
    assert(() {
      try {
        final idLen = fiche.identification.description?.length ?? 0;
        final habLen = fiche.habitat.description?.length ?? 0;
        final alimLen = fiche.alimentation.description?.length ?? 0;
        final reproLen = fiche.reproduction.description?.length ?? 0;
        final repLen = fiche.protectionEtatActuel?.description?.length ?? 0;
        debugPrint('📥 Fiche reçue ($source): id=$idLen, hab=$habLen, alim=$alimLen, repro=$reproLen, prot=$repLen');
      } catch (_) {
        // Ignorer les erreurs de logging
      }
      return true;
    }());
  }

  /// Annule toutes les subscriptions actives
  void _cancelAllSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Charge le nombre d'espèces de la famille de manière optimisée
  Future<void> _maybeLoadFamilyCount() async {
    final family = _fiche?.famille.trim();
    if (family == null || family.isEmpty) return;
    
    try {
      final aggregate = await FirebaseFirestore.instance
          .collection('fiches_oiseaux')
          .where('famille', isEqualTo: family)
          .count()
          .get();
      
      if (mounted) {
        setState(() => _familySpeciesCount = aggregate.count);
      }
    } catch (error) {
      // Log l'erreur en mode debug uniquement
      assert(() {
        debugPrint('Erreur lors du chargement du nombre d\'espèces pour la famille $family: $error');
        return true;
      }());
    }
  }

  @override
  void dispose() {
    _cleanupAnimations();
    _cleanupControllers();
    _cleanupStreams();
    _cleanupTimers();
    super.dispose();
  }

  /// Nettoie les animations et leurs listeners
  void _cleanupAnimations() {
    _panelAnimation.removeListener(_onPanelPositionChanged);
    _panelController.dispose();
  }

  /// Nettoie les controllers de pages
  void _cleanupControllers() {
    _contentController.dispose();
    _tabController.dispose();
  }

  /// Nettoie tous les streams actifs
  void _cleanupStreams() {
    _cancelAllSubscriptions();
  }

  /// Nettoie les timers actifs
  void _cleanupTimers() {
    _centeringTimer?.cancel();
    _centeringTimer = null;
  }

  /// Démarre la vérification périodique optimisée pour maintenir le centrage
  void _startPeriodicCenteringCheck() {
    _centeringTimer?.cancel();
    
    if (!mounted) return;
    
    _centeringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_tabController.hasClients || _programmaticAnimating) {
        timer.cancel();
        return;
      }
      
      _checkAndAdjustTabCentering();
    });
  }

  /// Vérifie et ajuste le centrage des onglets si nécessaire
  void _checkAndAdjustTabCentering() {
    final panelValue = _panelAnimation.value;
    final isInStableMode = panelValue < 0.3 || panelValue > 0.7;
    
    if (!isInStableMode) return;
    
    final targetPage = _nearestPageForIndex(_tabController, _selectedTabIndex);
    final currentPage = _tabController.page ?? _tabController.initialPage.toDouble();
    
    if ((currentPage - targetPage).abs() > 0.15) {
      _tabController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  // État de détection des changements de mode
  bool _wasInExtendedMode = false;
  bool _wasInBasicMode = false;
  bool _isRecenteringScheduled = false;
  bool _miniTitleHidden = false;

  // Méthode appelée quand la position du panel change
  void _onPanelPositionChanged() {
    final isCurrentlyInBasicMode = _panelAnimation.value < 0.3; // Mode 2/3-1/3
    final isCurrentlyInExtendedMode = _panelAnimation.value > 0.7; // Mode étendu
    // Disparition progressive du petit titre après 5s en mode étendu
    if (isCurrentlyInExtendedMode && !_wasInExtendedMode) {
      _miniTitleHidden = false;
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (_panelAnimation.value > 0.7) {
          setState(() => _miniTitleHidden = true);
        }
      });
    }
    if (!isCurrentlyInExtendedMode && _miniTitleHidden) {
      setState(() => _miniTitleHidden = false);
    }
    
    // Détecter TOUTE transition vers un mode stable (2/3-1/3 OU étendu)
    final shouldRecenter = (isCurrentlyInBasicMode && !_wasInBasicMode) || 
                          (isCurrentlyInExtendedMode && !_wasInExtendedMode);
    
    if (shouldRecenter && !_isRecenteringScheduled) {
      _isRecenteringScheduled = true;
      
      // Attendre que l'animation du panel soit complètement terminée
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _forceRecenterSelectedTab();
            _isRecenteringScheduled = false;
          }
        });
      });
    }
    
    // Mettre à jour les états précédents
    _wasInExtendedMode = isCurrentlyInExtendedMode;
    _wasInBasicMode = isCurrentlyInBasicMode;
  }

  // Recentrer l'onglet sélectionné dans le carousel (version douce)
  // (supprimé) _recenterSelectedTab non utilisé

  // Forcer le recentrage (version robuste pour les transitions de mode)
  void _forceRecenterSelectedTab() {
    if (!mounted || !_tabController.hasClients) return;
    
    // Calculer la page cible pour centrer l'onglet sélectionné
    final targetPage = _nearestPageForIndex(_tabController, _selectedTabIndex);
    final currentPage = _tabController.page ?? _tabController.initialPage.toDouble();
    
    // TOUJOURS recentrer, même si ça semble proche
    if ((currentPage - targetPage).abs() > 0.1) {
      _programmaticAnimating = true;
      
      // Animation garantie vers la position centrale
      _tabController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      ).then((_) {
        if (mounted) {
          _programmaticAnimating = false;
          
          // Vérification finale - si toujours pas centré, utiliser jumpToPage
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _tabController.hasClients) {
              final finalPage = _tabController.page ?? _tabController.initialPage.toDouble();
              final finalTarget = _nearestPageForIndex(_tabController, _selectedTabIndex);
              if ((finalPage - finalTarget).abs() > 0.2) {
                _tabController.jumpToPage(finalTarget);
              }
            }
          });
        }
      });
    } else if ((currentPage - targetPage).abs() > 0.05) {
      // Petite correction avec jumpToPage si très proche mais pas parfait
      _tabController.jumpToPage(targetPage);
    }
  }

  // ------------------------------ LOGIQUE "NEAREST PAGE" ---------------------
  // Calcule la page cible la plus proche ayant (page % n == desiredIndex)
  int _nearestPageForIndex(PageController controller, int desiredIndex) {
    final double current =
        controller.hasClients ? (controller.page ?? controller.initialPage.toDouble())
                              : controller.initialPage.toDouble();

    final int currentRound = current.round();
    final int currentMod = ((currentRound % _nTabs) + _nTabs) % _nTabs;

    int diff = desiredIndex - currentMod;
    // Normalise pour prendre le plus court chemin (wrap inclus)
    if (diff > _nTabs / 2) diff -= _nTabs;
    if (diff < -_nTabs / 2) diff += _nTabs;

    return currentRound + diff;
  }

  // ------------------------------ Sélection/Sync -----------------------------
  void _changeSelection(int newIndex) {
    if (newIndex != _selectedTabIndex) {
      setState(() {
        _previousTabIndex = _selectedTabIndex;
        _selectedTabIndex = newIndex;
        // Réaffiche le petit titre à chaque switch d'onglet; il sera masqué à nouveau au bout de 5s en mode étendu
        _miniTitleHidden = false;
      });

      // Si on est déjà en mode étendu, reprogrammer la disparition du petit titre après 3s
      if (_panelAnimation.value > 0.7) {
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          if (_panelAnimation.value > 0.7) {
            setState(() => _miniTitleHidden = true);
          }
        });
      }
      
      // Recentrer l'onglet dans TOUS les modes stables AVEC délai pour éviter conflits
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 50), () {
          final isInBasicMode = _panelAnimation.value < 0.3;
          final isInExtendedMode = _panelAnimation.value > 0.7;
          final isInStableMode = isInBasicMode || isInExtendedMode;
          
          if (isInStableMode && mounted && !_programmaticAnimating && !_isRecenteringScheduled) {
            _forceRecenterSelectedTab(); // Version robuste pour tous les modes
          }
        });
      });
    }
  }

  // Quand on **fait défiler** les onglets - SIMPLE ET DIRECT
  void _onTabCarouselChanged(int pageIndex) {
    if (_programmaticAnimating) return;

    final actualIndex = pageIndex % _nTabs;
    final currentIndex = _selectedTabIndex;
    final diff = (actualIndex - currentIndex + _nTabs) % _nTabs;

    // Autorise les mouvements adjacents + wrap SEULEMENT
    if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
      _changeSelection(actualIndex);

      // Synchronise le contenu INSTANTANÉMENT - pas d'animation concurrente
      if (_contentController.hasClients) {
        final target = _nearestPageForIndex(_contentController, actualIndex);
        _contentController.jumpToPage(target);
      }
    } else if (diff != 0) {
      // Mouvement non autorisé → SNAP vers l'adjacent sans animation
      final targetIndex = diff <= _nTabs ~/ 2
          ? (currentIndex + 1) % _nTabs
          : (currentIndex - 1 + _nTabs) % _nTabs;

      _changeSelection(targetIndex);

      // SNAP instantané pour éviter le wiggle
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, targetIndex);
        _contentController.jumpToPage(t);
      }

      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, targetIndex);
        _tabController.jumpToPage(t);
      }
    }
  }

  // Quand on **tape** un onglet - ANIMATION FLUIDE UNIQUE
  void _onTabSelected(int index) {
    if (_programmaticAnimating) return;

    final currentIndex = _selectedTabIndex;
    final diff = (index - currentIndex + _nTabs) % _nTabs;

    // Autorise adjacent + wrap
    if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
      _programmaticAnimating = true;
      // Ouvre automatiquement le panel en grand si on tape un onglet en mode compact
      if (_panelController.value < 0.75) {
        _panelController.animateTo(
          1.0,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
      _changeSelection(index);

      // Animation SIMULTANÉE des deux PageViews vers la même position
      final duration = const Duration(milliseconds: 280); // Synchronisé avec les onglets
      final curve = Curves.easeOutCubic; // Même courbe que les onglets

      List<Future> animations = [];

      // Contenu → page la plus proche
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, index);
        animations.add(_contentController.animateToPage(t, duration: duration, curve: curve));
      }

      // Onglets → page la plus proche 
      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, index);
        animations.add(_tabController.animateToPage(t, duration: duration, curve: curve));
      }

      // Attendre que TOUTES les animations se terminent
      Future.wait(animations).whenComplete(() => _programmaticAnimating = false);
    } else {
      // Non autorisé → SNAP vers l'adjacent le plus cohérent
      final targetIndex = diff <= _nTabs ~/ 2
          ? (currentIndex + 1) % _nTabs
          : (currentIndex - 1 + _nTabs) % _nTabs;

      _changeSelection(targetIndex);

      // SNAP instantané pour éviter conflit
      if (_contentController.hasClients) {
        final t = _nearestPageForIndex(_contentController, targetIndex);
        _contentController.jumpToPage(t);
      }

      if (_tabController.hasClients) {
        final t = _nearestPageForIndex(_tabController, targetIndex);
        _tabController.jumpToPage(t);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Intercepter le retour pour animer
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _animateReturn();
      },
      child: Scaffold(
        backgroundColor: (_showBackground && !_isReturning)
            ? const Color(0xFFF2F5F8) 
            : Colors.transparent, // Transparent au début/retour puis arrière-plan progressif
        body: LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
          final screenHeight = constraints.maxHeight;

                      return Stack(
                     children: [
               // Image full screen (toujours visible pour l'Hero animation)
               _buildBackgroundImage(screenHeight),

               // Fade d'harmonisation image/panel (temporairement désactivé pour test Hero)
               // if (_showBackground && !_isReturning) _buildImagePanelFade(m, screenHeight),

                             // Bouton retour (masqué pendant le retour)
              if (_showBackground && !_isReturning) _buildBackButton(m),
              
              // Interface de calibration (mode développement uniquement)
              if (_showBackground && !_isReturning && _isDevMode) _buildAlignmentIndicator(m),

              // Panel
              AnimatedBuilder(
                animation: _panelAnimation,
                builder: (context, _) {
                  // Animation simple : 0.0 = caché, 0.33 = 1/3 visible, 1.0 = étendu
                  final minPanelHeight = 0.0; // Complètement caché
                  final initialPanelHeight = screenHeight * 0.33; // 1/3 visible
                  final maxPanelHeight = screenHeight * 0.95; // Mode étendu
                  
                  double currentPanelHeight;
                  if (_panelAnimation.value <= 0.5) {
                    // De caché (0.0) à 1/3 visible (0.5)
                    final progress = (_panelAnimation.value / 0.5).clamp(0.0, 1.0);
                    currentPanelHeight = minPanelHeight + (progress * initialPanelHeight);
                  } else {
                    // De 1/3 visible (0.5) à étendu (1.0)
                    final progress = ((_panelAnimation.value - 0.5) / 0.5).clamp(0.0, 1.0);
                    currentPanelHeight = initialPanelHeight + (progress * (maxPanelHeight - initialPanelHeight));
                  }

                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: _togglePanel,
                      onPanUpdate: (details) {
                        final delta = -details.delta.dy / screenHeight;
                        final newValue = (_panelController.value + delta * 2)
                            .clamp(0.0, 1.0);
                        _panelController.value = newValue;
                      },
                      onPanEnd: _onPanelPanEnd,
                    child: Container(
                        width: double.infinity,
                        height: currentPanelHeight,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(65),
                            topRight: Radius.circular(65),
                          ),
                        boxShadow: [
                          BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 10,
                              offset: Offset(0, -5),
                              spreadRadius: 0,
                            )
                          ],
                        ),
                        child: _buildPanelContent(m),
                      ),
                    ),
                  );
                },
            ),
          ],
        );
      },
      ),
      ),
    );
  }

  /// Animation de retour optimisée avec séquence inverse
  Future<void> _animateReturn() async {
    if (_isReturning) return;
    
    _logReturnAnimation('🔄 Début animation retour...');
    setState(() => _isReturning = true);

    // Fermeture rapide du panel pour préparer l'animation Hero
    _logReturnAnimation('📱 Fermeture du panel...');
    _panelController.animateTo(
      0.0, 
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInCubic,
    );

    // Délai minimal optimisé pour synchroniser avec l'animation
    await Future.delayed(const Duration(milliseconds: 390));
    
    if (mounted) {
      _logReturnAnimation('🚪 Navigation pop - should trigger Hero...');
      Navigator.of(context).pop();
    }
  }

  /// Log optimisé pour l'animation de retour (debug uniquement)
  void _logReturnAnimation(String message) {
    assert(() {
      debugPrint(message);
      return true;
    }());
  }

  // --- Background image ------------------------------------------------------
  Widget _buildBackgroundImage(double screenHeight) {



    return Hero(
      tag: 'bird-hero-${widget.bird.id}',
      transitionOnUserGestures: true,
      flightShuttleBuilder: (context, animation, direction, fromContext, toContext) {
        debugPrint('🚀 Hero animation DECLENCHE: direction=$direction, value=${animation.value}');
        if (direction == HeroFlightDirection.pop) {
          debugPrint('🔙 RETOUR HERO ANIMATION EN COURS ! - Animation visible maintenant');
        }
        
        // Animation simple et visible du contour
        final radiusValue = direction == HeroFlightDirection.push 
            ? 12.0 * (1.0 - animation.value) // 12 -> 0
            : 12.0 * animation.value; // 0 -> 12
        
                 return ClipRRect(
           borderRadius: BorderRadius.circular(radiusValue),
           child: widget.bird.urlImage.isNotEmpty
               ? SizedBox(
                   width: double.infinity,
                   height: double.infinity,
                   child: CachedNetworkImage(
                     imageUrl: widget.bird.urlImage,
                     fit: BoxFit.cover, // Structure 100% identique
                     alignment: _optimalImageAlignment,
                     fadeInDuration: Duration.zero,
                     fadeOutDuration: Duration.zero,
                     filterQuality: FilterQuality.high,
                   ),
                 )
               : Container(
                   color: const Color(0xFFD2DBB2),
                   child: const Center(
                     child: Icon(Icons.image, color: Color(0xFF6A994E), size: 32),
                   ),
                 ),
         );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0.0), // Coins carrés en plein écran
        child: SizedBox(
          width: double.infinity,
          height: screenHeight,
          child: widget.bird.urlImage.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.bird.urlImage,
                  fit: BoxFit.cover, // Page detail garde BoxFit.cover pour remplir l'écran
                  alignment: _optimalImageAlignment,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  filterQuality: FilterQuality.high,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFFD2DBB2),
                    child: const Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Color(0xFF6A994E),
                        size: 32,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFFD2DBB2),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        color: Color(0xFF6A994E),
                        size: 32,
                      ),
                    ),
                  ),
                )
              : Container(
                  color: const Color(0xFFD2DBB2),
                  child: const Center(
                    child: Icon(Icons.image, color: Color(0xFF6A994E), size: 32),
                  ),
                ),
        ),
      ),
    );
  }

  // _buildCenteredHeroTitle supprimé (titre géré dans le panel)

  // --- Back button -----------------------------------------------------------
  Widget _buildBackButton(ResponsiveMetrics m) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
          child: Container(
            width: m.dp(50, tabletFactor: 1.1),
            height: m.dp(50, tabletFactor: 1.1),
            decoration: BoxDecoration(
              color: const Color(0xFF473C33).withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () => _animateReturn(),
              icon: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: m.dp(24, tabletFactor: 1.1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Interface de calibration d'alignement --------------------------------
  Widget _buildAlignmentIndicator(ResponsiveMetrics m) {
    final fineValue = BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species);
    final alignmentDesc = BirdImageAlignments.getAlignmentDescription(widget.bird.genus, widget.bird.species);
    final hasCustom = BirdImageAlignments.hasCustomAlignment(widget.bird.genus, widget.bird.species);
    
    final color = _alignmentJustSaved
        ? Colors.green.shade600 // Vert intense pour confirmation
        : fineValue < -0.1 
            ? Colors.blue
            : fineValue > 0.1 
                ? Colors.orange
                : Colors.green;
    
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Indicateur d'alignement actuel
              GestureDetector(
                onTap: () {
                  _adminTapCount++;
                  
                  // Triple-tap pour accéder au panel d'administration
                  if (_adminTapCount >= 3) {
                    _adminTapCount = 0;
                    _showAdminPanel();
                  } else {
                    // Réinitialiser le compteur après 2 secondes
                    Future.delayed(const Duration(seconds: 2), () {
                      _adminTapCount = 0;
                    });
                    
                    // Simple tap pour calibration
                    _showAlignmentCalibration(m);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: _alignmentJustSaved ? 0.95 : 0.85),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: _alignmentJustSaved ? 8 : 4,
                        offset: const Offset(0, 2),
                      ),
                      if (_alignmentJustSaved) 
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 0),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _alignmentJustSaved
                            ? Icons.check_circle
                            : fineValue < -0.1 
                                ? Icons.keyboard_arrow_left
                                : fineValue > 0.1 
                                    ? Icons.keyboard_arrow_right
                                    : Icons.center_focus_weak,
                        color: Colors.white,
                        size: m.dp(16, tabletFactor: 1.0),
                      ),
                      SizedBox(width: m.dp(4, tabletFactor: 1.0)),
                      Text(
                        _alignmentJustSaved ? 'SAUVEGARDÉ !' : alignmentDesc,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: m.font(12, tabletFactor: 1.0, min: 10, max: 14),
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (hasCustom) ...[
                        SizedBox(width: m.dp(4, tabletFactor: 1.0)),
                        Icon(
                          Icons.star,
                          color: Colors.white,
                          size: m.dp(12, tabletFactor: 1.0),
                        ),
                      ],
                      SizedBox(width: m.dp(4, tabletFactor: 1.0)),
                      Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: m.dp(14, tabletFactor: 1.0),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Valeur numérique fine
              SizedBox(height: m.dp(6, tabletFactor: 1.0)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Valeur: ${fineValue.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: m.font(10, tabletFactor: 1.0, min: 8, max: 12),
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le panel d'administration (triple-tap)
  void _showAdminPanel() {
    showDialog(
      context: context,
      builder: (context) => const AlignmentAdminPanel(),
    ).then((_) {
      // Recharger le mode dev après fermeture du panel
      _checkDevMode();
    });
  }
  
  /// Affiche l'interface de calibration d'alignement
  void _showAlignmentCalibration(ResponsiveMetrics m) {
    showDialog(
      context: context,
      builder: (context) => AlignmentCalibrationDialog(
        bird: widget.bird,
        currentAlignment: BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species),
        onAlignmentChanged: (newAlignment) async {
          assert(() {
            debugPrint('🎯 DÉBUT Validation alignement: ${widget.bird.nomFr} → ${newAlignment.toStringAsFixed(2)}');
            debugPrint('🎯 Alignement AVANT: ${_optimalImageAlignment.x.toStringAsFixed(2)}');
            return true;
          }());
          
          // 1. Mettre à jour l'image IMMÉDIATEMENT avec la nouvelle valeur
          setState(() {
            _optimalImageAlignment = Alignment(newAlignment, 0.0);
            _alignmentJustSaved = true;
          });
          
          assert(() {
            debugPrint('🎯 Alignement APRÈS setState: ${_optimalImageAlignment.x.toStringAsFixed(2)}');
            return true;
          }());
          
          // 2. Sauvegarder l'alignement (le cache est mis à jour immédiatement dans calibrateAlignment)
          await BirdImageAlignments.calibrateAlignment(widget.bird.genus, widget.bird.species, newAlignment);
          
          // 3. Réinitialiser le feedback après 2 secondes
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _alignmentJustSaved = false;
              });
            }
          });
          
          // Log pour confirmation
          assert(() {
            debugPrint('✅ Alignement sauvegardé: ${widget.bird.nomFr} → ${newAlignment.toStringAsFixed(2)}');
            final afterSave = BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species);
            debugPrint('✅ Vérification cache: ${afterSave.toStringAsFixed(2)}');
            return true;
          }());
        },
        onPreviewAlignment: (previewAlignment) {
          // Aperçu en temps réel pendant l'ajustement
          setState(() {
            _optimalImageAlignment = Alignment(previewAlignment, 0.0);
            _alignmentJustSaved = false; // Réinitialiser l'état pendant la preview
          });
        },
      ),
    ).then((_) {
      // Quand le dialog se ferme, garder l'alignement actuel
      assert(() {
        debugPrint('🚪 Dialog fermé, alignement actuel: ${_optimalImageAlignment.x.toStringAsFixed(2)}');
        final cached = BirdImageAlignments.getFineAlignment(widget.bird.genus, widget.bird.species);
        debugPrint('🚪 Cache alignement: ${cached.toStringAsFixed(2)}');
        return true;
      }());
      
      // NE PAS écraser l'alignement - juste réinitialiser le feedback
      setState(() {
        _alignmentJustSaved = false;
      });
    });
  }

  // --- Fade d'harmonisation image/panel (animation progressive) ---



  // --- Panel content ---------------------------------------------------------
  Widget _buildPanelContent(ResponsiveMetrics m) {
    const textColor = Color(0xFF606D7C);

    final showBasicInfo = _panelAnimation.value < 0.7 && _panelAnimation.value > 0.2; // infos visibles quand panel en position 1/3

    return Column(
          children: [
        // Poignée
        Container(
          width: m.dp(40, tabletFactor: 1.1),
          height: m.dp(4, tabletFactor: 1.0),
          margin: EdgeInsets.symmetric(vertical: m.dp(12, tabletFactor: 1.0)),
          decoration: BoxDecoration(
            color: const Color(0x70344356),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Contenu
        Expanded(
          child: NotificationListener<UserScrollNotification>(
            onNotification: (n) {
              // En mode compact (1/3), le premier geste de scroll ouvre le panel en grand
              final isCompact = _panelAnimation.value < 0.75;
              if (isCompact && n.direction != ScrollDirection.idle) {
                _panelController.animateTo(
                  1.0,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOutCubic,
                );
                return true; // on consomme l'événement
              }
              return false;
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8, // Hauteur max raisonnable pour éviter overflow
              ),
              child: SingleChildScrollView(
                physics: _panelAnimation.value < 0.75
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: m.dp(24, tabletFactor: 1.1),
                  right: m.dp(24, tabletFactor: 1.1),
                  top: showBasicInfo ? m.dp(4, tabletFactor: 1.0) : m.dp(16, tabletFactor: 1.0),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                SizedBox(height: showBasicInfo ? m.dp(2, tabletFactor: 1.0) : m.dp(0, tabletFactor: 1.0)),

                // Infos de base (nom, famille)
                if (showBasicInfo) _buildInfoSection(m),

                if (showBasicInfo) SizedBox(height: m.dp(16, tabletFactor: 1.1)),

                // Carrousel d'onglets
                Transform.translate(
                  offset: Offset(0, showBasicInfo ? 0 : -m.dp(0, tabletFactor: 1.1)),
                  child: _buildTabButtons(m),
                ),

                Transform.translate(
                  offset: Offset(0, showBasicInfo ? -m.dp(16, tabletFactor: 1.0) : -m.dp(8, tabletFactor: 1.0)),
                  child: _buildAnimatedTabTitle(m),
                ),

                SizedBox(height: showBasicInfo ? m.dp(12, tabletFactor: 1.1) : m.dp(4, tabletFactor: 1.1)),

                if (!showBasicInfo)
                  Container(
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0x70344356),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),

                SizedBox(height: showBasicInfo ? 0 : m.dp(4, tabletFactor: 1.1)),

                // Titre principal de l'onglet courant (dans le panel, en haut)
                Align(
                  alignment: _panelAnimation.value > 0.7 ? Alignment.center : Alignment.centerLeft,
                        child: Text(
                    _tabs[_selectedTabIndex]['title'],
                    textAlign: _panelAnimation.value > 0.7 ? TextAlign.center : TextAlign.left,
                          style: TextStyle(
                      color: textColor,
                      fontSize: m.font(32, tabletFactor: 1.1, min: 24, max: 40),
                            fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: m.dp(16, tabletFactor: 1.1)),

                // Contenu principal (PageView synchronisé)
                _buildMainContent(m),

                SizedBox(height: m.dp(40, tabletFactor: 1.1)),
                ],
                ),
              ),
            ),
          ),
        ),
          ],
    );
  }

  Widget _buildInfoSection(ResponsiveMetrics m) {
    const labelColor = Color(0xFF606D7C);
    const valueColor = Color(0xFF606D7C);

    final nom = _fiche?.nomFrancais.isNotEmpty == true ? _fiche!.nomFrancais : widget.bird.nomFr;
    final sci = _fiche?.nomScientifique.isNotEmpty == true ? _fiche!.nomScientifique : '${widget.bird.genus} ${widget.bird.species}';
    final fam = _fiche?.famille.isNotEmpty == true ? _fiche!.famille : _familyName;

    return LayoutBuilder(builder: (context, constraints) {
      final baseFont = m.font(16, tabletFactor: 1.0, min: 12, max: 20);
      final minFont = 9.0;

      double measureSepWidth(double fontSize) {
        final tp = TextPainter(
          text: TextSpan(
            text: ' : ',
            style: TextStyle(color: labelColor, fontFamily: 'Quicksand', fontWeight: FontWeight.w300, fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        return tp.size.width;
      }

      double measureLabelWidth(String text, double fontSize) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(color: labelColor, fontFamily: 'Quicksand', fontWeight: FontWeight.w300, fontSize: fontSize),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        return tp.size.width;
      }

      double computeLabelWidth(double fontSize) {
        final w1 = measureLabelWidth('Nom', fontSize);
        final w2 = measureLabelWidth('N. Scientifique', fontSize);
        final w3 = measureLabelWidth('Famille', fontSize);
        // Marge légère pour le séparateur
        final maxW = [w1, w2, w3].reduce((a, b) => a > b ? a : b) + m.dp(4, tabletFactor: 1.0);
        // Cap supérieur (évite gaspillage d'espace)
        final cap = m.dp(125, tabletFactor: 1.1);
        return maxW < cap ? maxW : cap;
      }

      bool fitsAll(double fontSize) {
        final currentLabelWidth = computeLabelWidth(fontSize);
        final valueWidth = constraints.maxWidth - currentLabelWidth - measureSepWidth(fontSize);
        TextPainter p(String t) => TextPainter(
              text: TextSpan(
                text: t,
                style: TextStyle(color: valueColor, fontFamily: 'Quicksand', fontWeight: FontWeight.w500, fontSize: fontSize),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              ellipsis: '…',
            )
              ..layout(maxWidth: valueWidth);
        final p1 = p(nom);
        final p2 = p(sci);
        final p3 = p(fam);
        return !(p1.didExceedMaxLines || p2.didExceedMaxLines || p3.didExceedMaxLines);
      }

      // Réduction homogène uniquement en mode 2/3–1/3 (panel compact)
      final bool isCompact = _panelAnimation.value < 0.3;
      double chosen = baseFont;
      if (isCompact) {
        while (chosen > minFont && !fitsAll(chosen)) {
          chosen -= 0.5;
        }
      }

      final currentLabelWidth = computeLabelWidth(chosen);
      final labelStyle = TextStyle(color: labelColor, fontFamily: 'Quicksand', fontWeight: FontWeight.w300, fontSize: chosen);
      final valueStyle = TextStyle(color: valueColor, fontFamily: 'Quicksand', fontWeight: FontWeight.w500, fontSize: chosen);

      Widget row(String label, String value) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: currentLabelWidth,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
            ),
            Text(' : ', style: labelStyle),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
          ],
        );
      }

      return Column(children: [
        row('Nom', nom),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        row('N. Scientifique', sci),
        SizedBox(height: m.dp(8, tabletFactor: 1.0)),
        row('Famille', fam),
        SizedBox(height: m.dp(16, tabletFactor: 1.1)),
        Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0x70344356),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ]);
    });
  }

  // --- Carrousel d'onglets avec effet fade sur les côtés ------------------
  Widget _buildTabButtons(ResponsiveMetrics m) {
    return SizedBox(
      height: m.dp(90, tabletFactor: 1.1), // Plus de hauteur pour les animations
      child: Stack(
        children: [
          // Le carousel principal
          PageView.builder(
            controller: _tabController,
            onPageChanged: _onTabCarouselChanged,
            physics: const StableCarouselPhysics(),
            pageSnapping: true,
            itemBuilder: (context, pageIndex) {
          final index = pageIndex % _nTabs;
          final tab = _tabs[index];
          final isSelected = index == _selectedTabIndex;
          final wasJustDeselected = index == _previousTabIndex;

          // Seulement les onglets impliqués dans le changement s'animent
          final shouldAnimate = isSelected || wasJustDeselected;

          return Center(
            child: GestureDetector(
              onTap: () => _onTabSelected(index),
              child: shouldAnimate
                  ? TweenAnimationBuilder<double>(
                      key: ValueKey(
                          '$index-${isSelected ? "select" : "deselect"}')
,
                      duration: const Duration(milliseconds: 280), // Plus fluide
                      curve: Curves.easeOutCubic, // Courbe plus naturelle
                      tween: Tween<double>(
                        begin: isSelected ? 0.0 : 1.0,
                        end: isSelected ? 1.0 : 0.0,
                      ),
                      builder: (context, animValue, child) {
                        // Calcul des valeurs interpolées optimisées pour la fluidité
                        final size = 60.0 + (6.0 * animValue); // 60 -> 66 simple
                        final iconSize = 28.0 + (3.0 * animValue); // 28 -> 31 plus modéré
                        final yOffset = -4.0 * animValue; // Montée simple et fluide
                        final colorAlpha = 0.3 + (0.7 * animValue); // 0.3 -> 1.0
                        final titleHeight = 6.0 * animValue; // 0 -> 6 simple
                        final shadowIntensity = 0.15 * animValue; // Ombre plus douce
    
    return Column(
                          mainAxisSize: MainAxisSize.min,
        children: [
                            Transform.translate(
                              offset: Offset(
                                  0.0, yOffset * m.dp(1, tabletFactor: 1.0)),
                              child: Container(
                                width: m.dp(size, tabletFactor: 1.1),
                                height: m.dp(size, tabletFactor: 1.1),
      decoration: BoxDecoration(
                                  color: (tab['color'] as Color)
                                      .withValues(alpha: colorAlpha),
                                  borderRadius: BorderRadius.circular(
                                    m.dp(16, tabletFactor: 1.0),
                                  ),
                                  boxShadow: animValue > 0.5
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15 * shadowIntensity),
                                            blurRadius: 4 + (2 * animValue), // Ombre plus douce
                                            offset: Offset(0, 2 + (1 * animValue)), // Se déplace moins
                                            spreadRadius: 0.5 * animValue, // S'étend moins
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  tab['icon'],
        color: Colors.white,
                                  size:
                                      m.dp(iconSize, tabletFactor: 1.1),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: m.dp(titleHeight, tabletFactor: 1.0),
                              child: animValue > 0.1
                                  ? Padding(
                                      padding: EdgeInsets.only(
                                          top: m.dp(6, tabletFactor: 1.0)),
                                      child: Opacity(
                                        opacity: animValue,
        child: Text(
                                          tab['title'],
            style: TextStyle(
                                            color: const Color(0x7F606D7C),
                                            fontSize: m.font(12,
                                                tabletFactor: 1.0,
                                                min: 10,
                                                max: 16),
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      },
                    )
                  :
                  // Onglets non impliqués : état statique
                  Column(
                    mainAxisSize: MainAxisSize.min,
            children: [
          Container(
                        width: m.dp(60, tabletFactor: 1.1),
                        height: m.dp(60, tabletFactor: 1.1),
            decoration: BoxDecoration(
                          color:
                              (tab['color'] as Color).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(
                            m.dp(16, tabletFactor: 1.0),
                          ),
                        ),
                        child: Icon(
                          tab['icon'],
                          color: Colors.white,
                          size: m.dp(28, tabletFactor: 1.1),
                        ),
                      ),
                      const SizedBox.shrink(),
                  ],
                ),
              ),
          );
        },
      ),
          
          // Masque fade gauche - couleur panel pour effet naturel
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: m.dp(40, tabletFactor: 1.1),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFFF3F5F9), // Couleur de fond du panel
                    const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.2],
          ),
        ),
      ),
          ),
          
          // Masque fade droite - couleur panel pour effet naturel
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: m.dp(60, tabletFactor: 1.1),
      decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    const Color(0xFFF3F5F9), // Couleur de fond du panel
                    const Color(0xFFF3F5F9).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Titre animé de l'onglet sélectionné - petit et toujours visible (disparaît après un délai en mode étendu)
  Widget _buildAnimatedTabTitle(ResponsiveMetrics m) {
    return SizedBox(
      height: m.dp(25, tabletFactor: 1.0), // Plus de hauteur pour éviter la coupure
      child: Align(
        alignment: Alignment.topCenter, // Colle en haut du conteneur
        child: TweenAnimationBuilder<double>(
          key: ValueKey('title-$_selectedTabIndex-$_previousTabIndex'),
          duration: const Duration(milliseconds: 280), // Synchronisé avec les onglets
          curve: Curves.easeOutCubic, // Même courbe que les onglets
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, animValue, child) {
            // Animation entrante optimisée pour fluidité maximale
            final opacity = animValue; // Animation simple et fluide
            final yOffset = 8.0 * (1.0 - animValue); // Descente simple et douce
            final scale = 0.85 + (0.15 * animValue); // Scaling modéré
 
            return AnimatedOpacity(
              opacity: _miniTitleHidden ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              child: Transform.translate(
                offset: Offset(0.0, yOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: opacity,
          child: Text(
                      _tabs[_selectedTabIndex]['title'],
                      textAlign: TextAlign.center,
            style: TextStyle(
                        color: const Color(0x7F606D7C), // Même couleur que sous les onglets
                        fontSize: m.font(12, tabletFactor: 1.0, min: 10, max: 16), // Plus petit
              fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w900, // Même poids que sous les onglets
                        letterSpacing: 0.3,
            ),
          ),
        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Contenu principal synchronisé ----------------------------------------
  Widget _buildMainContent(ResponsiveMetrics m) {
    final showBasicInfo = _panelAnimation.value < 0.7 && _panelAnimation.value > 0.2;
    final baseHeight = showBasicInfo ? 300.0 : 400.0; // Hauteur fixe pour éviter l'overflow

    return SizedBox(
      height: baseHeight,
      child: PageView.builder(
        controller: _contentController,
                 onPageChanged: (pageIndex) {
           if (_programmaticAnimating) return; // éviter ping-pong

           final actualIndex = pageIndex % _nTabs;
           final currentIndex = _selectedTabIndex;
           final diff = (actualIndex - currentIndex + _nTabs) % _nTabs;

           // Autorise adjacent + wrap SEULEMENT
           if (diff == 1 || diff == (_nTabs - 1) || diff == 0) {
             _changeSelection(actualIndex);

             // Synchronise l'onglet INSTANTANÉMENT
             if (_tabController.hasClients) {
               final t = _nearestPageForIndex(_tabController, actualIndex);
               _tabController.jumpToPage(t);
             }
           } else if (diff != 0) {
             // Mouvement non autorisé → SNAP vers l'adjacent
             final targetIndex = diff <= _nTabs ~/ 2
                 ? (currentIndex + 1) % _nTabs
                 : (currentIndex - 1 + _nTabs) % _nTabs;

             _changeSelection(targetIndex);

             // SNAP instantané pour éviter le wiggle
             final t = _nearestPageForIndex(_contentController, targetIndex);
             _contentController.jumpToPage(t);

             if (_tabController.hasClients) {
               final tt = _nearestPageForIndex(_tabController, targetIndex);
               _tabController.jumpToPage(tt);
             }
           }
         },
        // itemCount null => "infini"
        itemCount: null,
        itemBuilder: (context, pageIndex) {
          final index = pageIndex % _nTabs;
          return _buildContentForTab(m, index);
        },
      ),
    );
  }

  Widget _buildContentForTab(ResponsiveMetrics m, int index) {
    final showBasicInfo = _panelAnimation.value < 0.3;

    Widget content;
    switch (_tabs[index]['id']) {
      case 'identification':
        final id = _fiche?.identification;
        final mesures = id?.mesures;
        final ressemblantes = id?.especesRessemblantes;
        final tiles = <Widget>[];
        if ((mesures?.poids?.isNotEmpty ?? false) || (mesures?.taille?.isNotEmpty ?? false) || (mesures?.envergure?.isNotEmpty ?? false)) {
          tiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (mesures?.poids?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Poids', value: mesures!.poids!, m: m),
                  if (mesures?.taille?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Taille', value: mesures!.taille!, m: m),
                  if (mesures?.envergure?.isNotEmpty ?? false)
                    _miniInfoCard(title: 'Envergure', value: mesures!.envergure!, m: m),
                ],
              ),
            ),
          );
        }
        if (ressemblantes?.differenciation?.isNotEmpty ?? false) {
          tiles.add(
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Espèces ressemblantes', style: _subtitleTextStyle(m)),
                const SizedBox(height: 6),
                Text(_fmt(ressemblantes!.differenciation!), style: _contentTextStyle(m)),
              ]),
            ),
          );
        }
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Classification
          Text('Classification', style: _subtitleTextStyle(m)),
          const SizedBox(height: 6),
          Text(_fmt(_buildClassificationSentence()), style: _contentTextStyle(m)),
          if ((_familySpeciesCount ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_fmt('Espèces dans la famille: ${_familySpeciesCount!}'), style: _contentTextStyle(m)),
            ),
          const SizedBox(height: 12),

          // Morphologie
          Text('Morphologie', style: _subtitleTextStyle(m)),
          if ((id?.morphologie?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_fmt(id!.morphologie!), style: _contentTextStyle(m)),
            ),
          if (!(id?.morphologie?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Description morphologique à venir.', style: _contentTextStyle(m)),
            ),
          // 3 informations clés (déjà dans tiles via mesures)
          ...tiles,

          // Chant & cri (depuis sons_oiseaux / xeno-canto à intégrer ultérieurement)
          const SizedBox(height: 16),
          Text('Chant et cri', style: _subtitleTextStyle(m)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _fmt(_buildVocalInfoText()),
              style: _contentTextStyle(m),
            ),
          ),
        ]);
        break;
      case 'habitat':
        final h = _fiche?.habitat;
        final zones = h?.zonesObservation ?? '';
        final mig = h?.migration;
        final mois = mig?.mois;
        // Mini-cartes migration supprimées - informations intégrées dans le texte
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Type de milieu', style: _subtitleTextStyle(m)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_fmt(_getMilieuxText(h?.milieux) ?? 'Information non disponible'), style: _contentTextStyle(m)),
          ),
          if (zones.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Où l\'observer', style: _subtitleTextStyle(m))),
          if (zones.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fmt(zones), style: _contentTextStyle(m))),
          if (_fmt(_buildMigrationSentence(mig?.description, mois?.debut, mois?.fin)).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text('Migration', style: _subtitleTextStyle(m))),
          if (_fmt(_buildMigrationSentence(mig?.description, mois?.debut, mois?.fin)).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(_fmt(_buildMigrationSentence(mig?.description, mois?.debut, mois?.fin)), style: _contentTextStyle(m))),

        ]);
        break;
      case 'alimentation':
        final alim = _fiche?.alimentation;
        final parts = <String>[];
        if (alim?.regimePrincipal != null && alim!.regimePrincipal!.isNotEmpty) {
          parts.add('Régime: ${alim.regimePrincipal}');
        }
        if (alim?.proiesPrincipales.isNotEmpty == true) {
          parts.add('Proies: ${alim!.proiesPrincipales.join(', ')}');
        }
        if (alim?.description != null && alim!.description!.isNotEmpty) {
          parts.add(alim.description!);
        }
        final alimText = parts.isNotEmpty ? parts.join('. ') : 'Données d\'alimentation à venir.';
        content = Text(_fmt(alimText), style: _contentTextStyle(m));
        break;
      case 'reproduction':
        content = _buildReproductionSection(m);
        break;
      case 'repartition':
        final p = _fiche?.protectionEtatActuel;
        final tiles = <Widget>[];
        if (p?.statutFrance?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'France', value: p!.statutFrance!, m: m));
        if (p?.statutMonde?.isNotEmpty ?? false) tiles.add(_miniInfoCard(title: 'Monde', value: p!.statutMonde!, m: m));
        final hasTiles = tiles.isNotEmpty;
        final desc = p?.description ?? '';
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasTiles) Wrap(spacing: 10, runSpacing: 10, children: tiles),
          if (p?.actions?.isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_fmt('Actions: ${p!.actions!}'), style: _contentTextStyle(m))),
          if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_fmt(desc), style: _contentTextStyle(m))),
          if (!hasTiles && desc.isEmpty) Text('Données de protection à venir.', style: _contentTextStyle(m)),
        ]);
        break;
      default:
        content = Text(_fmt('Informations sur ${_tabs[index]['title'].toString().toLowerCase()} du ${widget.bird.nomFr}. '), style: _contentTextStyle(m));
        break;
    }

    if (showBasicInfo) {
      return content; // pas de scroll interne, panel gère le scroll
    } else {
      // Assure un scroll jusqu'au bas de l'écran pour éviter la frustration
      return SingleChildScrollView(
        padding: EdgeInsets.only(bottom: m.dp(40, tabletFactor: 1.0)),
        child: content,
      );
    }
  }

  // --- Section Reproduction (structurée) ------------------------------------
  Widget _buildReproductionSection(ResponsiveMetrics m) {
    final r = _fiche?.reproduction;
    if (r == null) {
      return Text('Données de reproduction à venir.', style: _contentTextStyle(m));
    }

    final periodeText = _formatPeriode(r.periode);
    final nbOeufs = (r.nbOeufsParPondee ?? r.nombreOeufs ?? '').trim();
    final incubation = (r.incubationJours ?? r.dureeIncubation ?? '').trim();
    final saison = (r.saisonReproduction ?? '').trim();
    final nbPontes = (r.nbPontes ?? '').trim();
    final typeNid = (r.typeNid ?? '').trim();

    final headerChips = <Widget>[];
    if (periodeText.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Période de reproduction', value: periodeText, m: m));
    if (saison.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Saison de reproduction', value: saison, m: m));
    if (typeNid.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Type de nid', value: typeNid, m: m));
    if (nbPontes.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Nombre de pontes', value: nbPontes, m: m));
    if (nbOeufs.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Œufs par ponte', value: nbOeufs, m: m));
    if (incubation.isNotEmpty) headerChips.add(_miniInfoCard(title: 'Incubation', value: incubation, m: m));

    final etapes = _buildEtapesReproduction(r, m);
    final desc = (r.description ?? '').trim();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 1) Étapes détaillées en premier
      ...etapes,
      if (desc.isNotEmpty) Text(_fmt(desc), style: _contentTextStyle(m)),
      if (desc.isEmpty && etapes.isEmpty)
        Text('Données de reproduction à venir.', style: _contentTextStyle(m)),
      // 2) Synthèse en bas
      if (headerChips.isNotEmpty) SizedBox(height: m.dp(16, tabletFactor: 1.0)),
      if (headerChips.isNotEmpty)
        Wrap(spacing: 10, runSpacing: 10, children: headerChips),
    ]);
  }

  String _formatPeriode(Periode? periode) {
    if (periode == null) return '';
    final debut = (periode.debutMois ?? '').trim();
    final fin = (periode.finMois ?? '').trim();
    if (debut.isEmpty && fin.isEmpty) return '';
    if (debut.isNotEmpty && fin.isNotEmpty) return '$debut → $fin';
    return debut.isNotEmpty ? debut : fin;
  }

  List<Widget> _buildEtapesReproduction(Reproduction r, ResponsiveMetrics m) {

    // buildLine non utilisé — retiré pour éviter l'avertissement

    String firstDetail(List<String> keys) {
      final d = r.details ?? const {};
      for (final k in keys) {
        final v = d[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    String mergeNonEmpty(List<String> parts) {
      final filtered = parts.where((p) => p.trim().isNotEmpty).toList();
      if (filtered.isEmpty) return '';
      return filtered.join(' — ');
    }

    final String parade = firstDetail(['paradeNuptiale', 'parade', 'periodeNuptiale']);
    final String accouplement = firstDetail(['accouplement']);
    final String nidType = (r.typeNid ?? '').trim();
    final String nidMateriaux = firstDetail(['materiauxNid', 'materiauxDuNid', 'materiaux']);
    final String nidEmplacement = firstDetail(['emplacementNid', 'siteNid', 'emplacement']);
    final String ponteExtras = firstDetail(['ponte', 'periodePonte']);
    final String ponteOeufs = (r.nbOeufsParPondee ?? r.nombreOeufs ?? '').trim();
    final String incubationDuree = (r.incubationJours ?? r.dureeIncubation ?? '').trim();
    final String incubationParents = firstDetail(['incubationMale', 'incubationMâle', 'incubationFemelle', 'incubationParents']);
    final String nourrissage = firstDetail(['nourrissage', 'nourrissageParents', 'dureeNourrissage']);
    final String envol = firstDetail(['ageEnvol', 'envolJeunes', 'envol']);
    final String emancipation = firstDetail(['ageEmancipation', 'émancipation', 'emancipation']);

    final lines = <Map<String, String>>[
      {'title': 'Période nuptiale / parade', 'text': _fmt(parade)},
      {'title': 'Accouplement', 'text': _fmt(accouplement)},
      {
        'title': 'Construction du nid',
        'text': mergeNonEmpty([
          if (nidType.isNotEmpty) 'Type: ${_fmt(nidType)}',
          if (nidMateriaux.isNotEmpty) 'Matériaux: ${_fmt(nidMateriaux)}',
          if (nidEmplacement.isNotEmpty) 'Emplacement: ${_fmt(nidEmplacement)}',
        ]),
      },
      {
        'title': 'Ponte',
        'text': mergeNonEmpty([
          if (ponteOeufs.isNotEmpty) 'Œufs par ponte: ${_fmt(ponteOeufs)}',
          if (ponteExtras.isNotEmpty) _fmt(ponteExtras),
        ]),
      },
      {
        'title': 'Incubation',
        'text': mergeNonEmpty([
          if (incubationDuree.isNotEmpty) 'Durée: ${_fmt(incubationDuree)}',
          if (incubationParents.isNotEmpty) _fmt(incubationParents),
        ]),
      },
      {'title': 'Nourrissage', 'text': _fmt(nourrissage)},
      {'title': 'Envol des jeunes', 'text': _fmt(envol)},
      {'title': 'Émancipation', 'text': _fmt(emancipation)},
    ].where((row) => row['text']!.trim().isNotEmpty).toList();

    if (lines.isEmpty) return [];
    return [
      for (final row in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row['title']!, style: _subtitleTextStyle(m)),
              const SizedBox(height: 4),
              Text(row['text']!, style: _contentTextStyle(m)),
            ],
          ),
        ),
    ];
  }

  TextStyle _contentTextStyle(ResponsiveMetrics m, {bool underline = false}) {
    return TextStyle(
      color: const Color(0xFF606D7C),
      fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w500,
      decoration: underline ? TextDecoration.underline : null,
      height: 1.4,
    );
  }

  TextStyle _subtitleTextStyle(ResponsiveMetrics m) {
    return TextStyle(
      color: const Color(0xFF606D7C),
      fontSize: m.font(15, tabletFactor: 1.0, min: 13, max: 18),
      fontFamily: 'Quicksand',
      fontWeight: FontWeight.w700,
      height: 1.3,
    );
  }

  String _buildClassificationSentence() {
    final nom = _fiche?.nomFrancais.isNotEmpty == true ? _fiche!.nomFrancais : widget.bird.nomFr;
    final sci = _fiche?.nomScientifique.isNotEmpty == true
        ? _fiche!.nomScientifique
        : '${widget.bird.genus} ${widget.bird.species}';
    final fam = _fiche?.famille.isNotEmpty == true ? _fiche!.famille : _familyName;
    final ordre = _fiche?.ordre.isNotEmpty == true ? _fiche!.ordre : '';
    final familleCount = _familySpeciesCount;

    String buildFamilyPhrase(String famille) {
      if (familleCount != null && familleCount > 1) {
        return "la famille des $famille, qui compte $familleCount espèces";
      }
      return "la famille des $famille";
    }

    if (fam.isNotEmpty && ordre.isNotEmpty) {
      final famillePhrase = buildFamilyPhrase(fam);
      return _fmt("L'espèce $nom ($sci) appartient à $famillePhrase, au sein de l'ordre des $ordre.");
    }
    if (fam.isNotEmpty) {
      final famillePhrase = buildFamilyPhrase(fam);
      return _fmt("L'espèce $nom ($sci) appartient à $famillePhrase.");
    }
    if (ordre.isNotEmpty) {
      return _fmt("L'espèce $nom ($sci) relève de l'ordre des $ordre.");
    }
    return _fmt("L'espèce $nom ($sci).");
  }



  String? _getMilieuxText(dynamic milieux) {
    if (milieux == null) return null;
    if (milieux is String) return milieux;
    if (milieux is List && milieux.isNotEmpty) {
      return milieux.first.toString();
    }
    return null;
  }

  String _buildVocalInfoText() {
    // Placeholder: on s'appuie pour l'instant sur l'URL audio Firebase si disponible.
    // Intégration Xeno-canto (licence commerciale) à brancher côté back si besoin.
    final hasAudio = widget.bird.urlMp3.isNotEmpty;
    if (hasAudio) {
      return "Un enregistrement est disponible dans l'application. Une intégration élargie (Xeno‑canto) sera ajoutée lorsque les licences compatibles auront été confirmées.";
    }
    return "Informations à venir. Une intégration des chants et cris (sources compatibles) est prévue.";
  }

  // Fonction non référencée — retirée pour éviter l'avertissement 'unused_element'
  /*
  String _buildZonesObservationSentence(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    // Si le texte commence déjà par notre préfixe, le renvoyer tel quel (ponctuation normalisée)
    final lower = text.toLowerCase();
    final normalized = lower.replaceAll(RegExp(r"\s+"), ' ');
    final alreadyPrefixed = normalized.startsWith("on peut l'observer") ||
        normalized.startsWith("on peut l'observer") ||
        normalized.startsWith("où l'observer") ||
        normalized.startsWith("où l'observer") ||
        normalized.startsWith("ou l'observer");
    if (alreadyPrefixed) {
      return _ensurePeriod(_fmt(text));
    }

    // Transformer une liste brute en phrase naturelle, en évitant "à à ..."
    final parts = text
        .split(RegExp(r'[;,/]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    String buildTarget(List<String> items) {
      final joined = items.length <= 1 ? (items.isEmpty ? '' : items.first) : _joinWithAnd(items);
      final beginsWithPrep = RegExp(r'^(à|au|aux|en|dans|sur)\b', caseSensitive: false).hasMatch(joined);
      final prefix = "On peut l'observer notamment"; // apostrophe typographique
      return beginsWithPrep ? "$prefix $joined." : "$prefix à $joined.";
    }

    return _fmt(buildTarget(parts));
  }
  */

  // _joinWithAnd non utilisé — retiré

  String _buildMigrationSentence(String? description, String? debut, String? fin) {
    String result = '';
    
    if (description != null && description.trim().isNotEmpty) {
      result = description.trim();
    }
    
    // Si on a des mois de migration, on les intègre naturellement
    if ((debut != null && debut.trim().isNotEmpty) || (fin != null && fin.trim().isNotEmpty)) {
      final monthsParts = <String>[];
      if (debut != null && debut.trim().isNotEmpty) monthsParts.add(debut.trim());
      if (fin != null && fin.trim().isNotEmpty) monthsParts.add(fin.trim());
      
      if (monthsParts.isNotEmpty) {
        final monthsText = monthsParts.length == 2 
            ? 'départ ${monthsParts[0]}, retour ${monthsParts[1]}'
            : monthsParts[0];
            
        if (result.isEmpty) {
          result = 'Migration $monthsText';
        } else {
          // Si la description ne contient pas déjà de mois, on les ajoute
          final monthNames = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 
                             'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
          final hasMonthsInDesc = monthNames.any((month) => result.toLowerCase().contains(month));
          
          if (!hasMonthsInDesc) {
            result = '$result ($monthsText)';
          }
        }
      }
    }
    
    return _fmt(result);
  }

  // Normalise une partie de la ponctuation (apostrophes, espaces fines) pour un rendu agréable
  String _fmt(String input) {
    var s = input
        .replaceAll("'", "'")
        .replaceAll(' :', ' :')
        .replaceAll(' ;', ' ;');
    // Traits d'union fléchés si présents
    s = s.replaceAll('->', '→');
    // Espaces autour des tirets demi-cadratins
    s = s.replaceAll(' - ', ' — ');
    // Corriger les doubles points
    s = s.replaceAll('..', '.');
    return s;
  }

  // _ensurePeriod non utilisé — retiré

  Widget _miniInfoCard({required String title, required String value, required ResponsiveMetrics m}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _contentTextStyle(m, underline: true)),
          const SizedBox(height: 4),
          Text(_fmt(value), style: _contentTextStyle(m)),
        ],
      ),
    );
  }

  // --- Helpers panel ---------------------------------------------------------
  void _togglePanel() {
    if (_panelController.value < 0.75) {
      _panelController.animateTo(1.0,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic);
    } else {
      _panelController.animateTo(0.5, // Retour à la position 1/3 au lieu de 0.0
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    }
  }

  void _onPanelPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity.abs() > 500) {
      if (velocity < 0) {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic);
      } else {
        _panelController.animateTo(0.5, // Retour à la position 1/3 au lieu de 0.0
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic);
      }
    } else {
      if (_panelController.value < 0.75) {
        _panelController.animateTo(0.5, // Retour à la position 1/3 au lieu de 0.0
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic);
      } else {
        _panelController.animateTo(1.0,
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOutCubic);
      }
    }
  }

  String get _familyName => '${widget.bird.genus}idés';
}

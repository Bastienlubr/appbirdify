import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../ui/responsive/responsive.dart';
import '../../models/bird.dart';
import '../../services/Mission/communs/commun_gestionnaire_assets.dart';
import '../../data/bird_image_alignments.dart';
import '../../services/Users/favorites_service.dart';
import 'bird_detail_page.dart';

class BaseOrnithoPage extends StatefulWidget {
  const BaseOrnithoPage({super.key});

  @override
  State<BaseOrnithoPage> createState() => _BaseOrnithoPageState();
}

class _BaseOrnithoPageState extends State<BaseOrnithoPage>
    with AutomaticKeepAliveClientMixin {
  // État de chargement
  bool _isLoading = true;
  
  // Données principales
  List<Bird> _birds = [];
  List<Bird> _displayedBirds = []; // Cache intelligent des résultats
  
  // Filtres et tri
  String _query = '';
  bool _sortAsc = true;
  bool _dense = false;
  final Set<String> _selectedMilieux = <String>{};
  final Set<String> _favoriteIds = <String>{};
  bool _showOnlyFavorites = false;
  
  // Cache pour optimisations
  String? _lastQuery;
  Set<String>? _lastSelectedMilieux;
  bool? _lastShowOnlyFavorites;
  bool? _lastSortAsc;

  @override
  bool get wantKeepAlive => true;

  void _applyChange(VoidCallback applyChange) {
    applyChange();
    _updateDisplayedBirds();
    setState(() {});
  }

  /// Cache intelligent : recalcule uniquement si les paramètres ont changé
  void _updateDisplayedBirds() {
    // Vérifier si un recalcul est nécessaire
    final currentQuery = _query.trim();
    final currentMilieux = Set<String>.from(_selectedMilieux);
    
    if (_lastQuery == currentQuery &&
        _lastSelectedMilieux != null && 
        _setEquals(_lastSelectedMilieux!, currentMilieux) &&
        _lastShowOnlyFavorites == _showOnlyFavorites &&
        _lastSortAsc == _sortAsc &&
        _displayedBirds.isNotEmpty) {
      return; // Pas de changement, utiliser le cache
    }
    
    // Sauvegarder l'état actuel
    _lastQuery = currentQuery;
    _lastSelectedMilieux = currentMilieux;
    _lastShowOnlyFavorites = _showOnlyFavorites;
    _lastSortAsc = _sortAsc;
    
    // Recalculer
    _displayedBirds = _computeFilteredBirds();
  }

  /// Calcule la liste filtrée et triée des oiseaux
  List<Bird> _computeFilteredBirds() {
    // Commencer avec tous les oiseaux valides
    final validBirds = _birds.where((bird) {
      final key = _normalizeForSort(bird.nomFr);
      return key.isNotEmpty && RegExp(r'^[a-z]').hasMatch(key);
    });
    
    // Appliquer les filtres en séquence
    Iterable<Bird> filtered = validBirds;
    
    // Filtre par query
    if (_query.trim().isNotEmpty) {
      final queryNormalized = _normalizeForSort(_query.trim());
      filtered = filtered.where((bird) {
        final nameKey = _normalizeForSort(bird.nomFr);
        final speciesKey = _normalizeForSort(bird.species);
        return nameKey.contains(queryNormalized) || speciesKey.contains(queryNormalized);
      });
    }
    
    // Filtre par biomes
    if (_selectedMilieux.isNotEmpty) {
      filtered = filtered.where((bird) => _birdMatchesSelectedBiomes(bird, _selectedMilieux));
    }
    
    // Filtre favoris
    if (_showOnlyFavorites) {
      filtered = filtered.where((bird) => _favoriteIds.contains(bird.id));
    }
    
    // Trier et retourner
    final result = filtered.toList();
    result.sort((a, b) {
      final comparison = _normalizeForSort(a.nomFr).compareTo(_normalizeForSort(b.nomFr));
      return _sortAsc ? comparison : -comparison;
    });
    
    return result;
  }

  /// Utilitaire pour comparer les ensembles
  bool _setEquals<T>(Set<T> set1, Set<T> set2) {
    return set1.length == set2.length && set1.containsAll(set2);
  }

  /// Configuration de grille optimisée
  ({int crossAxisCount, double spacing, double aspectRatio}) _computeGridConfiguration(ResponsiveMetrics m) {
    final int baseCols = m.isTablet ? (m.isWide ? 5 : 4) : 2;
    final int crossAxisCount = _dense ? (m.isTablet ? baseCols + 1 : 3) : baseCols;
    final double spacing = m.dp(10, tabletFactor: 1.1);
    final double aspectRatio = _dense ? 0.78 : 0.72;
    
    return (
      crossAxisCount: crossAxisCount,
      spacing: spacing,
      aspectRatio: aspectRatio,
    );
  }

  void _toggleBiomeSelection(String biomeKey, bool selected) {
    final changed = selected ? _selectedMilieux.add(biomeKey) : _selectedMilieux.remove(biomeKey);
    if (changed) {
      _updateDisplayedBirds();
      setState(() {});
    }
  }

  void _onSearchChanged(String value) {
    if (_query != value) {
      _query = value;
      _updateDisplayedBirds();
      setState(() {});
    }
  }

  void _toggleDensity() {
    setState(() {
      _dense = !_dense;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAllBirds();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Précharger les images après la première construction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _precacheVisibleImages();
    });
  }

  /// Précharge intelligemment les images visibles
  void _precacheVisibleImages() {
    if (_displayedBirds.isEmpty) return;
    
    // Précharger uniquement les 12 premières images (première vue)
    final imagesToPreload = _displayedBirds.take(12).where((bird) => bird.urlImage.isNotEmpty);
    
    for (final bird in imagesToPreload) {
      precacheImage(
        CachedNetworkImageProvider(bird.urlImage),
        context,
      ).catchError((_) {
        // Ignorer silencieusement les erreurs de préchargement
      });
    }
  }

  /// Charge tous les oiseaux de manière optimisée
  Future<void> _loadAllBirds() async {
    try {
      await MissionPreloader.loadBirdifyData();
      final names = MissionPreloader.getAllBirdNames();
      
      // Construction optimisée de la liste
      final birds = names
          .map((name) => MissionPreloader.getBirdData(name))
          .where((bird) => bird != null)
          .cast<Bird>()
          .toList();
      
      // Tri une seule fois à la source
      birds.sort((a, b) => a.nomFr.toLowerCase().compareTo(b.nomFr.toLowerCase()));
      
      if (mounted) {
        _birds = birds;
        _updateDisplayedBirds();
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Log l'erreur en mode debug
        assert(() {
          debugPrint('Erreur lors du chargement des oiseaux: $error');
          return true;
        }());
      }
    }
  }

  /// Charge les favoris de manière optimisée
  Future<void> _loadFavorites() async {
    try {
      final favorites = await FavoritesService.getFavoriteIds();
      if (mounted) {
        _favoriteIds
          ..clear()
          ..addAll(favorites);
        setState(() {});
      }
    } catch (error) {
      // Log l'erreur en mode debug
      assert(() {
        debugPrint('Erreur lors du chargement des favoris: $error');
        return true;
      }());
    }
  }

  /// Toggle favori avec gestion d'erreur robuste
  Future<void> _toggleFavorite(Bird bird) async {
    // Optimisation UI : mise à jour immédiate pour fluidité
    final wasLoved = _favoriteIds.contains(bird.id);
    setState(() {
      if (wasLoved) {
        _favoriteIds.remove(bird.id);
      } else {
        _favoriteIds.add(bird.id);
      }
    });

    try {
      final actualState = await FavoritesService.toggleFavorite(bird.id);
      
      // Vérifier la cohérence avec l'état local
      if (mounted && (actualState != !wasLoved)) {
        setState(() {
          if (actualState) {
            _favoriteIds.add(bird.id);
          } else {
            _favoriteIds.remove(bird.id);
          }
        });
      }
    } catch (error) {
      // Restaurer l'état en cas d'erreur
      if (mounted) {
        setState(() {
          if (wasLoved) {
            _favoriteIds.add(bird.id);
          } else {
            _favoriteIds.remove(bird.id);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour des favoris'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final gridConfig = _computeGridConfiguration(m);

        return SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: m.spacing, vertical: m.gapMedium()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Répertoire des Oiseaux',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: m.font(24, tabletFactor: 1.1, min: 20, max: 40),
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF344356),
                      ),
                    ),
                    SizedBox(height: m.gapSmall()),
                    Text(
                      'Identifiez, écoutez, observez',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: m.font(16, tabletFactor: 1.05, min: 13, max: 22),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF57534E),
                      ),
                    ),
                    SizedBox(height: m.gapMedium()),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: m.dp(48, tabletFactor: 1.0),
                            child: TextField(
                              onChanged: _onSearchChanged, // ✅ Utilise le cache
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Rechercher une espèce...',
                                hintStyle:
                                    const TextStyle(fontFamily: 'Quicksand'),
                                prefixIcon: const Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: m.dp(16), vertical: 0),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD6D3D1), width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFD6D3D1), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF6A994E), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: m.gapSmall()),
                    // Ligne de chips filtres (milieux)
                    SizedBox(
                      height: m.dp(40),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _buildFilterChips(m),
                      ),
                    ),
                    SizedBox(height: m.gapSmall()),
                    // Label A-Z / tri
                    GestureDetector(
                      onTap: () => _applyChange(
                          () => _sortAsc = !_sortAsc),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _sortAsc ? 'A-Z ' : 'Z-A ',
                              style: TextStyle(
                                color: const Color(0xFF57534E),
                                fontSize: m.font(16, tabletFactor: 1.05, min: 13, max: 22),
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
                                height: 1.60,
                              ),
                            ),
                            TextSpan(
                              text: 'Classés par ordre alphabétique',
                              style: TextStyle(
                                color: const Color(0xFF57534E),
                                fontSize: m.font(13,
                                    tabletFactor: 1.05, min: 12, max: 20),
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w500,
                                height: 1.60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: m.gapSmall()),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : CustomScrollView(
                              slivers: [
                                for (final entry in _groupByFirstLetter(_displayedBirds).entries) ...[
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: m.gapSmall(),
                                        bottom: m.dp(6),
                                      ),
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontFamily: 'Quicksand',
                                          fontWeight: FontWeight.w900,
                                          fontSize: m.font(18, tabletFactor: 1.0, min: 14, max: 24),
                                          color: const Color(0xFF57534E),
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.only(bottom: m.gapSmall()),
                                    sliver: SliverGrid(
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridConfig.crossAxisCount,
                                        mainAxisSpacing: gridConfig.spacing,
                                        crossAxisSpacing: gridConfig.spacing,
                                        childAspectRatio: gridConfig.aspectRatio,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, idx) {
                                          final bird = entry.value[idx];
                                          return _SimpleBirdTile(
                                            bird: bird,
                                            imageRadius: m.dp(12, tabletFactor: 1.05),
                                            isFavorite: _favoriteIds.contains(bird.id),
                                            onFavoriteToggle: () => _toggleFavorite(bird),
                                          );
                                        },
                                        childCount: entry.value.length,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              // Bouton temporaire (à supprimer plus tard): ajuste la densité de la grille
              Positioned(
                right: m.dp(12),
                bottom: m.dp(12),
                child: Material(
                  color: const Color(0xFF6A994E),
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleDensity,
                    child: Padding(
                      padding: EdgeInsets.all(m.dp(12)),
                      child: Icon(_dense ? Icons.view_comfortable : Icons.view_comfy,
                          color: const Color(0xFFFEC868), size: m.dp(22)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

extension _Filters on _BaseOrnithoPageState {
  List<Widget> _buildFilterChips(ResponsiveMetrics m) {
    return [
      _buildFavoriteChip(m),
      ..._buildBiomeChips(m),
    ];
  }

  Widget _buildFavoriteChip(ResponsiveMetrics m) {
    return Padding(
      padding: EdgeInsets.only(right: m.gapSmall()),
      child: FilterChip(
        selected: _showOnlyFavorites,
        onSelected: (selected) => _applyChange(() => _showOnlyFavorites = selected),
        backgroundColor: Colors.pink[100],
        selectedColor: Colors.pink,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showOnlyFavorites ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: _showOnlyFavorites ? Colors.white : Colors.pink,
            ),
            const SizedBox(width: 4),
            Text(
              'Favoris',
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: _showOnlyFavorites ? Colors.white : Colors.pink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        shape: StadiumBorder(
          side: BorderSide(color: Colors.pink.withValues(alpha: 0.3), width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: m.dp(12), vertical: m.dp(10)),
      ),
    );
  }

  List<Widget> _buildBiomeChips(ResponsiveMetrics m) {
    const biomes = ['Urbain', 'Forestier', 'Agricole', 'Humide', 'Montagnard', 'Littoral'];
    
    return biomes.map((biome) => Padding(
      padding: EdgeInsets.only(right: m.gapSmall()),
      child: FilterChip(
        selected: _selectedMilieux.contains(biome.toLowerCase()),
        onSelected: (selected) => _toggleBiomeSelection(biome.toLowerCase(), selected),
        backgroundColor: const Color(0xFF6A994E),
        selectedColor: const Color(0xFF6A994E),
        label: Text(
          biome,
          style: const TextStyle(
            fontFamily: 'Quicksand',
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: const StadiumBorder(
          side: BorderSide(color: Color(0x2D000000), width: 1),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: m.dp(16), vertical: m.dp(10)),
      ),
    )).toList();
  }
}

extension _SortNormalize on _BaseOrnithoPageState {
  String _normalizeForSort(String input) {
    String n = input.toLowerCase().trim();
    const Map<String, String> map = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a',
      'ç': 'c',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
      'ñ': 'n',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ý': 'y', 'ÿ': 'y',
      'œ': 'o', 'Œ': 'o', 'æ': 'a', 'Æ': 'a',
      '’': '\'', '‘': '\'', 'ʼ': '\'',
    };
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i < n.length; i++) {
      final ch = n[i];
      sb.write(map[ch] ?? ch);
    }
    n = sb.toString();
    n = n.replaceAll(RegExp(r"[^a-z0-9\s\-]"), "");
    n = n.replaceAll(RegExp(r"\s+"), " ").trim();
    return n;
  }

  Map<String, List<Bird>> _groupByFirstLetter(List<Bird> birds) {
    final Map<String, List<Bird>> groups = {};
    for (final b in birds) {
      final key = _normalizeForSort(b.nomFr);
      if (key.isEmpty) continue;
      final String letter = key[0].toUpperCase();
      (groups[letter] ??= <Bird>[]).add(b);
    }
    final sortedKeys = groups.keys.toList()..sort();
    final Map<String, List<Bird>> ordered = {};
    for (final k in sortedKeys) {
      ordered[k] = groups[k]!;
    }
    return ordered;
  }
}

bool _birdMatchesSelectedBiomes(Bird b, Set<String> selected) {
  // Normaliser les noms de biomes stockés côté Bird.milieux vers nos libellés UI
  final Set<String> normalized = b.milieux
      .map((m) => m.toLowerCase().trim())
      .map((m) {
        if (m.contains('urb')) return 'urbain';
        if (m.contains('forest')) return 'forestier';
        if (m.contains('agric')) return 'agricole';
        if (m.contains('humid') ||
            m.contains('marais') ||
            m.contains("plan d'eau") ||
            m.contains('eau')) {
          return 'humide';
        }
        if (m.contains('mont')) return 'montagnard';
        if (m.contains('littoral') || m.contains('côte') || m.contains('cote')) {
          return 'littoral';
        }
        return m;
      }).toSet();
  return normalized.any((n) => selected.contains(n));
}

class _SimpleBirdTile extends StatelessWidget {
  final Bird bird;
  final double imageRadius;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const _SimpleBirdTile({
    required this.bird,
    required this.imageRadius,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _buildTileContent(context);
  }

  Future<void> _navigateToBirdDetail(BuildContext context) async {
    // Préchargement optimisé pour Hero animation fluide
    if (bird.urlImage.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(bird.urlImage), context);
      } catch (_) {
        // Continuer même si le préchargement échoue
      }
    }
    
    if (!context.mounted) return;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BirdDetailPage(bird: bird),
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        opaque: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.5, 1.0, curve: Curves.easeOutQuart),
              ),
            ),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildTileContent(BuildContext context) {
    const double dp = 1.0;

    return InkWell(
      borderRadius: BorderRadius.circular(imageRadius),
      onTap: () => _navigateToBirdDetail(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(imageRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image Hero optimisée
            Hero(
              tag: 'bird-hero-${bird.id}',
              transitionOnUserGestures: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(imageRadius),
                child: (bird.urlImage.isNotEmpty)
                    ? SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: CachedNetworkImage(
                          imageUrl: bird.urlImage,
                          fit: BoxFit.cover, // Structure identique partout
                          alignment: BirdImageAlignments.getOptimalAlignment(
                            bird.genus,
                            bird.species,
                          ),
                          fadeInDuration: const Duration(milliseconds: 400),
                          filterQuality: FilterQuality.high,
                      placeholder: (context, url) => Container(
                        color: const Color(0xFFD2DBB2),
                        child: const Center(
                          child: Icon(Icons.image_outlined, color: Color(0xFF6A994E), size: 32),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFD2DBB2),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Color(0xFF6A994E), size: 32),
                        ),
                      ),
                      memCacheWidth: 640,
                      memCacheHeight: 800,
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
            // Container nom
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: EdgeInsets.only(
                  left: 6.0 * dp,
                  right: 6.0 * dp,
                  bottom: 6.0 * dp,
                ),
                height: 40.0 * dp,
                padding: EdgeInsets.symmetric(horizontal: 8.0 * dp),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(5.0 * dp),
                    topRight: Radius.circular(5.0 * dp),
                    bottomLeft: Radius.circular(12.0 * dp),
                    bottomRight: Radius.circular(12.0 * dp),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x3F000000),
                      blurRadius: 4.0 * dp,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    bird.nomFr,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w800,
                      fontSize: 14.0,
                      color: const Color(0xFF344356),
                      letterSpacing: -0.3,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
            // Bouton favori
            Positioned(
              top: 8.0 * dp,
              right: 8.0 * dp,
              child: Container(
                width: 32.0 * dp,
                height: 32.0 * dp,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onFavoriteToggle,
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 18.0 * dp,
                      color: isFavorite ? Colors.pink : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
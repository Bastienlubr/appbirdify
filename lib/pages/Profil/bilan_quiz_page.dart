import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rive/rive.dart' as rive;
import '../../models/bird.dart';
import '../Perchoir/bird_detail_page.dart';
import '../../services/Mission/communs/commun_gestionnaire_assets.dart';
import '../../services/Perchoir/fiche_oiseau_service.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:convert' as convert;
import 'package:shared_preferences/shared_preferences.dart';
import '../../ui/responsive/responsive.dart';

/// Page de synthèse des résultats de quiz pour un périmètre (par défaut: un biome)
///
/// Usage initial: afficher un bilan par biome (ex: urbain, forestier, ...).
/// - scopeId: identifiant utilisé pour filtrer (ex: 'U' ou 'urbain')
/// - scopeLabel: libellé visible dans l'UI (ex: 'Milieu urbain')
class BilanQuizPage extends StatefulWidget {
  final String scopeId;   // Peut être un code (ex: 'U') ou un nom (ex: 'urbain')
  final String scopeLabel;

  const BilanQuizPage({
    super.key,
    required this.scopeId,
    required this.scopeLabel,
  });

  @override
  State<BilanQuizPage> createState() => _BilanQuizPageState();
}

class _BilanQuizPageState extends State<BilanQuizPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // (chargement visible supprimé)

  // Tableau de bord
  int _totalAttempts = 0; // Nombre d'épreuves jouées (somme des tentatives sur le périmètre)
  double _weightedGoodAnswersPct = 0.0; // Moyenne pondérée par tentatives

  // Espèces piégeuses: nom -> erreurs cumulées
  List<MapEntry<String, int>> _topTrickySpecies = const [];

  // Badges filtrés par périmètre
  List<Map<String, dynamic>> _badges = const [];

  // Suivi des préchargements pour éviction mémoire
  List<String> _preloadedImageUrls = const [];
  List<String> _preloadedBirdNames = const [];

  // Audio: un seul player partagé, état par oiseau
  late final AudioPlayer _audioPlayer;
  // États audio
  final Set<String> _audioOnBirds = <String>{};
  bool _audioBusy = false;
  final Set<String> _audioAvailableBirds = <String>{};
  String? _thickCrossSvg;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    // 1) Charger un snapshot local pour afficher tout de suite
    _loadCachedSnapshot().whenComplete(() {
      // 2) Rafraîchir en arrière-plan depuis Firestore
      _loadData();
    });
    // Préparer une version à traits plus épais de l'icône de fermeture
    unawaited(_prepareThickCrossIcon());
  }

  // Charge le SVG d'origine et augmente les épaisseurs de traits
  Future<void> _prepareThickCrossIcon() async {
    try {
      final raw = await rootBundle.loadString('assets/Images/Bouton/cross.svg');
      String svg = raw;
      // Heuristique simple: augmenter stroke-width existant et/ou injecter un style
      if (svg.contains('stroke-width')) {
        svg = svg.replaceAll(RegExp(r'stroke-width\s*=\s*"([0-9.]+)"'), 'stroke-width="3.4"');
      } else {
        // Injecter un style de stroke si pertinent sur paths/lines
        svg = svg.replaceAll('<path', '<path stroke-width="4.4"');
        svg = svg.replaceAll('<line', '<line stroke-width="4.4"');
        svg = svg.replaceAll('<polyline', '<polyline stroke-width="4.4"');
      }
      if (!mounted) return;
      setState(() { _thickCrossSvg = svg; });
    } catch (_) {
      // En cas d'échec, conserver l'asset original
    }
  }

  Future<void> _loadData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    try {
      // 1) Charger toutes les progressions de missions de l'utilisateur
      final missionsSnap = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('progression_missions')
          .get();

      // 2) Filtrer par périmètre (biome). Compatibilité: matcher code (ex: 'U') OU nom (ex: 'urbain')
      final String idLower = widget.scopeId.toLowerCase();
      final String labelLower = widget.scopeLabel.toLowerCase();

      final List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredDocs = missionsSnap.docs.where((d) {
        final data = d.data();
        final String missionId = d.id; // ex: U01, F02
        final dynamic biomeField = data['biome']; // parfois code ('U') ou nom ('urbain')
        final String biomeStr = biomeField?.toString().toLowerCase() ?? '';

        final bool matchByBiomeField = biomeStr == idLower || biomeStr == labelLower;
        final bool matchByPrefix = missionId.isNotEmpty && widget.scopeId.isNotEmpty && missionId[0].toLowerCase() == idLower[0];
        return matchByBiomeField || matchByPrefix;
      }).toList();

      // 3) Agréger tentatives, moyenne pondérée et espèces piégeuses
      int totalTentatives = 0;
      double sumWeightedMean = 0.0;
      final Map<String, int> speciesErrors = <String, int>{};

      for (final doc in filteredDocs) {
        final data = doc.data();
        final int tentatives = (data['tentatives'] is int) ? (data['tentatives'] as int) : 0;
        final double moyenne = (data['moyenneScores'] is num) ? (data['moyenneScores'] as num).toDouble() : 0.0;
        totalTentatives += tentatives;
        sumWeightedMean += moyenne * tentatives;

        final Map<String, dynamic> histo = (data['scoresHistorique'] is Map<String, dynamic>)
            ? (data['scoresHistorique'] as Map<String, dynamic>)
            : <String, dynamic>{};
        for (final entry in histo.entries) {
          final String bird = entry.key;
          final int count = (entry.value is int) ? (entry.value as int) : 0;
          speciesErrors[bird] = (speciesErrors[bird] ?? 0) + count;
        }
      }

      final double weightedPct = totalTentatives > 0 ? (sumWeightedMean / totalTentatives) : 0.0;

      // 4) Construire le top 10 des espèces piégeuses
      final List<MapEntry<String, int>> sortedSpecies = speciesErrors.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<MapEntry<String, int>> top10ByCount = sortedSpecies.take(10).toList();

      // En parallèle, calculer un pourcentage basé sur le nombre total d'épreuves (tentatives) pour normaliser
      // On l'affichera à côté de chaque espèce
      final int denom = totalTentatives == 0 ? 1 : totalTentatives;
      final List<MapEntry<String, int>> topPrepared = top10ByCount.map((e) => MapEntry<String, int>(
        '${e.key}||${((e.value / denom) * 100).toStringAsFixed(0)}',
        e.value,
      )).toList();

      // 5) Récupérer les badges et filtrer par périmètre si possible (heuristique: badgeId commençant par le code)
      final badgesSnap = await _firestore
          .collection('utilisateurs')
          .doc(user.uid)
          .collection('badges')
          .get();

      final List<Map<String, dynamic>> badgesAll = badgesSnap.docs.map((d) => d.data()).toList();
      final String expectedPrefix = widget.scopeId.toUpperCase();
      final List<Map<String, dynamic>> badgesFiltered = badgesAll.where((b) {
        final id = b['badgeId']?.toString() ?? '';
        return id.toUpperCase().startsWith(expectedPrefix);
      }).toList();

      if (!mounted) return;
      setState(() {
        _totalAttempts = totalTentatives;
        _weightedGoodAnswersPct = double.parse(weightedPct.toStringAsFixed(1));
        _topTrickySpecies = topPrepared;
        _badges = badgesFiltered;
      });
      // Sauvegarder le snapshot pour le prochain affichage instantané
      unawaited(_saveSnapshotToCache());

      // Préchargement en fond des 6 premières espèces piégeuses (dans l'ordre)
      final List<String> top6Names = _topTrickySpecies
          .map((e) => e.key.split('||').first)
          .where((n) => n.trim().isNotEmpty)
          .take(6)
          .toList();
      _preloadedBirdNames = top6Names;
      // Déterminer rapidement la disponibilité audio (cache → CSV)
      final Set<String> avail = <String>{};
      for (final name in top6Names) {
        final cached = MissionPreloader.findBirdByName(name);
        if (cached != null && cached.urlMp3.isNotEmpty) {
          avail.add(name);
          continue;
        }
        final fromCsv = await _loadBirdFromCsvByName(name);
        if (fromCsv != null && fromCsv.urlMp3.isNotEmpty) {
          avail.add(name);
        }
      }
      if (mounted) {
        setState(() { _audioAvailableBirds
          ..clear()
          ..addAll(avail);
        });
      }
      // Précharge en fond images puis audio (top 10 pour meilleure réactivité)
      final List<String> top10Names = _topTrickySpecies
          .map((e) => e.key.split('||').first)
          .where((n) => n.trim().isNotEmpty)
          .take(10)
          .toList();
      unawaited(_preloadTopSpeciesImagesInOrder(top10Names));
      unawaited(MissionPreloader.preloadAudioForBirds(top10Names));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BilanQuizPage._loadData error: $e');
      }
      if (!mounted) return;
    }
  }

  String _cacheKey() {
    final normalized = widget.scopeId.trim().toLowerCase();
    return 'bilan_quiz_snapshot_$normalized';
  }

  Future<void> _loadCachedSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey());
      if (raw == null || raw.isEmpty) return;
      final data = convert.jsonDecode(raw) as Map<String, dynamic>;
      final attempts = (data['totalAttempts'] as num?)?.toInt() ?? 0;
      final pct = (data['weightedPct'] as num?)?.toDouble() ?? 0.0;
      final List<dynamic> species = (data['topSpecies'] as List?) ?? const [];
      final parsedSpecies = <MapEntry<String, int>>[];
      for (final s in species) {
        final str = s?.toString() ?? '';
        if (str.isEmpty) continue;
        // format: name||pct||count
        final parts = str.split('||');
        if (parts.isEmpty) continue;
        final name = parts[0];
        final count = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
        parsedSpecies.add(MapEntry<String, int>(
          // on conserve name||pct comme clé pour l’UI actuelle
          parts.length > 1 ? '$name||${parts[1]}' : name,
          count,
        ));
      }
      final List<dynamic> badges = (data['badges'] as List?) ?? const [];
      final parsedBadges = <Map<String, dynamic>>[];
      for (final b in badges) {
        if (b is Map) parsedBadges.add(b.cast<String, dynamic>());
      }
      if (!mounted) return;
      setState(() {
        _totalAttempts = attempts;
        _weightedGoodAnswersPct = double.parse(pct.toStringAsFixed(1));
        _topTrickySpecies = parsedSpecies;
        _badges = parsedBadges;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveSnapshotToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final species = _topTrickySpecies.map((e) {
        // reconstruire 'name||pct||count'
        final name = e.key.split('||').first;
        final pct = (e.key.split('||').length > 1) ? e.key.split('||')[1] : '0';
        return '$name||$pct||$e.value';
      }).toList();
      final payload = {
        'totalAttempts': _totalAttempts,
        'weightedPct': _weightedGoodAnswersPct,
        'topSpecies': species,
        'badges': _badges,
        'ts': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey(), convert.jsonEncode(payload));
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      // Afficher toujours le contenu; les données se mettront à jour en arrière-plan
      body: _buildFigmaLikeContent(context),
    );
  }

  Widget _buildFigmaLikeContent(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildAvatarHeader(),
                const SizedBox(height: 8),
                _buildScopeTitle(),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: _buildDashboardFigmaStyle(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: _buildTrickySpeciesFigmaStyle(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 19),
                  child: _buildBadgesFigmaStyle(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Positioned(
            left: 16,
            top: 12,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                Navigator.of(context).maybePop();
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _thickCrossSvg != null
                    ? SvgPicture.string(
                        _thickCrossSvg!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        semanticsLabel: 'Fermer',
                      )
                    : SvgPicture.asset(
                        'assets/Images/Bouton/cross.svg',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        semanticsLabel: 'Fermer',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHeader() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 183,
          height: 183,
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: OvalBorder(),
            shadows: [
              BoxShadow(
                color: Color(0x153C7FD0),
                blurRadius: 19,
                offset: Offset(0, 12),
              )
            ],
          ),
        ),
        Container(
          width: 152,
          height: 152,
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/Images/Milieu/Milieu_urbain.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(80),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeTitle() {
    return SizedBox(
      width: 228.24,
      child: Text(
        _formattedScopeTitle(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF334355),
          fontSize: 30,
          fontFamily: 'Fredoka',
          fontWeight: FontWeight.w700,
          height: 1.33,
        ),
      ),
    );
  }

  String _formattedScopeTitle() {
    String id = widget.scopeId.trim().toLowerCase();
    String label = widget.scopeLabel.trim().toLowerCase();
    String source = label.isNotEmpty ? label : id;

    String adjective;
    if (source.contains('urbain')) {
      adjective = 'urbains';
    } else if (source.contains('forest')) {
      adjective = 'forestiers';
    } else if (source.contains('agric')) {
      adjective = 'agricoles';
    } else if (source.contains('mont')) {
      adjective = 'montagnards';
    } else if (source.contains('littoral') || source.contains('cote') || source.contains('côte')) {
      adjective = 'littoraux';
    } else if (source.contains('humide') || source.contains('marais')) {
      adjective = 'humides';
    } else {
      // fallback: simple pluriel en ajoutant 's' si nécessaire
      adjective = source;
      if (!adjective.endsWith('s') && !adjective.endsWith('x')) {
        adjective = '$adjective' 's';
      }
    }

    // Capitaliser la première lettre
    String capitalized = adjective.isNotEmpty
        ? adjective[0].toUpperCase() + adjective.substring(1)
        : adjective;
    return 'Milieux $capitalized';
  }

  // === Figma: Tableau de bord (deux pastilles) ===
  Widget _buildDashboardFigmaStyle() {
    return SizedBox(
      width: 338,
      height: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Titre
          const Positioned(
            left: 0,
            top: -10,
            child: SizedBox(
              width: 151,
              height: 29,
              child: Text(
                'Tableau de bord',
                style: TextStyle(
                  color: Color(0xFF334355),
                  fontSize: 15,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  height: 2.67,
                ),
              ),
            ),
          ),
          // Pastille gauche: Nombre d'épreuves
          Positioned(
            left: 8,
            top: 27,
            child: Container(
              width: 152,
              height: 42,
              decoration: ShapeDecoration(
                color: const Color(0xFFD2DBB2),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 2, color: Color(0xFF473C33)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Icône (gauche)
          Positioned(
            left: 13,
            top: 31,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Image.asset(
                'assets/PAGE/Profil/nombres de sessions.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Valeur et label (gauche)
          Positioned(
            left: 52,
            top: 29,
            child: SizedBox(
              width: 120,
              height: 34,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 0,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _totalAttempts.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xC4334355),
                          fontSize: 22,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Expanded(
                    child: Text(
                      "Nombre d'épreuves",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xC4334355),
                        fontSize: 14,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w400,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pastille droite: Bonnes réponses
          Positioned(
            left: 184,
            top: 27,
            child: Container(
              width: 152,
              height: 42,
              decoration: ShapeDecoration(
                color: const Color(0xFFD2DBB2),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 2, color: Color(0xFF473C33)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // (label déplacé plus bas pour s'assurer qu'il est au-dessus de tous les éléments)
          // Valeur du pourcentage: position fixe (comme avant), taille auto-adaptée
          Positioned(
            left: 190,
            top: 29,
            child: SizedBox(
              width: 64,
              height: 34,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _weightedGoodAnswersPct.toStringAsFixed(0),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6A994E),
                        fontSize: 34,
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      '%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF6A994E),
                        fontSize: 26,
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Libellé sur 2 lignes, séparé pour que la valeur reste ancrée
          Positioned(
            left: 262,
            top: 29,
            child: SizedBox(
              width: 80,
              height: 34,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Bonnes\nréponses',
                  maxLines: 2,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xC4334355),
                    fontSize: 14,
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
          
        ],
      ),
    );
  }

  // === Figma: Tes espèces piégeuses ===
  Widget _buildTrickySpeciesFigmaStyle() {
    return SizedBox(
      width: 338,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 174,
            height: 29,
            child: Text(
              'Tes espèces piégeuses',
              style: TextStyle(
                color: Color(0xFF334355),
                fontSize: 15,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                height: 2.67,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _topTrickySpecies.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = _topTrickySpecies[index];
              final parts = entry.key.split('||');
              final String birdName = parts.first;
              final String pct = parts.length > 1 ? parts[1] : '0';
              final int count = entry.value;
              return InkWell(
                onTap: () async {
                  await _openBirdDetail(birdName);
                },
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: SizedBox(
                  key: ValueKey('tricky_$birdName'),
                  width: 332,
                  height: 46,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Pastille de fond
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: 332,
                          height: 46,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFD2DBB2),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(width: 2, color: Color(0xFF473C33)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      // Bouton audio ON/OFF (gauche)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: StatefulBuilder(
                            builder: (context, setLocalState) {
                              final isOn = _audioOnBirds.contains(birdName);
                              final isEnabled = _audioAvailableBirds.contains(birdName);
                              return InkWell(
                                onTap: () async {
                                  await _toggleBirdAudio(birdName);
                                  // Forcer rebuild local pour stabiliser l'AnimatedOpacity si la liste ne rebuild pas
                                  setLocalState(() {});
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: _AudioMiniToggle(
                                  key: ValueKey('toggle_$birdName'),
                                  isOn: isOn,
                                  isEnabled: isEnabled,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // Texte (nom + sous-texte et stats)
                      Positioned(
                        left: 46,
                        top: 8,
                        right: 40,
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "$birdName\n",
                                style: const TextStyle(
                                  color: Color(0xC4334355),
                                  fontSize: 16,
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w700,
                                  height: 0.94,
                                ),
                              ),
                              TextSpan(
                                text: '$count erreurs • $pct% des tentatives',
                                style: const TextStyle(
                                  color: Color(0xC4334355),
                                  fontSize: 14,
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w400,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // pastille droite → bouton SVG, collée à l'extrême droite
                      Positioned(
                        right: 15,
                        top: 8,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () async { await _openBirdDetail(birdName); },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const ShapeDecoration(
                              color: Color(0xFFF2F5F8),
                              shape: OvalBorder(),
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/Images/Bouton/bouton droite.svg',
                              fit: BoxFit.contain,
                              width: 18,
                              height: 18,
                              colorFilter: const ColorFilter.mode(Color(0xBF473C33), BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openBirdDetail(String birdName) async {
    try {
      final navigator = Navigator.of(context);
      // Stopper l'audio en cours avant de naviguer
      try {
        _audioOnBirds.clear();
        await _audioPlayer.stop();
      } catch (_) {}
      final resolved = await _resolveCompleteBird(birdName);
      final minimal = resolved ?? Bird(
        id: birdName.toLowerCase().replaceAll(' ', '_'),
        genus: '',
        species: '',
        nomFr: birdName,
        urlMp3: '',
        urlImage: '',
        milieux: <String>{},
      );
      if (!mounted) return;
      navigator.push(_slideRightRoute(BirdDetailPage(bird: minimal, useHero: false, staticEntrance: true)));
    } catch (_) {
      // En cas d'erreur, naviguer tout de même avec un oiseau minimal
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final minimal = Bird(
        id: birdName.toLowerCase().replaceAll(' ', '_'),
        genus: '',
        species: '',
        nomFr: birdName,
        urlMp3: '',
        urlImage: '',
        milieux: <String>{},
      );
      navigator.push(_slideRightRoute(BirdDetailPage(bird: minimal, useHero: false, staticEntrance: true)));
    }
  }

  Route _slideRightRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        final slideTween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
        // Motion blur horizontal (effet de vitesse), sans modifier la vitesse d'animation
        return AnimatedBuilder(
          animation: curved,
          builder: (context, _) {
            final sigmaX = (1.0 - curved.value) * 6.0; // 6px -> 0 (horizontal only)
            return SlideTransition(
              position: curved.drive(slideTween),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: sigmaX, sigmaY: 0.0),
                child: child,
              ),
            );
          },
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
    );
  }

  // Résout un Bird complet par nom (cache → CSV → Firestore), en fusionnant au besoin
  Future<Bird?> _resolveCompleteBird(String birdName) async {
    Bird? best;
    try {
      // 1) Cache MissionPreloader
      final cached = MissionPreloader.findBirdByName(birdName);
      if (cached != null) {
        best = cached;
      }

      // 2) CSV Bank son oiseauxV4
      final fromCsv = await _loadBirdFromCsvByName(birdName);
      if (fromCsv != null) {
        best = _mergeBirds(best, fromCsv);
      }

      // Si informations clés manquantes, tenter Firestore
      final needsFirestore = best == null || best.urlImage.isEmpty || best.genus.isEmpty || best.species.isEmpty;
      if (needsFirestore) {
        final fiches = await FicheOiseauService.searchFichesByName(birdName);
        if (fiches.isNotEmpty) {
          // choisir la meilleure fiche: correspondance exacte sur le nom français si possible
          final normalizedTarget = _normalizeName(birdName);
          final exact = fiches.firstWhere(
            (f) => _normalizeName(f.nomFrancais) == normalizedTarget,
            orElse: () => fiches.first,
          );
          final fromFs = _toBirdFromFiche(exact);
          best = _mergeBirds(best, fromFs);
        }
      }

      return best;
    } catch (_) {
      return best; // retourner ce qu'on a pu assembler
    }
  }

  // Précharge, dans l'ordre, les images des espèces (top 6) pour une ouverture instantanée
  Future<void> _preloadTopSpeciesImagesInOrder(List<String> birdNames) async {
    for (final name in birdNames) {
      try {
        final bird = await _resolveCompleteBird(name);
        if (bird != null && bird.urlImage.isNotEmpty) {
          if (!mounted) return;
          await precacheImage(CachedNetworkImageProvider(bird.urlImage), context);
          _preloadedImageUrls = List<String>.from(_preloadedImageUrls)..add(bird.urlImage);
        }
      } catch (_) {
        // ignorer silencieusement pour ne pas bloquer l'UI
      }
    }
  }

  // Fusionne deux Bird en privilégiant les champs non vides
  Bird _mergeBirds(Bird? a, Bird b) {
    if (a == null) return b;
    return Bird(
      id: a.id.isNotEmpty ? a.id : b.id,
      genus: a.genus.isNotEmpty ? a.genus : b.genus,
      species: a.species.isNotEmpty ? a.species : b.species,
      nomFr: a.nomFr.isNotEmpty ? a.nomFr : b.nomFr,
      urlMp3: a.urlMp3.isNotEmpty ? a.urlMp3 : b.urlMp3,
      urlImage: a.urlImage.isNotEmpty ? a.urlImage : b.urlImage,
      milieux: a.milieux.isNotEmpty ? a.milieux : b.milieux,
    );
  }

  @override
  void dispose() {
    // Stop audio proprement
    try { _audioPlayer.dispose(); } catch (_) {}
    // Évacuer du cache mémoire Flutter les images préchargées de cette page
    for (final url in _preloadedImageUrls) {
      try {
        final provider = CachedNetworkImageProvider(url);
        // Evict du cache mémoire (laisse le cache disque intact)
        provider.evict();
      } catch (_) {}
    }
    // Nettoyer les drapeaux internes de précharge côté MissionPreloader
    try {
      if (_preloadedBirdNames.isNotEmpty) {
        MissionPreloader.clearImagesForBirds(_preloadedBirdNames);
      }
    } catch (_) {}
    super.dispose();
  }

  // Map une fiche Firestore vers un Bird minimal utilisable par BirdDetailPage
  Bird _toBirdFromFiche(dynamic fiche) {
    try {
      final String nomFr = (fiche.nomFrancais ?? '').toString();
      final String nomSci = (fiche.nomScientifique ?? '').toString();
      final parts = nomSci.split(' ');
      final String genus = parts.isNotEmpty ? parts[0] : '';
      final String species = parts.length > 1 ? parts[1] : '';
      final String id = nomSci.isNotEmpty ? nomSci.replaceAll(' ', '_').toLowerCase() : _normalizeName(nomFr).replaceAll(' ', '_');
      String image = '';
      try {
        image = (fiche.medias?.imagePrincipale ?? '').toString();
        if (image.isEmpty && (fiche.medias?.images is List && fiche.medias.images.isNotEmpty)) {
          image = fiche.medias.images.first.toString();
        }
      } catch (_) {}
      final List<String> milieuxList = (fiche.habitat?.milieux is List) ? List<String>.from(fiche.habitat.milieux) : const <String>[];
      return Bird(
        id: id,
        genus: genus,
        species: species,
        nomFr: nomFr,
        urlMp3: '',
        urlImage: image,
        milieux: milieuxList.toSet(),
      );
    } catch (_) {
      return Bird(
        id: _normalizeName(fiche?.nomFrancais?.toString() ?? '').replaceAll(' ', '_'),
        genus: '',
        species: '',
        nomFr: fiche?.nomFrancais?.toString() ?? '',
        urlMp3: '',
        urlImage: '',
        milieux: <String>{},
      );
    }
  }

  // Petit widget d'icône audio ON/OFF (style QUIZ, version mini)
  // Utilise les mêmes assets Rive que le quiz pour la cohérence visuelle
  // et commute instantanément sans animation intrusive.
  // Note: on ne réimporte pas la logique du quiz, seulement le visuel.
  static const double _miniToggleSize = 32;

  // Toggle audio pour un oiseau dans la liste (on/off, lecture en boucle avec position aléatoire si dispo)
  Future<void> _toggleBirdAudio(String birdName) async {
    try {
      if (_audioBusy) return;
      _audioBusy = true;
      if (!mounted) return;
      final isOn = _audioOnBirds.contains(birdName);
      if (isOn) {
        // OFF (comme quiz)
        _audioOnBirds.remove(birdName);
        await _audioPlayer.pause().catchError((_) {});
        if (mounted) setState(() {});
        return;
      }

      // ON pour cet oiseau, OFF pour les autres
      _audioOnBirds
        ..clear()
        ..add(birdName);
      if (mounted) setState(() {}); // basculer visuel ON immédiatement

      // Résoudre URL
      Bird? bird = MissionPreloader.findBirdByName(birdName);
      bird ??= await _loadBirdFromCsvByName(birdName);
      final String url = (bird?.urlMp3 ?? '').trim();
      if (url.isEmpty) {
        _audioOnBirds.remove(birdName);
        if (mounted) setState(() {});
        return;
      }

      await _audioPlayer.stop();
      final preloaded = MissionPreloader.getPreloadedAudio(birdName);
      if (preloaded != null && preloaded.audioSource != null) {
        await _audioPlayer.setAudioSource(preloaded.audioSource!);
      } else {
        await _audioPlayer.setUrl(url);
      }
      final ms = (DateTime.now().millisecondsSinceEpoch % 5000);
      await _audioPlayer.seek(Duration(milliseconds: ms));
      await _audioPlayer.setLoopMode(LoopMode.all);
      await _audioPlayer.play();
      // Marquer comme disponible (active visuellement le bouton)
      _audioAvailableBirds.add(birdName);
      if (mounted) setState(() {});
    } catch (_) {
      // En cas d'erreur, couper l'état
      _audioOnBirds.remove(birdName);
      if (mounted) setState(() {});
    } finally {
      _audioBusy = false;
    }
  }

  Future<Bird?> _loadBirdFromCsvByName(String birdName) async {
    try {
      final csvString = await rootBundle.loadString('assets/data/Bank son oiseauxV4.csv');
      final lines = csvString.split(RegExp(r'\r?\n')); // robuste CRLF/LF
      if (lines.isEmpty) return null;
      final headers = _parseCsvLine(lines.first);
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final values = _parseCsvLine(line);
        if (values.isEmpty) continue;
        final row = <String, String>{};
        for (int j = 0; j < headers.length && j < values.length; j++) {
          row[headers[j]] = values[j];
        }
        final nomFr = (row['Nom_français'] ?? row['Nom_francais'] ?? row['Nom_Francais'] ?? '').trim();
        if (nomFr.isEmpty) continue;
        if (_normalizeName(nomFr) == _normalizeName(birdName)) {
          return Bird.fromCsvRow(row);
        }
      }
    } catch (_) {}
    return null;
  }

  List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(ch);
      }
    }
    result.add(current.toString());
    return result.map((s) => s.trim()).toList();
  }

  String _normalizeName(String name) {
    String n = name.toLowerCase().trim();
    const accents = {
      'à':'a','â':'a','ä':'a','á':'a','ã':'a','å':'a',
      'ç':'c',
      'é':'e','è':'e','ê':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i',
      'ñ':'n',
      'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
      'ù':'u','ú':'u','û':'u','ü':'u',
      'ý':'y','ÿ':'y',
      'œ':'oe','æ':'ae',
      '’':'\'','‘':'\'','ʼ':'\'',
    };
    n = n.split('').map((ch) => accents[ch] ?? ch).join();
    n = n.replaceAll(RegExp(r"\s+"), ' ');
    return n;
  }

  // === Figma: Badges ===
  Widget _buildBadgesFigmaStyle() {
    // sélectionner jusqu'à 3 badges (ou placeholders)
    final items = _badges.take(3).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final double availableWidth = constraints.maxWidth;
        final double paddingH = m.dp(10, tabletFactor: 1.1);
        final double spacing = m.dp(12, tabletFactor: 1.1);
        final int cols = 3;
        final double itemSize = ((availableWidth - (paddingH * 2) - spacing * (cols - 1)) / cols)
            .clamp(72.0, 118.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 160,
              height: 29,
              child: const Text(
                'Badges ',
                style: TextStyle(
                  color: Color(0xFF334355),
                  fontSize: 15,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  height: 2.67,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: m.dp(10, tabletFactor: 1.0)),
              decoration: ShapeDecoration(
                color: const Color(0xFFF7F7F7),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 2, color: Color(0xFF473C33)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) {
                  if (i < items.length) {
                    final b = items[i];
                    final title = b['badgeId']?.toString() ?? 'Badge';
                    return _badgeCircle(title, size: itemSize, m: m);
                  }
                  return _badgeCircle('', size: itemSize, m: m);
                }),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _badgeCircle(String label, {required double size, required ResponsiveMetrics m}) {
    final double iconSize = (size * 0.33).clamp(18.0, 40.0);
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const ShapeDecoration(
              color: Color(0xFFEBEBEB),
              shape: OvalBorder(),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.emoji_events, color: const Color(0xFF6A994E), size: iconSize),
          ),
          SizedBox(height: m.dp(6, tabletFactor: 1.0)),
          SizedBox(
            width: size + m.dp(8, tabletFactor: 1.0),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF334355),
                fontSize: m.font(12, tabletFactor: 1.0, min: 10, max: 14),
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // === Section 1: Tableau de bord === (legacy, non utilisé)
  /*Widget _buildDashboardSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tableau de bord',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Épreuves jouées',
                    value: _totalAttempts.toString(),
                    icon: Icons.play_arrow_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    label: 'Bonnes réponses',
                    value: '${_weightedGoodAnswersPct.toStringAsFixed(1)}%',
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }*/

  // === Section 2: Espèces piégeuses (Top 10) === (legacy, non utilisé)
  /*Widget _buildTrickySpeciesSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tes espèces piégeuses (Top 10)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _topTrickySpecies.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _topTrickySpecies[index];
                    final parts = entry.key.split('||');
                    final String birdName = parts.first;
                    final String pct = parts.length > 1 ? parts[1] : '0';
                    final int count = entry.value;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(birdName),
                      subtitle: Text('$count erreurs • $pct% des tentatives'),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }*/

  // === Section 3: Badges du périmètre === (legacy, non utilisé)
  /*Widget _buildBadgesSection(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badges • ${widget.scopeLabel}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_badges.isEmpty)
              const Text('Aucun badge spécifique pour ce périmètre pour le moment.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _badges.map((b) {
                  final String title = b['badgeId']?.toString() ?? 'Badge';
                  final String niveau = b['niveau']?.toString() ?? '';
                  return _BadgeChip(title: title, level: niveau);
                }).toList(),
              )
          ],
        ),
      ),
    );
  }*/
}

class _AudioMiniToggle extends StatefulWidget {
  final bool isOn;
  final bool isEnabled;
  const _AudioMiniToggle({super.key, required this.isOn, this.isEnabled = true});

  @override
  State<_AudioMiniToggle> createState() => _AudioMiniToggleState();
}

class _AudioMiniToggleState extends State<_AudioMiniToggle> with SingleTickerProviderStateMixin {
  Widget? _onAnimation;
  Widget? _offAnimation;
  bool _ready = false;
  late final AnimationController _eqCtrl;

  @override
  void initState() {
    super.initState();
    _eqCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _init();
    _maybeStartEq();
  }

  void _init() {
    if (_ready) return;
    _onAnimation = rive.RiveAnimation.asset(
      'assets/animations/audio_on.riv',
      fit: BoxFit.contain,
    );
    _offAnimation = rive.RiveAnimation.asset(
      'assets/animations/audio_off.riv',
      fit: BoxFit.contain,
    );
    _ready = true;
  }

  void _maybeStartEq() {
    if (widget.isOn && widget.isEnabled) {
      if (!_eqCtrl.isAnimating) _eqCtrl.repeat(reverse: true);
    } else {
      _eqCtrl.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _AudioMiniToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeStartEq();
  }

  @override
  Widget build(BuildContext context) {
    _init();
    return SizedBox(
      width: _BilanQuizPageState._miniToggleSize,
      height: _BilanQuizPageState._miniToggleSize,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // OFF en dessous
          AnimatedOpacity(
            opacity: (widget.isOn || !widget.isEnabled) ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.linear,
            child: ColorFiltered(
              colorFilter: widget.isEnabled
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.srcOver)
                  : const ColorFilter.mode(Color(0x33000000), BlendMode.srcATop),
              child: _offAnimation,
            ),
          ),
          // ON au-dessus
          AnimatedOpacity(
            opacity: (widget.isOn && widget.isEnabled) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 80),
            curve: Curves.linear,
            child: ColorFiltered(
              colorFilter: widget.isEnabled
                  ? const ColorFilter.mode(Colors.transparent, BlendMode.srcOver)
                  : const ColorFilter.mode(Color(0x33000000), BlendMode.srcATop),
              child: _onAnimation,
            ),
          ),
          // Égaliseur interne (barres pulsantes)
          if (widget.isOn && widget.isEnabled)
            Center(
              child: SizedBox(
                width: _BilanQuizPageState._miniToggleSize * 0.6,
                height: _BilanQuizPageState._miniToggleSize * 0.6,
                child: _EqualizerBars(
                  controller: _eqCtrl,
                  color: widget.isEnabled ? const Color(0xFF6A994E) : const Color(0x55000000),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _eqCtrl.dispose();
    super.dispose();
  }
}

class _EqualizerBars extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  const _EqualizerBars({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value;
        // Trois barres avec déphasage
        final heights = [
          0.3 + 0.6 * (0.5 + 0.5 * math.sin((t * 2 * math.pi) + 0.0)),
          0.3 + 0.6 * (0.5 + 0.5 * math.sin((t * 2 * math.pi) + 1.2)),
          0.3 + 0.6 * (0.5 + 0.5 * math.sin((t * 2 * math.pi) + 2.4)),
        ];
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            return Container(
              width: 3,
              height: heights[i] * (MediaQuery.of(context).size.shortestSide * 0.06),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

/*class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}*/

/*class _BadgeChip extends StatelessWidget {
  final String title;
  final String level;

  const _BadgeChip({required this.title, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (level.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text('($level)', style: const TextStyle(color: Colors.black54)),
          ]
        ],
      ),
    );
  }
}*/



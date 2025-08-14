import 'package:flutter/material.dart';
import '../ui/responsive/responsive.dart';
import '../models/bird.dart';
import '../services/mission_preloader.dart';

class BaseOrnithoPage extends StatefulWidget {
  const BaseOrnithoPage({super.key});

  @override
  State<BaseOrnithoPage> createState() => _BaseOrnithoPageState();
}

class _BaseOrnithoPageState extends State<BaseOrnithoPage> {
  bool _isLoading = true;
  List<Bird> _birds = [];
  String _query = '';
  bool _sortAsc = true;
  bool _dense = false; // bouton temporaire: densité de la grille
  final Set<String> _selectedMilieux = <String>{};

  @override
  void initState() {
    super.initState();
    _loadAllBirds();
  }

  Future<void> _loadAllBirds() async {
    try {
      await MissionPreloader.loadBirdifyData();
      final names = MissionPreloader.getAllBirdNames();
      final birds = <Bird>[];
      for (final name in names) {
        final b = MissionPreloader.getBirdData(name);
        if (b != null) birds.add(b);
      }
      birds.sort((a, b) => a.nomFr.toLowerCase().compareTo(b.nomFr.toLowerCase()));
      if (mounted) {
        setState(() {
          _birds = birds;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final double titleFont = m.font(24, tabletFactor: 1.1, min: 20, max: 40);
        final double subtitleFont = m.font(16, tabletFactor: 1.05, min: 13, max: 22);
        final double cardRadius = m.dp(14, tabletFactor: 1.05);
        final double cardPadding = m.dp(8, tabletFactor: 1.1);
        final double imageRadius = m.dp(12, tabletFactor: 1.05);
        final double nameFont = m.font(16, tabletFactor: 1.0, min: 13, max: 20);
        final double searchHeight = m.dp(48, tabletFactor: 1.0);
        final int baseCols = m.isTablet ? (m.isWide ? 5 : 4) : 2;
        final int crossAxisCount = _dense ? (m.isTablet ? baseCols + 1 : 3) : baseCols; // bouton temporaire densité
        final double gridSpacing = m.dp(10, tabletFactor: 1.1);

        // Filtrer/ordonner dynamiquement selon _query/_sortAsc avec normalisation (sans accents, œ->o, æ->a)
        final List<Bird> displayed = List<Bird>.from(_birds);
        // Retirer entrées non valides (nom vide / non alpha en tête)
        displayed.removeWhere((b) {
          final key = _normalizeForSort(b.nomFr);
          return key.isEmpty || !RegExp(r'^[a-z]').hasMatch(key);
        });
        if (_query.trim().isNotEmpty) {
          final q = _normalizeForSort(_query.trim());
          displayed.retainWhere((b) {
            final nameKey = _normalizeForSort(b.nomFr);
            final speciesKey = _normalizeForSort(b.species);
            return nameKey.contains(q) || speciesKey.contains(q);
          });
        }
        if (_selectedMilieux.isNotEmpty) {
          displayed.retainWhere((b) => b.milieux.any((m) => _selectedMilieux.contains(m.toLowerCase())));
        }
        displayed.sort((a, b) {
          final ak = _normalizeForSort(a.nomFr);
          final bk = _normalizeForSort(b.nomFr);
          final cmp = ak.compareTo(bk);
          return _sortAsc ? cmp : -cmp;
        });

        return SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: m.spacing, vertical: m.gapMedium()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Répertoire des Oiseaux',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: titleFont,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF344356),
                      ),
                    ),
                    SizedBox(height: m.gapSmall()),
                    Text(
                      'Identifiez, écoutez, observez',
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: subtitleFont,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF57534E),
                      ),
                    ),
                    SizedBox(height: m.gapMedium()),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: searchHeight,
                            child: TextField(
                              onChanged: (v) => setState(() => _query = v),
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: 'Rechercher une espèce...',
                                hintStyle: const TextStyle(fontFamily: 'Quicksand'),
                                prefixIcon: const Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(horizontal: m.dp(16), vertical: 0),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(color: Color(0xFFD6D3D1), width: 1),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(color: Color(0xFFD6D3D1), width: 1),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(9999),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Espace réservé pour actions additionnelles si besoin
                      ],
                    ),
                    SizedBox(height: m.gapSmall()),
                    // Ligne de chips filtres (milieux) inspirée du design
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
                      onTap: () => setState(() => _sortAsc = !_sortAsc),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _sortAsc ? 'A-Z ' : 'Z-A ',
                              style: TextStyle(
                                color: const Color(0xFF57534E),
                                fontSize: subtitleFont,
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
                                height: 1.60,
                              ),
                            ),
                            TextSpan(
                              text: 'Classés par ordre alphabétique',
                              style: TextStyle(
                                color: const Color(0xFF57534E),
                                fontSize: m.font(13, tabletFactor: 1.05, min: 12, max: 20),
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
                          : GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: gridSpacing,
                                crossAxisSpacing: gridSpacing,
                                childAspectRatio: _dense ? 0.75 : 0.67,
                              ),
                              itemCount: displayed.length,
                              itemBuilder: (context, index) {
                                final bird = displayed[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(imageRadius),
                                  onTap: () {
                                    // TODO: Naviguer vers la fiche espèce détaillée
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(bird.nomFr)),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(imageRadius),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Image principale
                                        if (bird.urlImage.isNotEmpty)
                                          Image.network(
                                            bird.urlImage,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: const Color(0xFFD2DBB2),
                                                child: const Icon(Icons.image_not_supported, color: Color(0xFF6A994E)),
                                              );
                                            },
                                          )
                                        else
                                          Container(
                                            color: const Color(0xFFD2DBB2),
                                            child: const Icon(Icons.image, color: Color(0xFF6A994E)),
                                          ),

                                        // Etiquette blanche superposée sur l'image (en bas)
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            margin: EdgeInsets.only(
                                              left: m.dp(6),
                                              right: m.dp(6),
                                              bottom: m.dp(6),
                                            ),
                                            height: m.dp(40),
                                            padding: EdgeInsets.symmetric(horizontal: m.dp(8)),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(m.dp(5)),
                                                topRight: Radius.circular(m.dp(5)),
                                                bottomLeft: Radius.circular(m.dp(12)),
                                                bottomRight: Radius.circular(m.dp(12)),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0x3F000000),
                                                  blurRadius: m.dp(4),
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: _AutoFitNameText(
                                                text: bird.nomFr,
                                                maxFontSize: nameFont,
                                                minSingleLineFactor: 0.88,
                                                minTwoLineFactor: 0.70,
                                                baseStyle: const TextStyle(
                                                  fontFamily: 'Quicksand',
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF344356),
                                                  letterSpacing: -0.3,
                                                ),
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
                    onTap: () => setState(() => _dense = !_dense),
                    child: Padding(
                      padding: EdgeInsets.all(m.dp(12)),
                      child: Icon(_dense ? Icons.view_comfortable : Icons.view_comfy, color: const Color(0xFFFEC868), size: m.dp(22)),
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
    final List<String> milieux = const [
      'plaine', 'forêt', 'montagne', 'marais', 'plan d\'eau', 'littoral'
    ];
    return [
      for (final milieu in milieux)
        Padding(
          padding: EdgeInsets.only(right: m.gapSmall()),
          child: FilterChip(
            selected: _selectedMilieux.contains(milieu),
            onSelected: (sel) {
              setState(() {
                if (sel) {
                  _selectedMilieux.add(milieu);
                } else {
                  _selectedMilieux.remove(milieu);
                }
              });
            },
            backgroundColor: const Color(0xFF6A994E),
            selectedColor: const Color(0xFF6A994E),
            label: Text(
              milieu[0].toUpperCase() + milieu.substring(1),
              style: const TextStyle(
                fontFamily: 'Quicksand',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            shape: StadiumBorder(
              side: BorderSide(color: const Color(0x2D000000), width: 1),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: m.dp(16), vertical: m.dp(10)),
          ),
        ),
    ];
  }
}

extension _SortNormalize on _BaseOrnithoPageState {
  String _normalizeForSort(String input) {
    String n = input.toLowerCase().trim();
    const Map<String, String> map = {
      'à':'a','â':'a','ä':'a','á':'a','ã':'a','å':'a',
      'ç':'c',
      'é':'e','è':'e','ê':'e','ë':'e',
      'í':'i','ì':'i','î':'i','ï':'i',
      'ñ':'n',
      'ò':'o','ó':'o','ô':'o','ö':'o','õ':'o',
      'ù':'u','ú':'u','û':'u','ü':'u',
      'ý':'y','ÿ':'y',
      'œ':'o','Œ':'o','æ':'a','Æ':'a',
      '’':'\'','‘':'\'','ʼ':'\'',
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
}

class _AutoFitTwoLineText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minFontSize;
  final TextStyle baseStyle;

  const _AutoFitTwoLineText({
    required this.text,
    required this.maxFontSize,
    required this.minFontSize,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double font = maxFontSize;
        final TextPainter painter = TextPainter(
          textDirection: TextDirection.ltr,
          maxLines: 2,
        );

        // Réduire progressivement jusqu'à tenir sur 2 lignes sans overflow
        while (font > minFontSize) {
          painter.text = TextSpan(text: text, style: baseStyle.copyWith(fontSize: font));
          painter.layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines) break;
          font -= 0.5; // pas fin pour un rendu fluide
        }

        return Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(fontSize: font),
        );
      },
    );
  }
}

/// Auto-fit spécialisé: essaie d'abord en 1 ligne en réduisant jusqu'à 88% max.
/// Si ça ne rentre pas, passe à 2 lignes et peut réduire jusqu'à 70%.
class _AutoFitNameText extends StatelessWidget {
  final String text;
  final double maxFontSize;
  final double minSingleLineFactor; // ex: 0.88
  final double minTwoLineFactor;    // ex: 0.70
  final TextStyle baseStyle;

  const _AutoFitNameText({
    required this.text,
    required this.maxFontSize,
    required this.minSingleLineFactor,
    required this.minTwoLineFactor,
    required this.baseStyle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 1) Essayer sur 1 ligne avec réduction légère (jusqu'à 88%)
        double font = maxFontSize;
        final TextPainter painter = TextPainter(textDirection: TextDirection.ltr, maxLines: 1);
        final double minSingle = maxFontSize * minSingleLineFactor;
        while (font > minSingle) {
          painter.text = TextSpan(text: text, style: baseStyle.copyWith(fontSize: font));
          painter.layout(maxWidth: constraints.maxWidth);
          if (!painter.didExceedMaxLines) {
            return Align(
              alignment: Alignment.center,
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(fontSize: font, height: 1.05),
              ),
            );
          }
          font -= 0.5;
        }

        // 2) Sinon, passer à 2 lignes et réduire jusqu'à 70%
        font = maxFontSize * minSingleLineFactor; // repartir de la limite 1 ligne pour continuité visuelle
        final double minTwo = maxFontSize * minTwoLineFactor;
        final TextPainter painter2 = TextPainter(textDirection: TextDirection.ltr, maxLines: 2);
        while (font > minTwo) {
          painter2.text = TextSpan(text: text, style: baseStyle.copyWith(fontSize: font));
          painter2.layout(maxWidth: constraints.maxWidth);
          if (!painter2.didExceedMaxLines) {
            return Align(
              alignment: Alignment.center,
              child: Text(
                text,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(fontSize: font, height: 1.05),
              ),
            );
          }
          font -= 0.5;
        }

        // 3) Dernier recours: utiliser la taille minimale deux lignes
        return Align(
          alignment: Alignment.center,
          child: Text(
            text,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.visible,
            textAlign: TextAlign.center,
            style: baseStyle.copyWith(fontSize: minTwo, height: 1.05),
          ),
        );
      },
    );
  }
}



import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../ui/responsive/responsive.dart';
import '../MissionHabitat/quiz_page.dart';
import 'creation_quiz_page.dart';
import '../../services/Quiz/custom_quiz_service.dart';
import '../../services/Users/user_orchestra_service.dart';

class QuizSelectionPage extends StatefulWidget {
  const QuizSelectionPage({super.key});

  @override
  State<QuizSelectionPage> createState() => _QuizSelectionPageState();
}

class _QuizSelectionPageState extends State<QuizSelectionPage> {
  int? _selectedIndex;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _cachedDocs;
  bool _showCustomQuizzes = false;

  void _prefetchListImages(List<String> urls, BuildContext context) {
    final toPrefetch = urls.where((u) => u.isNotEmpty).take(6);
    for (final url in toPrefetch) {
      // Ignorer erreurs réseau; précharger silencieusement
      precacheImage(NetworkImage(url), context).catchError((_) {});
    }
  }

  double pointerAlignForIndex(int idx) {
    // Aligne la tétine au centre de la carte: gauche = -0.5, droite = +0.5
    return (idx % 2 == 0) ? -0.5 : 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final bg = const Color(0xFFF3F5F9);

        // Flux Firestore des quiz disponibles
        final quizStream = FirebaseFirestore.instance
            .collection('Quiz varié')
            .orderBy('name')
            .snapshots();

        // Tailles agrandies des cartes
        final double horizontalPadding = m.dp(24);
        final double gutter = m.dp(16);
        // final double innerWidth = constraints.maxWidth - horizontalPadding * 2; // Unused
        // final double cardWidth = (innerWidth - gutter) / 2; // Unused
        // final double cardHeight = cardWidth * 0.96; // Unused
        // final double topImageHeight = cardHeight * 0.52; // Unused

        return Container(
          color: bg,
          child: SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: quizStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }
                if (snapshot.hasData) {
                  final sdocs = snapshot.data!.docs;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final needUpdate = _cachedDocs == null || _cachedDocs!.length != sdocs.length;
                    if (needUpdate) {
                      setState(() {
                        _cachedDocs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(sdocs);
                      });
                      final images = sdocs.map((d) => (d.data()['imageUrl'] ?? '').toString()).toList();
                      _prefetchListImages(images, context);
                    }
                  });
                }

                final docs = _cachedDocs ?? snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(m.dp(24)),
                        child: const Text('Aucun quiz disponible pour le moment.'),
                      ),
                    );
                  }
                }

                // Filtrer: retirer la tuile "voix les plus rares" pour éviter les trous visuels
                final visibleDocs = docs.where((d) {
                  final name = (d.data()['name'] ?? '').toString().toLowerCase();
                  return !name.contains('voix les plus rares');
                }).toList();

                // Construire listes dynamiques basées sur la liste filtrée
                final titles = visibleDocs.map((d) => (d.data()['name'] ?? '').toString()).toList();
                final images = visibleDocs.map((d) => (d.data()['imageUrl'] ?? '').toString()).toList();
                final descriptions = visibleDocs.map((d) => (d.data()['description'] ?? '').toString()).toList();

                final double cardW = (constraints.maxWidth - horizontalPadding * 2 - gutter) / 2;
                final double cardH = cardW * 0.96;
                final double topH = cardH * 0.52;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: m.dp(24), vertical: m.dp(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _showCustomQuizzes = false),
                            child: _TabLabel(label: 'QUIZ', selected: !_showCustomQuizzes),
                          ),
                          SizedBox(width: m.dp(24)),
                          GestureDetector(
                            onTap: () => setState(() => _showCustomQuizzes = true),
                            child: _TabLabel(label: 'MES QUIZ', selected: _showCustomQuizzes),
                          ),
                        ],
                      ),
                      SizedBox(height: m.dp(16)),
                      // Carte d'action: Créer ton quiz (premium uniquement)
                      if (!_showCustomQuizzes)
                        ...(UserOrchestra.isPremium
                            ? [
                                _ActionCreateQuizCard(onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const CreationQuizPage()),
                                  );
                                }),
                                SizedBox(height: m.dp(16)),
                              ]
                            : [
                                _ActionCreateQuizCardDisabled(onTapPaywall: () {
                                  Navigator.of(context).pushNamed('/abonnement/information');
                                }),
                                SizedBox(height: m.dp(16)),
                              ]),
                      // Affichage conditionnel: quiz officiels ou quiz personnalisés
                      if (_showCustomQuizzes)
                        _CustomQuizzesSection(cardW: cardW, cardH: cardH, topH: topH, gutter: gutter)
                      else
                        ..._buildOfficialQuizzes(visibleDocs, titles, images, descriptions, cardW, cardH, topH, gutter, m),
                      SizedBox(height: m.dp(40)),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildOfficialQuizzes(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> visibleDocs,
    List<String> titles,
    List<String> images,
    List<String> descriptions,
    double cardW,
    double cardH,
    double topH,
    double gutter,
    ResponsiveMetrics m,
  ) {
    return List.generate(((visibleDocs.length + 1) ~/ 2), (rowIdx) {
                        final i = rowIdx * 2;
                        final j = i + 1;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (j < visibleDocs.length) ...[
                                Expanded(
                                  child: _SmallQuizCard(
                                    width: cardW,
                                    height: cardH,
                                    topImageHeight: topH,
                                    title: titles[i],
                                    imageUrl: images[i].isNotEmpty ? images[i] : 'https://placehold.co/140x80',
                                    selected: _selectedIndex == i,
                                    onTap: () => setState(() { _selectedIndex = (_selectedIndex == i) ? null : i; }),
                                  ),
                                ),
                                  SizedBox(width: gutter),
                                  Expanded(
                                    child: _SmallQuizCard(
                                      width: cardW,
                                      height: cardH,
                                      topImageHeight: topH,
                                      title: titles[j],
                                      imageUrl: images[j].isNotEmpty ? images[j] : 'https://placehold.co/140x80',
                                      selected: _selectedIndex == j,
                                      onTap: () => setState(() { _selectedIndex = (_selectedIndex == j) ? null : j; }),
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: cardW,
                                    child: _SmallQuizCard(
                                      width: cardW,
                                      height: cardH,
                                      topImageHeight: topH,
                                      title: titles[i],
                                      imageUrl: images[i].isNotEmpty ? images[i] : 'https://placehold.co/140x80',
                                      selected: _selectedIndex == i,
                                      onTap: () => setState(() { _selectedIndex = (_selectedIndex == i) ? null : i; }),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              child: (_selectedIndex != null && (_selectedIndex == i || _selectedIndex == j))
                                  ? Padding(
                                      padding: EdgeInsets.only(top: m.dp(0), bottom: m.dp(16)),
                                      child: Transform.translate(
                                        offset: Offset(0, -m.dp(22)),
                                        child: _WideDescriptionPanel(
                                          corner: m.dp(14),
                                          title: titles[_selectedIndex!].replaceAll('\n', ' '),
                                          description: descriptions[_selectedIndex!],
                                          pointerXAlign: pointerAlignForIndex(_selectedIndex!),
                                          onContinuer: () {
                                            final missionId = visibleDocs[_selectedIndex!].id;
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => QuizPage(missionId: missionId),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            // Espace entre cette rangée (et son panneau) et la suivante
                            SizedBox(height: m.dp(24)),
                          ],
                        );
                      });
  }
}

class _CustomQuizzesSection extends StatefulWidget {
  final double cardW;
  final double cardH;
  final double topH;
  final double gutter;
  const _CustomQuizzesSection({required this.cardW, required this.cardH, required this.topH, required this.gutter});

  @override
  State<_CustomQuizzesSection> createState() => _CustomQuizzesSectionState();
}

class _CustomQuizzesSectionState extends State<_CustomQuizzesSection> {
  Map<String, dynamic>? _selectedQuiz;
  int? _selectedIndex;

  void _selectQuiz(Map<String, dynamic> quiz, int index) {
    setState(() {
      _selectedQuiz = quiz;
      _selectedIndex = index;
    });
  }

  void _deselectQuiz() {
    setState(() {
      _selectedQuiz = null;
      _selectedIndex = null;
    });
  }

  double _pointerAlignForIndex(int idx) {
    // Aligne la tétine au centre de la carte: gauche = -0.5, droite = +0.5
    return (idx % 2 == 0) ? -0.5 : 0.5;
  }

  String _buildQuizDescription(Map<String, dynamic> quiz) {
    final description = quiz['description'] ?? '';
    final questionsCount = quiz['questionsCount'] ?? 0;
    final selectedBirds = List<String>.from(quiz['selectedBirds'] ?? []);
    final speciesCount = selectedBirds.length;

    return [
      if (description.isNotEmpty) description,
      '$questionsCount questions',
      '$speciesCount espèces sélectionnées',
    ].join('\n');
  }

  void _launchQuiz(Map<String, dynamic> quiz) async {
    final quizId = quiz['id'] as String;
    final questions = await CustomQuizService.loadCustomQuiz(quizId);
    
    if (questions != null && mounted) {
      _deselectQuiz();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizPage(
            missionId: 'custom-${quiz['id']}',
            preloadedQuestions: questions,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: CustomQuizService.getUserCustomQuizzes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final customQuizzes = snapshot.data!;
        if (customQuizzes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.quiz, size: 48, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 12),
                  const Text(
                    'Aucun quiz personnalisé',
                    style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Créez votre premier quiz depuis l\'onglet QUIZ',
                    style: TextStyle(fontFamily: 'Quicksand', color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: List.generate(((customQuizzes.length + 1) ~/ 2), (rowIdx) {
            final i = rowIdx * 2;
            final j = i + 1;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (j < customQuizzes.length) ...[
                      Expanded(
                        child: _CustomQuizCard(
                          quiz: customQuizzes[i],
                          width: widget.cardW,
                          height: widget.cardH,
                          topImageHeight: widget.topH,
                          selected: _selectedIndex == i,
                          onTap: () => _selectQuiz(customQuizzes[i], i),
                        ),
                      ),
                      SizedBox(width: widget.gutter),
                      Expanded(
                        child: _CustomQuizCard(
                          quiz: customQuizzes[j],
                          width: widget.cardW,
                          height: widget.cardH,
                          topImageHeight: widget.topH,
                          selected: _selectedIndex == j,
                          onTap: () => _selectQuiz(customQuizzes[j], j),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: widget.cardW,
                        child: _CustomQuizCard(
                          quiz: customQuizzes[i],
                          width: widget.cardW,
                          height: widget.cardH,
                          topImageHeight: widget.topH,
                          selected: _selectedIndex == i,
                          onTap: () => _selectQuiz(customQuizzes[i], i),
                        ),
                      ),
                    ],
                  ],
                ),
                // Animation et popup exactement comme les quiz officiels
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: (_selectedIndex != null && (_selectedIndex == i || _selectedIndex == j))
                      ? Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 16),
                          child: Transform.translate(
                            offset: const Offset(0, -22),
                            child: _WideDescriptionPanel(
                              corner: 14,
                              title: _selectedQuiz!['name'] ?? 'Quiz sans nom',
                              description: _buildQuizDescription(_selectedQuiz!),
                              pointerXAlign: _pointerAlignForIndex(_selectedIndex!),
                              onContinuer: () => _launchQuiz(_selectedQuiz!),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),
              ],
            );
          }),
        );
      },
    );
  }
}

class _CustomQuizCard extends StatelessWidget {
  final Map<String, dynamic> quiz;
  final double width;
  final double height;
  final double topImageHeight;
  final bool selected;
  final VoidCallback onTap;

  const _CustomQuizCard({
    required this.quiz,
    required this.width,
    required this.height,
    required this.topImageHeight,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = quiz['name'] ?? 'Quiz sans nom';
    final questionsCount = quiz['questionsCount'] ?? 0;
    final radius = Radius.circular(15);
    
    return InkWell(
      borderRadius: BorderRadius.circular(radius.x),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius.x),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
            BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: selected ? const Color(0xFF473C33) : Colors.transparent,
                      width: selected ? 3 : 0,
                    ),
                    borderRadius: BorderRadius.circular(radius.x),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: topImageHeight,
              child: Container(
                decoration: ShapeDecoration(
                  color: const Color(0xFF6A994E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.quiz,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: topImageHeight,
              width: width,
              height: height - topImageHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF334355),
                          fontSize: 16,
                          fontFamily: 'Quicksand',
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$questionsCount questions',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                          fontFamily: 'Quicksand',
                        ),
                      ),
                    ],
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

class _ActionCreateQuizCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ActionCreateQuizCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF473C33), width: 2.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF6A994E),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Créer ton quiz',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF334355),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.chevron_right, color: Color(0xFF334355)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCreateQuizCardDisabled extends StatelessWidget {
  final VoidCallback onTapPaywall;
  const _ActionCreateQuizCardDisabled({required this.onTapPaywall});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapPaywall,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF473C33), width: 2.5),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFF9CA3AF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Créer ton quiz (Premium)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Color(0xFF334355),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              left: null,
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A994E),
                  borderRadius: const BorderRadius.only(
                    // Ajusté pour correspondre au rayon interne de la carte (15 - 2.5 ≈ 12.5)
                    topRight: Radius.circular(12.5),
                    bottomLeft: Radius.circular(10),
                    topLeft: Radius.circular(0),
                    bottomRight: Radius.circular(0),
                  ),
                  border: const Border(
                    top: BorderSide.none,
                    right: BorderSide.none,
                    left: BorderSide(color: Color(0xFF473C33), width: 2.5),
                    bottom: BorderSide(color: Color(0xFF473C33), width: 2.5),
                  ),
                  // Pas d'ombre pour coller parfaitement au bord
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xEDFEB547), Color(0xFFFEC868)],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: const Text(
                    'ENVOL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      height: 1.0,
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

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;

  const _TabLabel({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    // baseText supprimé (non utilisé)
    final Color muted = const Color(0x8C334355);
    const Color selectedYellow = Color(0xFFFEC868); // texte actif (bottom bar)
    const Color selectedGreen = Color(0xFF6A994E);  // contour actif (bottom bar)
    final Widget pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: ShapeDecoration(
        color: selected ? selectedGreen : Colors.transparent,
        shape: const StadiumBorder(),
      ),
      foregroundDecoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: selected ? selectedGreen : const Color(0xFFDADADA), width: 2),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? selectedYellow : muted,
          fontSize: 16,
          fontFamily: 'Fredoka',
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: 1,
          height: 1.1,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Ombre uniquement en dessous
        Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRect(
              child: FractionallySizedBox(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.70,
                child: const Material(
                  color: Colors.transparent,
                  elevation: 8,
                  shadowColor: Color(0x55000000),
                  shape: StadiumBorder(),
                ),
              ),
            ),
          ),
        ),
        pill,
      ],
    );
  }
}

class _SmallQuizCard extends StatelessWidget {
  final double width;
  final double height;
  final double topImageHeight;
  final String title;
  final String imageUrl;
  final bool selected;
  final VoidCallback? onTap;

  const _SmallQuizCard({
    required this.width,
    required this.height,
    required this.topImageHeight,
    required this.title,
    required this.imageUrl,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(15);
    return InkWell(
      borderRadius: BorderRadius.circular(radius.x),
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius.x),
          boxShadow: const [
            BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
            BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      color: selected ? const Color(0xFF473C33) : Colors.transparent,
                      width: selected ? 3 : 0,
                    ),
                    borderRadius: BorderRadius.circular(radius.x),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: topImageHeight,
              child: Container(
                decoration: ShapeDecoration(
                  color: const Color(0xFFD0D5DD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              width: width,
              height: topImageHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: topImageHeight,
              width: width,
              height: height - topImageHeight,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF334355),
                      fontSize: 16,
                      fontFamily: 'Quicksand',
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
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

class _WideDescriptionPanel extends StatelessWidget {
  final double corner;
  final String title;
  final String description;
  final double pointerXAlign; // -1.0 .. 1.0 (position horizontale de la tétine)
  final VoidCallback onContinuer;

  const _WideDescriptionPanel({
    required this.corner,
    required this.title,
    required this.description,
    required this.pointerXAlign,
    required this.onContinuer,
  });

  @override
  Widget build(BuildContext context) {
    final green = const Color(0xFF6A994E);
    // Couleurs et styles inspirés du popover vies, adaptés au panneau blanc
    const Color fillColor = Colors.white;
    const Color strokeColor = Color(0xFF473C33);
    const double borderWidth = 3.0;
    final double cornerRadius = corner;
    const EdgeInsets contentPadding = EdgeInsets.fromLTRB(23, 52, 23, 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Convertit l’alignement (-1..1) en position X en pixels, avec marges de sécurité
        final double rawCenter = (pointerXAlign + 1) * 0.5 * width;
        final double arrowCenterX = rawCenter.clamp(24.0, width - 24.0);
        const double arrowWidth = 24.0; // proportion similaire au popover
        const double arrowHeight = 18.0;

        return CustomPaint(
          painter: _IntegratedBubblePainterQuiz(
            fillColor: fillColor,
            strokeColor: strokeColor,
            borderWidth: borderWidth,
            cornerRadius: cornerRadius,
            arrowCenterX: arrowCenterX,
            arrowWidth: arrowWidth,
            arrowHeight: arrowHeight,
            topInset: contentPadding.top,
          ),
          child: Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF334355),
                      fontSize: 18,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF334355),
                    fontSize: 16,
                    fontFamily: 'Quicksand',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: onContinuer,
                    child: Container(
                      width: 140,
                      height: 32,
                      decoration: ShapeDecoration(
                        color: green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0x4C5468FF),
                            blurRadius: 25,
                            offset: Offset(0, 10),
                            spreadRadius: 0,
                          )
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          ' Continuer',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
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
    );
  }
}

class _IntegratedBubblePainterQuiz extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;
  final double borderWidth;
  final double cornerRadius;
  final double arrowCenterX;
  final double arrowWidth;
  final double arrowHeight;
  final double topInset;

  _IntegratedBubblePainterQuiz({
    required this.fillColor,
    required this.strokeColor,
    required this.borderWidth,
    required this.cornerRadius,
    required this.arrowCenterX,
    required this.arrowWidth,
    required this.arrowHeight,
    required this.topInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double left = borderWidth / 2;
    final double right = size.width - borderWidth / 2;
    final double bottom = size.height - borderWidth / 2;
    final double top = topInset;

    final double baseLeft = (arrowCenterX - arrowWidth / 2).clamp(left + cornerRadius, right - cornerRadius);
    final double baseRight = (arrowCenterX + arrowWidth / 2).clamp(left + cornerRadius, right - cornerRadius);
    final double tipY = top - arrowHeight;

    final Path path = Path();
    path.moveTo(left + cornerRadius, top);
    path.lineTo(baseLeft, top);
    // Triangle intégré avec pointe arrondie
    final double half = arrowWidth * 0.5;
    path.lineTo(arrowCenterX - half, top);
    path.quadraticBezierTo(arrowCenterX, tipY, arrowCenterX + half, top);
    path.lineTo(baseRight, top);
    path.lineTo(right - cornerRadius, top);
    path.arcToPoint(Offset(right, top + cornerRadius), radius: Radius.circular(cornerRadius));
    path.lineTo(right, bottom - cornerRadius);
    path.arcToPoint(Offset(right - cornerRadius, bottom), radius: Radius.circular(cornerRadius));
    path.lineTo(left + cornerRadius, bottom);
    path.arcToPoint(Offset(left, bottom - cornerRadius), radius: Radius.circular(cornerRadius));
    path.lineTo(left, top + cornerRadius);
    path.arcToPoint(Offset(left + cornerRadius, top), radius: Radius.circular(cornerRadius));

    // Ombre douce
    canvas.drawShadow(path, Colors.black.withAlpha(30), 14, true);

    // Remplissage
    final Paint fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Contour
    final Paint stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _IntegratedBubblePainterQuiz old) {
    return old.fillColor != fillColor ||
        old.strokeColor != strokeColor ||
        old.borderWidth != borderWidth ||
        old.cornerRadius != cornerRadius ||
        old.arrowCenterX != arrowCenterX ||
        old.arrowWidth != arrowWidth ||
        old.arrowHeight != arrowHeight ||
        old.topInset != topInset;
  }
}



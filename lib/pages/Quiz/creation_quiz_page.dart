import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/recap_button.dart';
import '../../ui/responsive/responsive.dart';
import '../../models/bird.dart';
import '../../services/Mission/communs/commun_gestionnaire_assets.dart';
import '../../services/Mission/communs/commun_generateur_quiz.dart';
import '../../services/Quiz/custom_quiz_service.dart';
import '../MissionHabitat/quiz_page.dart';

class CreationQuizPage extends StatefulWidget {
  const CreationQuizPage({super.key});

  @override
  State<CreationQuizPage> createState() => _CreationQuizPageState();
}

class _CreationQuizPageState extends State<CreationQuizPage> {
  bool _loading = true;
  List<Bird> _all = [];
  List<Bird> _displayed = [];
  final Set<String> _selected = <String>{};
  String _query = '';
  bool _sortAsc = true;
  static const int _minRequired = 20;
  final ScrollController _scrollController = ScrollController();
  double _topFadeOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBirds();
    _scrollController.addListener(() {
      final double y = _scrollController.position.pixels;
      // Opacité progressive: 0 → 1 sur ~12px pour être très visible dès le début
      final double next = (y / 12.0).clamp(0.0, 1.0);
      if ((next - _topFadeOpacity).abs() > 0.02) {
        setState(() => _topFadeOpacity = next);
      }
    });
  }

  Future<void> _loadBirds() async {
    try {
      await MissionPreloader.loadBirdifyData();
      final names = MissionPreloader.getAllBirdNames();
      final list = names
          .map((n) => MissionPreloader.getBirdData(n) ?? MissionPreloader.findBirdByName(n))
          .where((b) => b != null)
          .cast<Bird>()
          .where((b) => b.urlImage.trim().isNotEmpty)
          .toList();
      list.sort((a, b) => a.nomFr.toLowerCase().compareTo(b.nomFr.toLowerCase()));
      setState(() {
        _all = list;
        _applyFilters();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    Iterable<Bird> cur = _all;
    final q = _normalize(_query);
    if (q.isNotEmpty) {
      cur = cur.where((b) {
        final name = _normalize(b.nomFr);
        final species = _normalize(b.species);
        return name.contains(q) || species.contains(q);
      });
    }
    final list = cur.toList();
    list.sort((a, b) {
      final cmp = _normalize(a.nomFr).compareTo(_normalize(b.nomFr));
      return _sortAsc ? cmp : -cmp;
    });
    _displayed = list;
  }

  String _normalize(String s) {
    String n = s.toLowerCase().trim();
    const map = {
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
    n = n.split('').map((ch) => map[ch] ?? ch).join();
    n = n.replaceAll(RegExp(r"[^a-z0-9\s\-]"), "");
    n = n.replaceAll(RegExp(r"\s+"), " ").trim();
    return n;
  }

  void _onSearch(String v) {
    _query = v;
    setState(() => _applyFilters());
  }

  void _toggleSort() {
    setState(() {
      _sortAsc = !_sortAsc;
      _applyFilters();
    });
  }

  void _toggleSelect(Bird b) {
    setState(() {
      if (_selected.contains(b.nomFr)) {
        _selected.remove(b.nomFr);
      } else {
        _selected.add(b.nomFr);
      }
    });
  }

  Future<void> _startQuiz() async {
    if (_selected.isEmpty) return;
    final chosen = _all.where((b) => _selected.contains(b.nomFr)).toList();
    
    // Afficher le popup de configuration
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _QuizConfigDialog(
        selectedBirds: chosen,
        onLaunch: (questions) {
          Navigator.of(context).pop(); // Fermer dialog
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuizPage(
                missionId: 'custom',
                preloadedQuestions: questions,
              ),
            ),
          );
        },
        onSave: (name, description, questionsCount, questions) async {
          Navigator.of(context).pop(); // Fermer dialog
          final messenger = ScaffoldMessenger.of(context);
          final success = await CustomQuizService.saveCustomQuiz(
            name: name,
            description: description,
            selectedBirdNames: chosen.map((b) => b.nomFr).toList(),
            questionsCount: questionsCount,
            questions: questions,
          );
          if (mounted) {
            messenger.showSnackBar(
            SnackBar(
              content: Text(success ? 'Quiz "$name" sauvegardé avec succès!' : 'Erreur lors de la sauvegarde'),
              backgroundColor: success ? const Color(0xFF6A994E) : Colors.red,
            ),
          );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        final gridCols = m.isTablet ? (m.isWide ? 5 : 4) : 2;
        final spacing = m.dp(10, tabletFactor: 1.1);
        final aspect = 0.80;

        return Scaffold(
          backgroundColor: const Color(0xFFF3F5F9),
          appBar: AppBar(
            title: const Text('Création quiz', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w800)),
            backgroundColor: const Color(0xFFF3F5F9),
            foregroundColor: const Color(0xFF344356),
            elevation: 0.0,
            scrolledUnderElevation: 0.0,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(m.spacing, m.gapSmall(), m.spacing, m.gapSmall()),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: m.dp(48),
                              child: TextField(
                                onChanged: _onSearch,
                                decoration: InputDecoration(
                                  hintText: 'Rechercher une espèce...',
                                  prefixIcon: const Icon(Icons.search),
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
                          SizedBox(width: m.gapSmall()),
                          TextButton.icon(
                            onPressed: _toggleSort,
                            icon: Icon(_sortAsc ? Icons.sort_by_alpha : Icons.sort_by_alpha, color: const Color(0xFF344356)),
                            label: Text(_sortAsc ? 'A-Z' : 'Z-A', style: const TextStyle(fontFamily: 'Quicksand', color: Color(0xFF344356))),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                                side: const BorderSide(color: Color(0xFFD6D3D1), width: 1),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: m.dp(14), vertical: m.dp(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : Stack(
                              children: [
                                CustomScrollView(
                                  controller: _scrollController,
                                  slivers: [
                                    for (final entry in _groupByFirstLetter(_displayed).entries) ...[
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            left: m.spacing,
                                            right: m.spacing,
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
                                        padding: EdgeInsets.symmetric(horizontal: m.spacing, vertical: m.dp(4)),
                                        sliver: SliverGrid(
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridCols,
                                            mainAxisSpacing: spacing,
                                            crossAxisSpacing: spacing,
                                            childAspectRatio: aspect,
                                          ),
                                          delegate: SliverChildBuilderDelegate(
                                            (context, idx) {
                                              final b = entry.value[idx];
                                              final selected = _selected.contains(b.nomFr);
                                              return _SelectableBirdTile(
                                                bird: b,
                                                selected: selected,
                                                onTap: () => _toggleSelect(b),
                                              );
                                            },
                                            childCount: entry.value.length,
                                          ),
                                        ),
                                      ),
                                    ],
                                    // Marge de fin pour laisser le contenu passer sous le panel
                                    SliverToBoxAdapter(child: SizedBox(height: m.dp(160))),
                                  ],
                                ),
                                // Fade top overlay (apparaît quand on scrolle un peu)
                                IgnorePointer(
                                  ignoring: true,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    curve: Curves.easeInOut,
                                    opacity: 0.4,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        height: m.dp(55),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFFF3F5F9),
                                              Color(0xCCF3F5F9),
                                              Color(0x66F3F5F9),
                                              Color(0x00F3F5F9),
                                            ],
                                            stops: [0.0, 0.25, 0.6, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _BottomPanel(
                    selectedCount: _selected.length,
                    names: _selected.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
                    onRemove: (name) => setState(() => _selected.remove(name)),
                    onStart: _startQuiz,
                    minRequired: _minRequired,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<Bird>> _groupByFirstLetter(List<Bird> birds) {
    final Map<String, List<Bird>> groups = {};
    for (final b in birds) {
      final key = _normalize(b.nomFr);
      if (key.isEmpty) continue;
      final String letter = key[0].toUpperCase();
      (groups[letter] ??= <Bird>[]).add(b);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => _sortAsc ? a.compareTo(b) : b.compareTo(a));
    final Map<String, List<Bird>> ordered = {};
    for (final k in sortedKeys) {
      ordered[k] = groups[k]!;
    }
    return ordered;
  }
}

class _SelectableBirdTile extends StatelessWidget {
  final Bird bird;
  final bool selected;
  final VoidCallback onTap;
  const _SelectableBirdTile({required this.bird, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = 12.0;
    return InkWell(
      borderRadius: BorderRadius.circular(radius),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            (bird.urlImage.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: bird.urlImage,
                    fit: BoxFit.cover,
                    placeholder: (c, u) => Container(color: const Color(0xFFD2DBB2)),
                    errorWidget: (c, u, e) => Container(color: const Color(0xFFD2DBB2)),
                  )
                : Container(color: const Color(0xFFD2DBB2)),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(6),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(5),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                  border: Border.all(color: selected ? const Color(0xFFABC270) : Colors.transparent, width: 3),
                ),
                child: Center(
                  child: _AdaptiveTwoLineText(
                    text: bird.nomFr,
                    maxHeight: 40,
                    baseStyle: const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w800, color: Color(0xFF344356), height: 1.1),
                    candidateFontSizes: const [14.0, 13.5, 13.0, 12.5, 12.0, 11.5, 11.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF6A994E) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                width: 28,
                height: 28,
                child: Icon(selected ? Icons.check : Icons.add, size: 18, color: selected ? Colors.white : const Color(0xFF6A994E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveTwoLineText extends StatelessWidget {
  final String text;
  final double maxHeight;
  final TextStyle baseStyle;
  final List<double> candidateFontSizes;

  const _AdaptiveTwoLineText({
    required this.text,
    required this.maxHeight,
    required this.baseStyle,
    required this.candidateFontSizes,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        for (final size in candidateFontSizes) {
          final style = baseStyle.copyWith(fontSize: size);
          final span = TextSpan(text: text, style: style);
          final tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            maxLines: 2,
            textDirection: TextDirection.ltr,
            ellipsis: '…',
          );
          tp.layout(maxWidth: constraints.maxWidth);
          if (tp.height <= maxHeight) {
            return Text(
              text,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
          }
        }
        final fallback = baseStyle.copyWith(fontSize: candidateFontSizes.last);
        return Text(
          text,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: fallback,
        );
      },
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final int selectedCount;
  final List<String> names;
  final ValueChanged<String> onRemove;
  final VoidCallback onStart;
  final int minRequired;
  const _BottomPanel({required this.selectedCount, required this.names, required this.onRemove, required this.onStart, required this.minRequired});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFABC270).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -4)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (context) {
                          return SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Espèces sélectionnées',
                                          style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w900, fontSize: 18),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        onPressed: () => Navigator.pop(context),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (names.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: Text('Aucune espèce sélectionnée pour le moment.', style: TextStyle(fontFamily: 'Quicksand')),
                                    )
                                  else
                                    SizedBox(
                                      height: 300,
                                      child: ListView.separated(
                                        itemCount: names.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, i) {
                                          final name = names[i];
                                          return ListTile(
                                            dense: true,
                                            title: Text(name, style: const TextStyle(fontFamily: 'Quicksand')),
                                            trailing: IconButton(
                                              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFBC4749)),
                                              onPressed: () {
                                                Navigator.pop(context);
                                                onRemove(name);
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                    child: RecapButton(
                      size: RecapButtonSize.small,
                      text: 'Total $selectedCount / ${(selectedCount >= minRequired) ? selectedCount : minRequired}',
                      backgroundColor: Colors.white,
                      textColor: const Color(0xFF344356),
                      borderColor: const Color(0xFFD6D3D1),
                      hoverBackgroundColor: const Color(0xFFF6F7F8),
                      hoverBorderColor: const Color(0xFFCFCFCF),
                      shadowColor: const Color(0xFFABC270),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      borderRadius: 12,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          builder: (context) {
                            return SafeArea(
                              top: false,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Espèces sélectionnées',
                                            style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w900, fontSize: 18),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () => Navigator.pop(context),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (names.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text('Aucune espèce sélectionnée pour le moment.', style: TextStyle(fontFamily: 'Quicksand')),
                                      )
                                    else
                                      SizedBox(
                                        height: 300,
                                        child: ListView.separated(
                                          itemCount: names.length,
                                          separatorBuilder: (_, __) => const Divider(height: 1),
                                          itemBuilder: (context, i) {
                                            final name = names[i];
                                            return ListTile(
                                              dense: true,
                                              title: Text(name, style: const TextStyle(fontFamily: 'Quicksand')),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFBC4749)),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  onRemove(name);
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                RecapButton(
                  text: selectedCount >= minRequired ? 'Lancer' : 'Verrouillé',
                  size: RecapButtonSize.small,
                  disabled: !(selectedCount >= minRequired),
                  backgroundColor: selectedCount >= minRequired ? const Color(0xFF6A994E) : const Color(0xFFD1D5DB),
                  // Contour = même teinte que l'ombre (#415E31) quand actif
                  borderColor: selectedCount >= minRequired ? const Color(0xFF415E31) : null,
                  hoverBorderColor: selectedCount >= minRequired ? const Color(0xFF415E31) : null,
                  // Hover dérivé automatiquement pour rester plus clair que le contour
                  shadowColor: selectedCount >= minRequired ? const Color(0xFF415E31) : const Color(0xFF9CA3AF),
                  textColor: selectedCount >= minRequired ? Colors.white : const Color(0xFF374151),
                  leadingAsset: selectedCount >= minRequired ? null : 'assets/Images/Bouton/logolock.png',
                  leadingSize: 35,
                  leadingGap: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  borderRadius: 12,
                  onPressed: selectedCount >= minRequired ? onStart : null,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizConfigDialog extends StatefulWidget {
  final List<Bird> selectedBirds;
  final Function(List<QuizQuestion>) onLaunch;
  final Function(String name, String description, int questionsCount, List<QuizQuestion>) onSave;

  const _QuizConfigDialog({
    required this.selectedBirds,
    required this.onLaunch,
    required this.onSave,
  });

  @override
  State<_QuizConfigDialog> createState() => _QuizConfigDialogState();
}

class _QuizConfigDialogState extends State<_QuizConfigDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isGenerating = false;
  List<QuizQuestion>? _questions;
  int _selectedQuestionCount = 10;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  Future<void> _generateQuestions() async {
    setState(() => _isGenerating = true);
    try {
      await MissionPreloader.preloadAudioForBirds(widget.selectedBirds.map((b) => b.nomFr).toList());
      final questions = await QuizGenerator.generateQuizFromBirds(widget.selectedBirds, maxQuestions: _selectedQuestionCount);
      if (mounted) {
        setState(() {
          _questions = questions;
          _isGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: const Text(
        'Configuration du quiz',
        style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w900, fontSize: 20),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 320,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              '${widget.selectedBirds.length} espèces sélectionnées',
              style: const TextStyle(fontFamily: 'Quicksand', color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            // Sélecteur nombre de questions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nombre de questions:', style: TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 10, label: Text('10')),
                    ButtonSegment(value: 20, label: Text('20')),
                  ],
                  selected: {_selectedQuestionCount},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _selectedQuestionCount = selection.first;
                      _generateQuestions();
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    textStyle: const TextStyle(fontFamily: 'Quicksand', fontSize: 16, fontWeight: FontWeight.w600),
                    selectedBackgroundColor: const Color(0xFF6A994E),
                    selectedForegroundColor: Colors.white,
                    backgroundColor: const Color(0xFFF9FAFB),
                    foregroundColor: const Color(0xFF374151),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du quiz',
                hintText: 'Ex: Mes oiseaux favoris',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF9FAFB),
              ),
              style: const TextStyle(fontFamily: 'Quicksand'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optionnelle)',
                hintText: 'Décrivez votre quiz personnalisé...',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Color(0xFFF9FAFB),
              ),
              style: const TextStyle(fontFamily: 'Quicksand'),
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Génération en cours...', style: TextStyle(fontFamily: 'Quicksand')),
                ],
              ),
            ],
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Expanded(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler', style: TextStyle(fontFamily: 'Quicksand', fontSize: 16)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RecapButton(
            text: 'Sauvegarder',
            size: RecapButtonSize.small,
            disabled: _isGenerating || _questions == null || _nameController.text.trim().isEmpty,
            backgroundColor: const Color(0xFF6A994E),
            textColor: Colors.white,
            shadowColor: const Color(0xFF415E31),
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: () {
              if (_questions != null && _nameController.text.trim().isNotEmpty) {
                widget.onSave(_nameController.text.trim(), _descController.text.trim(), _selectedQuestionCount, _questions!);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RecapButton(
            text: 'Lancer',
            size: RecapButtonSize.small,
            disabled: _isGenerating || _questions == null,
            backgroundColor: const Color(0xFF6A994E),
            textColor: Colors.white,
            shadowColor: const Color(0xFF415E31),
            borderRadius: 8,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onPressed: () {
              if (_questions != null) {
                widget.onLaunch(_questions!);
              }
            },
          ),
        ),
      ],
    );
  }
}


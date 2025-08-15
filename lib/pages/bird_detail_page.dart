import 'package:flutter/material.dart';
import '../ui/responsive/responsive.dart';
import '../services/bird_detail_repository.dart';
import '../models/bird_detail_data.dart';

class BirdDetailPage extends StatefulWidget {
  final String birdId; // peut être id ou nom commun selon appelant
  const BirdDetailPage({super.key, required this.birdId});

  @override
  State<BirdDetailPage> createState() => _BirdDetailPageState();
}

class _BirdDetailPageState extends State<BirdDetailPage> {
  late final BirdDetailRepository _repo;
  BirdDetailData? _data;
  bool _loading = true;
  String? _error;

  final PageController _pageController = PageController();
  int _currentSection = 0; // 0..4

  @override
  void initState() {
    super.initState();
    _repo = BirdDetailRepository();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _repo.fetchById(widget.birdId);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null || _data == null) {
            return Center(child: Text('Impossible de charger la fiche', style: TextStyle(fontFamily: 'Quicksand', fontSize: m.font(16))));
          }
          final data = _data!;

          return Stack(
            children: [
              // Image de couverture
              Positioned.fill(
                child: data.imageUrl.isNotEmpty
                    ? Image.network(
                        data.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFFD2DBB2)),
                      )
                    : Container(color: const Color(0xFFD2DBB2)),
              ),

              // Gradient top for legibility
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: m.dp(140),
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xB3000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // Bouton retour + titres superposés
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(m.dp(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _CircleBackButton(size: m.dp(44)),
                      SizedBox(width: m.dp(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.commonName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w900,
                                fontSize: m.font(22, tabletFactor: 1.06, min: 18, max: 34),
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: m.dp(2)),
                            Text(
                              data.scientificName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                fontSize: m.font(14, tabletFactor: 1.05, min: 12, max: 20),
                                color: const Color(0xFFECECEC),
                              ),
                            ),
                            if (data.family.isNotEmpty) ...[
                              SizedBox(height: m.dp(2)),
                              Text(
                                data.family,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Quicksand',
                                  fontWeight: FontWeight.w500,
                                  fontSize: m.font(13, tabletFactor: 1.05, min: 11, max: 18),
                                  color: const Color(0xFFEDEDED),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Sheet partiellement ouverte + glissable
              _BottomSheetSections(
                metrics: m,
                currentIndex: _currentSection,
                onIndexChanged: (i) {
                  setState(() => _currentSection = i);
                  _pageController.animateToPage(i, duration: const Duration(milliseconds: 260), curve: Curves.easeOut);
                },
                pageView: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentSection = i),
                  children: [
                    _SectionContent(title: 'Identification', color: const Color(0xFF606D7C), body: data.identification),
                    _SectionContent(title: 'Habitat', color: const Color(0xFF6A994E), body: data.habitat),
                    _SectionContent(title: 'Alimentation', color: const Color(0xFFFF98B7), body: data.alimentation),
                    _SectionContent(title: 'Reproduction', color: const Color(0xFFABC270), body: data.reproduction),
                    _SectionContent(title: 'Répartition', color: const Color(0xFFFC826A), body: data.repartition),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  final double size;
  const _CircleBackButton({required this.size});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFECECEC), width: 2),
            color: const Color(0x33000000),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
    );
  }
}

class _BottomSheetSections extends StatefulWidget {
  final ResponsiveMetrics metrics;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final Widget pageView;
  const _BottomSheetSections({
    required this.metrics,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.pageView,
  });

  @override
  State<_BottomSheetSections> createState() => _BottomSheetSectionsState();
}

class _BottomSheetSectionsState extends State<_BottomSheetSections> with SingleTickerProviderStateMixin {
  late DraggableScrollableController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.35,
      minChildSize: 0.30,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.35, 0.65, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5F9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Color(0x3F000000), blurRadius: 10, offset: Offset(0, -8)),
            ],
          ),
          child: Column(
            children: [
              SizedBox(height: m.dp(8)),
              Container(
                width: m.dp(70),
                height: m.dp(5),
                decoration: BoxDecoration(
                  color: const Color(0x70344356),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              SizedBox(height: m.dp(8)),
              _SectionTabs(currentIndex: widget.currentIndex, onTap: widget.onIndexChanged),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) => false,
                  child: widget.pageView,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTabs extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _SectionTabs({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final labels = const ['Identification', 'Habitat', 'Alimentation', 'Reproduction', 'Répartition'];
    final colors = const [Color(0xFF606D7C), Color(0xFF6A994E), Color(0xFFFF98B7), Color(0xFFABC270), Color(0xFFFC826A)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(labels[i], style: const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w700)),
                selected: currentIndex == i,
                onSelected: (_) => onTap(i),
                selectedColor: colors[i].withOpacity(0.18),
                backgroundColor: Colors.white,
                labelStyle: TextStyle(color: currentIndex == i ? colors[i] : const Color(0xFF344356)),
                shape: const StadiumBorder(side: BorderSide(color: Color(0x2D000000), width: 1)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  final String title;
  final Color color;
  final String body;
  const _SectionContent({required this.title, required this.color, required this.body});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(m.dp(16), m.dp(12), m.dp(16), m.dp(28)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w900,
                  fontSize: m.font(28, tabletFactor: 1.08, min: 20, max: 40),
                  color: color,
                ),
              ),
              SizedBox(height: m.gapSmall()),
              Text(
                body.isNotEmpty ? body : 'Contenu à venir…',
                style: TextStyle(
                  fontFamily: 'Quicksand',
                  fontSize: m.font(16, tabletFactor: 1.04, min: 13, max: 22),
                  color: const Color(0xFF606D7C),
                  height: 1.45,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}



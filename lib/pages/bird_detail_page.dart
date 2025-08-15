import 'package:flutter/material.dart';
import '../models/bird.dart';
import '../ui/responsive/responsive.dart';
import '../theme/colors.dart';

class BirdDetailPage extends StatefulWidget {
  final Bird bird;

  const BirdDetailPage({
    super.key,
    required this.bird,
  });

  @override
  State<BirdDetailPage> createState() => _BirdDetailPageState();
}

class _BirdDetailPageState extends State<BirdDetailPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          return _buildContent(context, m);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, ResponsiveMetrics m) {
    return CustomScrollView(
      slivers: [
        // Hero image avec AppBar intégré
        _buildHeroSection(context, m),
        
        // Contenu principal
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.background,
            child: Column(
              children: [
                _buildInfoSection(context, m),
                _buildTabsSection(context, m),
                _buildIdentificationSection(context, m),
                SizedBox(height: m.gapLarge()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection(BuildContext context, ResponsiveMetrics m) {
    final double imageHeight = m.isTablet ? 400.0 : 320.0;
    
    return SliverAppBar(
      expandedHeight: imageHeight,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: Container(
        margin: EdgeInsets.all(m.dp(8)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.textDark,
            size: m.dp(24),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image principale
            if (widget.bird.urlImage.isNotEmpty)
              Image.network(
                widget.bird.urlImage,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.lightGreen.withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: m.dp(64),
                        color: AppColors.secondary,
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: AppColors.lightGreen.withOpacity(0.3),
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: m.dp(64),
                    color: AppColors.secondary,
                  ),
                ),
              ),
            
            // Gradient overlay au bas
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withOpacity(0.8),
                      AppColors.background,
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

  Widget _buildInfoSection(BuildContext context, ResponsiveMetrics m) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: m.dp(20),
        vertical: m.gapMedium(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom français
          Text(
            widget.bird.nomFr,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(28, tabletFactor: 1.1),
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          
          SizedBox(height: m.gapSmall()),
          
          // Ligne séparatrice
          Container(
            height: 2,
            width: m.dp(60),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          
          SizedBox(height: m.gapMedium()),
          
          // Informations détaillées
          _buildInfoRow(
            context, 
            m, 
            'Nom', 
            widget.bird.nomFr,
          ),
          
          SizedBox(height: m.gapSmall()),
          
          _buildInfoRow(
            context, 
            m, 
            'Nom scientifique', 
            '${widget.bird.genus} ${widget.bird.species}',
          ),
          
          SizedBox(height: m.gapSmall()),
          
          _buildInfoRow(
            context, 
            m, 
            'Famille', 
            _getFamilyName(widget.bird.genus),
          ),
          
          if (widget.bird.milieux.isNotEmpty) ...[
            SizedBox(height: m.gapSmall()),
            _buildInfoRow(
              context, 
              m, 
              'Milieux', 
              widget.bird.milieux.join(', '),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, ResponsiveMetrics m, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.dp(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: m.dp(140),
            child: Text(
              '$label :',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: m.font(16, tabletFactor: 1.05),
                fontWeight: FontWeight.w400,
                color: AppColors.textDark.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: m.font(16, tabletFactor: 1.05),
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsSection(BuildContext context, ResponsiveMetrics m) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: m.dp(20)),
      child: Row(
        children: [
          _buildTab(context, m, 'Identification', true, const Color(0xFFFF98B7)),
          SizedBox(width: m.dp(8)),
          _buildTab(context, m, 'Habitat', false, const Color(0xFFFC826A)),
          SizedBox(width: m.dp(8)),
          _buildTab(context, m, 'Audio', false, const Color(0xFFFEC868)),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, ResponsiveMetrics m, String title, bool isActive, Color color) {
    return Expanded(
      child: Container(
        height: m.dp(50),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.white,
          borderRadius: BorderRadius.circular(m.dp(15)),
          border: Border.all(
            color: isActive ? color : AppColors.textDark.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(14, tabletFactor: 1.05),
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textDark.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificationSection(BuildContext context, ResponsiveMetrics m) {
    return Container(
      margin: EdgeInsets.all(m.dp(20)),
      padding: EdgeInsets.all(m.dp(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.dp(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identification',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(24, tabletFactor: 1.1),
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
          
          SizedBox(height: m.gapMedium()),
          
          Text(
            _getIdentificationText(),
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(16, tabletFactor: 1.05),
              fontWeight: FontWeight.w500,
              color: AppColors.textDark.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getFamilyName(String genus) {
    // Map de quelques genres vers leurs familles
    final Map<String, String> familyMap = {
      'Coracias': 'Coraciidés',
      'Parus': 'Paridés',
      'Turdus': 'Turdidés',
      'Falco': 'Falconidés',
      'Buteo': 'Accipitridés',
      'Ardea': 'Ardéidés',
      'Corvus': 'Corvidés',
      'Hirundo': 'Hirundinidés',
      'Passer': 'Passéridés',
    };
    
    return familyMap[genus] ?? 'Non renseigné';
  }

  String _getIdentificationText() {
    // Texte générique adapté selon l'espèce
    if (widget.bird.genus == 'Coracias') {
      return "Chez nous en Europe, cet oiseau de la taille d'un geai est unique et inconfondable. Quand on observe un Rollier d'Europe, on voit un oiseau bleu. En effet chez lui, la tête, les ailes et toutes les parties inférieures sont d'un bleu aigue-marine, tout au moins chez l'adulte. En vue de profil, le brun fauve façon \"crécerelle mâle\" du dos, du manteau et des scapulaires contraste joliment. Il y a même une touche de bleu azur aux épaules. En vol, c'est le festival de couleurs car s'ajoute au panel le noir ou le bleu des rémiges suivant qu'on l'observe en vol de dessus ou de dessous. La tête est barrée latéralement de noir. Cette barre est formée du bec fort, de la zone lorale, de l'œil et de la zone post-oculaire. Les pattes sont rosées. Les sexes sont semblables.";
    }
    
    return "Cet oiseau présente des caractéristiques distinctives qui permettent son identification en milieu naturel. L'observation attentive de son plumage, de sa silhouette et de son comportement facilitent sa reconnaissance sur le terrain. Les variations saisonnières et les différences entre mâles et femelles peuvent également aider à l'identification précise de l'espèce.";
  }
}
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
  bool _isPlayingAudio = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          
          return CustomScrollView(
            slivers: [
              // App Bar personnalisée avec image de fond
              _buildSliverAppBar(m),
              
              // Contenu principal
              SliverToBoxAdapter(
                child: _buildMainContent(m),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(ResponsiveMetrics m) {
    final double appBarHeight = m.dp(400, tabletFactor: 1.2, min: 350, max: 500);
    
    return SliverAppBar(
      expandedHeight: appBarHeight,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: Padding(
        padding: EdgeInsets.all(m.dp(8)),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.primary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.all(m.dp(8)),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.favorite_border, color: AppColors.primary),
              onPressed: () {
                // TODO: Ajouter/retirer des favoris
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fonctionnalité des favoris à venir')),
                );
              },
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Image de l'oiseau
            widget.bird.urlImage.isNotEmpty
                ? Image.network(
                    widget.bird.urlImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.lightGreen.withOpacity(0.3),
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 80,
                          color: AppColors.secondary,
                        ),
                      );
                    },
                  )
                : Container(
                    color: AppColors.lightGreen.withOpacity(0.3),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 80,
                      color: AppColors.secondary,
                    ),
                  ),
            
            // Gradient overlay pour la lisibilité
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            
            // Bouton de lecture audio
            if (widget.bird.urlMp3.isNotEmpty)
              Positioned(
                bottom: m.dp(20),
                right: m.dp(20),
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  onPressed: _toggleAudio,
                  child: Icon(_isPlayingAudio ? Icons.pause : Icons.play_arrow),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(ResponsiveMetrics m) {
    return Container(
      padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nom et titre
          _buildBirdTitle(m),
          
          SizedBox(height: m.gapLarge()),
          
          // Informations de base
          _buildBasicInfo(m),
          
          SizedBox(height: m.gapLarge()),
          
          // Habitats
          _buildHabitats(m),
          
          SizedBox(height: m.gapLarge()),
          
          // Section identification (placeholder)
          _buildIdentificationSection(m),
          
          SizedBox(height: m.gapLarge()),
        ],
      ),
    );
  }

  Widget _buildBirdTitle(ResponsiveMetrics m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.bird.nomFr,
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: m.font(32, tabletFactor: 1.1, min: 24, max: 48),
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: m.gapSmall()),
        Text(
          '${widget.bird.genus} ${widget.bird.species}',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontSize: m.font(20, tabletFactor: 1.05, min: 16, max: 28),
            fontWeight: FontWeight.w500,
            color: AppColors.textDark.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfo(ResponsiveMetrics m) {
    return Container(
      padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.dp(16, tabletFactor: 1.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations générales',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(22, tabletFactor: 1.05, min: 18, max: 30),
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: m.gapMedium()),
          
          _buildInfoRow(m, 'Nom français', widget.bird.nomFr),
          _buildInfoRow(m, 'Nom scientifique', '${widget.bird.genus} ${widget.bird.species}'),
          _buildInfoRow(m, 'Genre', widget.bird.genus),
          _buildInfoRow(m, 'Espèce', widget.bird.species),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ResponsiveMetrics m, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: m.gapSmall()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: m.dp(140, tabletFactor: 1.1),
            child: Text(
              '$label :',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
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
                fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitats(ResponsiveMetrics m) {
    if (widget.bird.milieux.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.dp(16, tabletFactor: 1.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Habitats',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(22, tabletFactor: 1.05, min: 18, max: 30),
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: m.gapMedium()),
          
          Wrap(
            spacing: m.dp(8),
            runSpacing: m.dp(8),
            children: widget.bird.milieux.map((milieu) => _buildHabitatChip(m, milieu)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitatChip(ResponsiveMetrics m, String milieu) {
    // Couleurs selon le type d'habitat
    Color chipColor;
    switch (milieu.toLowerCase()) {
      case 'forestier':
        chipColor = const Color(0xFF4CAF50);
        break;
      case 'urbain':
        chipColor = const Color(0xFF9E9E9E);
        break;
      case 'agricole':
        chipColor = const Color(0xFFFF9800);
        break;
      case 'humide':
        chipColor = const Color(0xFF2196F3);
        break;
      case 'montagnard':
        chipColor = const Color(0xFF795548);
        break;
      case 'littoral':
        chipColor = const Color(0xFF00BCD4);
        break;
      default:
        chipColor = AppColors.secondary;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.dp(16, tabletFactor: 1.05),
        vertical: m.dp(8, tabletFactor: 1.05),
      ),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(m.dp(20, tabletFactor: 1.05)),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Text(
        milieu.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontSize: m.font(14, tabletFactor: 1.0, min: 12, max: 18),
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }

  Widget _buildIdentificationSection(ResponsiveMetrics m) {
    return Container(
      padding: EdgeInsets.all(m.dp(20, tabletFactor: 1.1)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.dp(16, tabletFactor: 1.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
              fontSize: m.font(22, tabletFactor: 1.05, min: 18, max: 30),
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: m.gapMedium()),
          
          Text(
            'Les informations détaillées d\'identification seront bientôt disponibles.',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: m.font(16, tabletFactor: 1.0, min: 14, max: 20),
              fontWeight: FontWeight.w500,
              color: AppColors.textDark.withOpacity(0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAudio() {
    if (widget.bird.urlMp3.isEmpty) return;
    
    setState(() {
      _isPlayingAudio = !_isPlayingAudio;
    });
    
    // TODO: Implémenter la lecture audio
    if (_isPlayingAudio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecture audio en cours...')),
      );
      
      // Simuler l'arrêt automatique après quelques secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      });
    }
  }
}
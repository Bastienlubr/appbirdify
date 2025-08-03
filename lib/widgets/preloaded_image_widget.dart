import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/asset_preloader_service.dart';
import '../services/local_image_service.dart';
import '../theme/colors.dart';

/// Widget spécialisé pour afficher les images préchargées
/// Évite les effets de flash et utilise le cache du préchargeur
class PreloadedImageWidget extends StatefulWidget {
  final String birdName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool showLoadingIndicator;

  const PreloadedImageWidget({
    super.key,
    required this.birdName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.showLoadingIndicator = true,
  });

  @override
  State<PreloadedImageWidget> createState() => _PreloadedImageWidgetState();
}

class _PreloadedImageWidgetState extends State<PreloadedImageWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final AssetPreloaderService _preloaderService = AssetPreloaderService();
  final LocalImageService _localImageService = LocalImageService();
  
  ImageProvider? _imageProvider;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadImage();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _setupAnimation() {
    _fadeController = AnimationController(
      duration: widget.fadeInDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _loadImage() async {
    try {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Vérifier si l'image est préchargée
      if (_preloaderService.isImagePreloaded(widget.birdName)) {
        if (kDebugMode) debugPrint('✅ Image préchargée trouvée: ${widget.birdName}');
        
        _imageProvider = _preloaderService.getPreloadedImage(widget.birdName);
        
        if (_imageProvider != null && mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Démarrer l'animation de fade-in
          _fadeController.forward();
          return;
        }
      }

      // Fallback: essayer l'image locale
      if (_localImageService.hasLocalImage(widget.birdName)) {
        if (kDebugMode) debugPrint('📸 Image locale trouvée: ${widget.birdName}');
        
        _imageProvider = _localImageService.getImageProvider(widget.birdName);
        
        if (_imageProvider != null && mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Démarrer l'animation de fade-in
          _fadeController.forward();
          return;
        }
      }

      // Fallback: essayer l'image Firebase depuis les données Birdify
      if (kDebugMode) debugPrint('⚠️ Image non préchargée, tentative chargement Firebase: ${widget.birdName}');
      
      // Ici on pourrait implémenter un fallback pour charger l'image depuis Birdify
      // Pour l'instant, on affiche une erreur
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Image non disponible';
        });
      }
      
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur chargement image ${widget.birdName}: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: widget.borderRadius != null
          ? BoxDecoration(
              borderRadius: widget.borderRadius,
            )
          : null,
      clipBehavior: widget.borderRadius != null ? Clip.antiAlias : Clip.none,
      child: _buildImageContent(),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    
    if (_hasError) {
      return _buildErrorState();
    }
    
    if (_imageProvider != null) {
      return _buildImageState();
    }
    
    return _buildPlaceholderState();
  }

  Widget _buildLoadingState() {
    if (widget.showLoadingIndicator) {
      return Container(
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chargement...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontFamily: 'Quicksand',
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return widget.placeholder ?? _buildDefaultPlaceholder();
  }

  Widget _buildErrorState() {
    return widget.errorWidget ?? _buildDefaultErrorWidget();
  }

  Widget _buildImageState() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Image(
            image: _imageProvider!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              if (kDebugMode) debugPrint('❌ Erreur affichage image: $error');
              return _buildDefaultErrorWidget();
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderState() {
    return widget.placeholder ?? _buildDefaultPlaceholder();
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.image,
          size: 32,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 32,
              color: AppColors.accent,
            ),
            const SizedBox(height: 8),
            Text(
              'Image non disponible',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontFamily: 'Quicksand',
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.accent.withValues(alpha: 0.7),
                  fontFamily: 'Quicksand',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget pour afficher une image avec préchargement automatique
/// Utilise le service de préchargement pour optimiser les performances
class OptimizedImageWidget extends StatelessWidget {
  final String birdName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration fadeInDuration;
  final bool showLoadingIndicator;

  const OptimizedImageWidget({
    super.key,
    required this.birdName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.showLoadingIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return PreloadedImageWidget(
      birdName: birdName,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      placeholder: placeholder,
      errorWidget: errorWidget,
      fadeInDuration: fadeInDuration,
      showLoadingIndicator: showLoadingIndicator,
    );
  }
} 
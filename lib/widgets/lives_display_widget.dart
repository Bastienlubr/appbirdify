import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/life_sync_service.dart';

class LivesDisplayWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final double? iconSize;
  final double? fontSize;
  final Color? textColor;
  final bool showBackground;

  const LivesDisplayWidget({
    super.key,
    this.width,
    this.height,
    this.iconSize,
    this.fontSize,
    this.textColor,
    this.showBackground = true,
  });

  @override
  State<LivesDisplayWidget> createState() => _LivesDisplayWidgetState();
}

class _LivesDisplayWidgetState extends State<LivesDisplayWidget> {
  int _currentLives = 5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLives();
  }

  Future<void> _loadLives() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Synchroniser les vies et récupérer le nombre actuel
        await LifeSyncService.syncLivesOnHomeEntry(user.uid);
        final lives = await LifeSyncService.getCurrentLives(user.uid);
        
        if (mounted) {
          setState(() {
            _currentLives = lives;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentLives = 5; // Valeur par défaut si pas connecté
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLives = 5; // Valeur par défaut en cas d'erreur
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: widget.width ?? 80,
        height: widget.height ?? 40,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF386641)),
            ),
          ),
        ),
      );
    }

    if (widget.showBackground) {
      return Stack(
        alignment: Alignment.topRight,
        children: [
          // Image de fond du compteur
          Image.asset(
            'assets/Images/Bouton/viequizmission.png',
            width: widget.width ?? 80,
            height: widget.height ?? 40,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: widget.width ?? 80,
                height: widget.height ?? 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD2DBB2),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
          // Contenu superposé (cœur + nombre)
          Positioned(
            left: 10,
            top: -5,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône cœur
                Image.asset(
                  'assets/Images/Bouton/Copie de Copie de Un bol d\'Air Frais (23).png',
                  width: widget.iconSize ?? 35,
                  height: widget.iconSize ?? 35,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: widget.iconSize ?? 35,
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Nombre de vies
                Text(
                  '$_currentLives',
                  style: TextStyle(
                    fontFamily: 'Quicksand',
                    fontSize: widget.fontSize ?? 35,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor ?? Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // Version simple sans fond
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône cœur
          Image.asset(
            'assets/Images/Bouton/Copie de Copie de Un bol d\'Air Frais (23).png',
            width: widget.iconSize ?? 30,
            height: widget.iconSize ?? 30,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.favorite,
                color: Colors.red,
                size: widget.iconSize ?? 30,
              );
            },
          ),
          const SizedBox(width: 2),
          // Nombre de vies
          Text(
            '$_currentLives',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: widget.fontSize ?? 24,
              fontWeight: FontWeight.w700,
              color: widget.textColor ?? const Color(0xFF473C33),
            ),
          ),
        ],
      );
    }
  }
}

// Widget pour afficher les vies dans le bloc de statistiques
class LivesStatsWidget extends StatelessWidget {
  const LivesStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const LivesDisplayWidget(
      showBackground: false,
      iconSize: 30,
      fontSize: 24,
      textColor: Color(0xFF473C33),
    );
  }
}

// Widget pour afficher les vies dans le quiz
class LivesQuizWidget extends StatelessWidget {
  const LivesQuizWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const LivesDisplayWidget(
      showBackground: true,
      width: 80,
      height: 40,
      iconSize: 35,
      fontSize: 35,
      textColor: Colors.black,
    );
  }
} 
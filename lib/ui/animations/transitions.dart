import 'package:flutter/material.dart';

/// 🎬 Animations centralisées optimisées pour 60 FPS constants
/// Toutes les transitions de l'app sont définies ici pour :
/// - Cohérence visuelle parfaite
/// - Réutilisabilité maximale  
/// - Maintenance centralisée
/// - Performance optimisée
class AppTransitions {
  
  // ⏱️ Durées optimisées pour fluidité maximale
  static const Duration _fastDuration = Duration(milliseconds: 250);
  static const Duration _standardDuration = Duration(milliseconds: 400);
  // Removed unused: _slowDuration
  
  // 🎭 Courbes optimisées pour sensation premium
  static const Curve _enterCurve = Curves.easeOutQuart;
  static const Curve _exitCurve = Curves.easeInQuart;
  static const Curve _smoothCurve = Curves.easeInOutCubic;

  /// 🌟 PERCHOIR SLIDE AUTH-STYLE
  /// Animation EXACTEMENT identique aux pages login/register
  /// Slide de droite avec effet premium
  static Widget perchoinSlideTransition(Widget child, Animation<double> animation) {
    // 🎯 Animation IDENTIQUE aux pages auth (login_screen.dart ligne 297-302)
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeInOut;
    
    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    var offsetAnimation = animation.drive(tween);
    
    return SlideTransition(
      position: offsetAnimation,
      child: child,
    );
  }

  /// 🌙 FADE PREMIUM
  /// Transition élégante pour pages standards
  static Widget premiumFadeTransition(Widget child, Animation<double> animation) {
    // 🎭 Fade avec courbe optimisée
    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: _enterCurve,
    ));
    
    // ✨ Scale très subtil pour éviter l'effet "plat"
    final scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: _smoothCurve,
    ));

    return FadeTransition(
      opacity: fadeAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        child: child,
      ),
    );
  }

  /// 🚀 PAGE ROUTE BUILDER PRÊTS À L'EMPLOI
  /// Utilisation directe dans Navigator.push()
  
  /// Route avec slide Perchoir optimisé
  static PageRouteBuilder<T> perchoinSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _standardDuration, // ✅ 400ms pour fluidité parfaite
      reverseTransitionDuration: _fastDuration, // ✅ 250ms retour plus rapide
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 🎯 Animation entrée
        if (animation.status == AnimationStatus.forward) {
          return perchoinSlideTransition(child, animation);
        }
        // 🔄 Animation sortie (retour)
        else {
          final reverseSlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(1.0, 0.0), // ✅ Sort vers la droite
          ).animate(CurvedAnimation(
            parent: secondaryAnimation,
            curve: _exitCurve,
          ));
          
          return SlideTransition(
            position: reverseSlide,
            child: child,
          );
        }
      },
    );
  }

  /// Route avec fade premium
  static PageRouteBuilder<T> premiumFadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _fastDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return premiumFadeTransition(child, animation);
      },
    );
  }

  /// 🎮 ANIMATEDSWITCHER BUILDERS
  /// Pour utilisation dans AnimatedSwitcher.transitionBuilder
  
  /// Builder pour AnimatedSwitcher avec logique Perchoir
  static Widget smartTransitionBuilder(Widget child, Animation<double> animation, int currentIndex, int previousIndex) {
    // 🎯 Animation auth-style pour Perchoir (index 3)
    if (currentIndex == 3 || previousIndex == 3) {
      return perchoinSlideTransition(child, animation);
    }
    // 🌙 Fade premium pour autres pages
    else {
      return premiumFadeTransition(child, animation);
    }
  }
}

/// 🎨 Extensions utilitaires pour animations custom
extension AnimationExtensions on Animation<double> {
  /// Crée une courbe personnalisée sur un interval
  Animation<double> interval(double begin, double end, {Curve curve = Curves.linear}) {
    return CurvedAnimation(
      parent: this,
      curve: Interval(begin, end, curve: curve),
    );
  }
}

/// 📱 Constantes visuelles pour cohérence
class VisualConstants {
  static const double subtleScale = 0.98;
  static const double dynamicScale = 0.95;
  static const Offset slideRightBegin = Offset(1.2, 0.0);
  static const Offset slideLeftBegin = Offset(-1.2, 0.0);
  static const Duration quickTransition = Duration(milliseconds: 200);
  static const Duration standardTransition = Duration(milliseconds: 400);
  static const Duration slowTransition = Duration(milliseconds: 600);
}

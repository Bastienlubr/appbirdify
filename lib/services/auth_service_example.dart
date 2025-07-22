import 'auth_service.dart';

/// Exemple d'utilisation du AuthService
class AuthServiceExample {
  
  /// Exemple : Vérifier l'état de connexion
  static void checkAuthState() {
    // 🔍 Vérification de l'état d'authentification...
    
    // Exemple d'utilisation des propriétés AuthService
    // final isLoggedIn = AuthService.isUserLoggedIn;
    // final currentUser = AuthService.currentUser;
    // final userId = AuthService.currentUserId;
    // final email = AuthService.currentUserEmail;
    
    // ✅ Utilisateur connecté: $isLoggedIn
    // 👤 Utilisateur actuel: ${currentUser?.uid ?? 'Aucun'}
    // 🆔 ID utilisateur: ${userId ?? 'Aucun'}
    // 📧 Email: ${email ?? 'Aucun'}
  }
  
  /// Exemple : Afficher les informations du profil
  static void displayUserProfile() {
    // 👤 Affichage du profil utilisateur...
    
    final profile = AuthService.userProfile;
    
    if (profile != null) {
      // ✅ Profil trouvé:
      profile.forEach((key, value) {
        //   $key: $value
      });
    } else {
      // ❌ Aucun profil utilisateur trouvé
    }
  }
  
  /// Exemple : Vérifier les propriétés de l'utilisateur
  static void checkUserProperties() {
    // 🔍 Vérification des propriétés utilisateur...
    
    // Exemple d'utilisation des propriétés AuthService
    // final isAnonymous = AuthService.isAnonymous;
    // final isEmailVerified = AuthService.isEmailVerified;
    // final isNewUser = AuthService.isNewUser;
    // final timeSinceLastSignIn = AuthService.timeSinceLastSignIn;
    
    // 👻 Utilisateur anonyme: $isAnonymous
    // ✅ Email vérifié: $isEmailVerified
    // 🆕 Nouvel utilisateur: $isNewUser
    
    // if (timeSinceLastSignIn != null) {
    //   final hours = timeSinceLastSignIn.inHours;
    //   final minutes = timeSinceLastSignIn.inMinutes % 60;
    //   // ⏰ Dernière connexion: il y a ${hours}h ${minutes}min
    // } else {
    //   // ⏰ Dernière connexion: inconnue
    // }
  }
  
  /// Exemple : Écouter les changements d'état d'authentification
  static void listenToAuthChanges() {
    // Note: Cette méthode est commentée pour éviter les appels print() dans les exemples
    // Dans un vrai usage, vous pourriez utiliser debugPrint() ou un logger
    
    // final subscription = AuthService.listenToAuthChanges().listen(
    //   (user) {
    //     if (user != null) {
    //       // Utilisateur connecté: ${user.email}
    //     } else {
    //       // Utilisateur déconnecté
    //     }
    //   },
    //   onError: (error) {
    //     // Erreur lors de l'écoute: $error
    //   },
    // );
    
    // Note: Dans un vrai usage, il faudrait gérer la désinscription
    // subscription.cancel();
  }
  
  /// Exemple : Utilisation complète
  static void runCompleteExample() {
    // 🚀 Démarrage de l'exemple complet du AuthService
    
    // 1. Vérifier l'état de connexion
    checkAuthState();
    
    // ==================================================
    
    // 2. Afficher le profil utilisateur
    displayUserProfile();
    
    // ==================================================
    
    // 3. Vérifier les propriétés
    checkUserProperties();
    
    // ==================================================
    
    // 4. Démarrer l'écoute (commenté pour éviter les blocages)
    // listenToAuthChanges();
    
    // ✅ Exemple terminé !
  }
} 
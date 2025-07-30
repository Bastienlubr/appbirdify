import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../pages/home_screen.dart';
import 'package:flutter/foundation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Le mot de passe est trop faible. Utilisez au moins 6 caractères.';
      case 'email-already-in-use':
        return 'Cette adresse email est déjà utilisée.';
      case 'invalid-email':
        return 'Adresse email invalide.';
      case 'operation-not-allowed':
        return 'L\'inscription par email/mot de passe n\'est pas activée.';
      case 'network-request-failed':
        return 'Erreur de connexion réseau. Vérifiez votre connexion internet.';
      default:
        return 'Erreur lors de l\'inscription: $code';
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs';
        _isLoading = false;
      });
      return;
    }

    final isValidEmail = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
    if (!isValidEmail) {
      setState(() {
        _errorMessage = 'Veuillez entrer une adresse email valide';
        _isLoading = false;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = 'Le mot de passe doit contenir au moins 6 caractères';
        _isLoading = false;
      });
      return;
    }

    try {
      // Créer l'utilisateur avec Firebase Auth
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour le profil utilisateur avec le nom
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);
        
        // Sauvegarder les informations utilisateur dans Firestore
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'name': name,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
          });
        } catch (firestoreError) {
          // Log l'erreur Firestore mais ne pas bloquer l'inscription
          debugPrint('Firestore error: $firestoreError');
        }
      }

      if (!mounted) return;

      // Navigation vers l'écran principal avec pushReplacement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      setState(() {
        _errorMessage = _getFirebaseErrorMessage(e.code);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Unexpected error during registration: $e');
      setState(() {
        _errorMessage = 'Erreur inconnue. Réessayez plus tard.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Calculer les dimensions responsives
    final contentWidth = screenWidth * 0.85; // 85% de la largeur d'écran
    final maxContentWidth = 400.0; // Largeur maximale pour les grands écrans
    final actualContentWidth = contentWidth > maxContentWidth ? maxContentWidth : contentWidth;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Stack(
        children: [
          // Contenu principal centré
          Positioned(
            top: screenHeight * 0.15, // Plus haut pour accommoder 3 champs
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: actualContentWidth,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Titre principal
                    const Text(
                      'Créer un compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF344356),
                        fontFamily: 'Quicksand',
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Sous-titre
                    const Text(
                      'Remplissez les informations pour créer votre compte',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF606D7C),
                        fontFamily: 'Quicksand',
                        height: 1.56,
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    
                    // Champ Nom
                    Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(60, 128, 209, 0.085),
                            blurRadius: 19,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF334355),
                          fontFamily: 'Quicksand',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Nom complet',
                          hintStyle: TextStyle(
                            color: const Color(0xFF344356).withAlpha((0.3 * 255).toInt()),
                            fontSize: 20,
                            fontFamily: 'Quicksand',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Champ Email
                    Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(60, 128, 209, 0.085),
                            blurRadius: 19,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF334355),
                          fontFamily: 'Quicksand',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Adresse email',
                          hintStyle: TextStyle(
                            color: const Color(0xFF344356).withAlpha((0.3 * 255).toInt()),
                            fontSize: 20,
                            fontFamily: 'Quicksand',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Champ Mot de passe
                    Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(60, 128, 209, 0.085),
                            blurRadius: 19,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF334355),
                          fontFamily: 'Quicksand',
                        ),
                        decoration: InputDecoration(
                          hintText: 'Mot de passe',
                          hintStyle: TextStyle(
                            color: const Color(0xFF344356).withAlpha((0.3 * 255).toInt()),
                            fontSize: 20,
                            fontFamily: 'Quicksand',
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Affichage du message d'erreur
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBC4749).withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFBC4749),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFBC4749),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  color: Color(0xFFBC4749),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 30),
                    
                    // Bouton S'INSCRIRE
                    GestureDetector(
                      onTap: _isLoading ? null : _handleRegister,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _isLoading 
                              ? const Color(0xFF6A994E).withValues(alpha: 0.7)
                              : const Color(0xFF6A994E),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(60, 128, 209, 0.085),
                              blurRadius: 19,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'S\'INSCRIRE',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Quicksand',
                                      ),
                                    ),
                            ),
                            if (!_isLoading)
                              Positioned(
                                right: 16,
                                top: 16,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Color(0xFF6A994E),
                                    size: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Lien vers la connexion
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          "Vous avez déjà un compte ? ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF344356),
                            fontFamily: 'Quicksand',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Connectez-vous",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6A994E),
                              fontFamily: 'Quicksand',
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Mascotte (oiseau) - positionnée en pourcentages pour tous les écrans
          Positioned(
            top: screenHeight * 0.275, // Ajusté pour les 3 champs
            right: screenWidth * 0.19,
            child: Image.asset(
              'assets/Images/Bouton/mascotte.png',
              width: 60,
              height: 60,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../home_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Créer l'utilisateur avec Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Mettre à jour le nom d'affichage
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      if (!context.mounted) return;

      // Navigation vers la page d'accueil après inscription réussie
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;

      String errorMessage = 'Une erreur est survenue';
      
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Le mot de passe est trop faible';
          break;
        case 'email-already-in-use':
          errorMessage = 'Un compte existe déjà avec cet email';
          break;
        case 'invalid-email':
          errorMessage = 'Email invalide';
          break;
        case 'operation-not-allowed':
          errorMessage = 'L\'inscription par email/mot de passe n\'est pas activée';
          break;
      }

      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      if (!context.mounted) return;
      
      setState(() {
        _errorMessage = 'Une erreur inattendue est survenue';
      });
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Stack(
        children: [
          // Mascotte flottante en haut à droite
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset(
                  'assets/Images/Bouton/bouton echap.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Contenu principal centré
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                ),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 60), // Espace pour la mascotte
                            
                            // Titre principal
                            const Text(
                              'Créer un compte',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF386641),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            
                            const Text(
                              'Rejoignez la communauté Birdify',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6A994E),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),

                            // Champ nom
                            TextFormField(
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              decoration: InputDecoration(
                                labelText: 'Nom complet',
                                hintText: 'Votre nom',
                                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF6A994E)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF386641), width: 3),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                labelStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  color: Color(0xFF6A994E),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre nom';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ email
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'votre@email.com',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6A994E)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF386641), width: 3),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                labelStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  color: Color(0xFF6A994E),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Veuillez entrer un email valide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ mot de passe
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Mot de passe',
                                hintText: 'Votre mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6A994E)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF6A994E),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF386641), width: 3),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                labelStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  color: Color(0xFF6A994E),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre mot de passe';
                                }
                                if (value.length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ confirmation mot de passe
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: InputDecoration(
                                labelText: 'Confirmer le mot de passe',
                                hintText: 'Confirmez votre mot de passe',
                                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF6A994E)),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF6A994E),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscureConfirmPassword = !_obscureConfirmPassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF6A994E), width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFF386641), width: 3),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                labelStyle: const TextStyle(
                                  fontFamily: 'Quicksand',
                                  color: Color(0xFF6A994E),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez confirmer votre mot de passe';
                                }
                                if (value != _passwordController.text) {
                                  return 'Les mots de passe ne correspondent pas';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Affichage du message d'erreur
                            if (_errorMessage != null)
                              Container(
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
                            const SizedBox(height: 32),

                            // Bouton CONTINUER avec flèche
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF386641), Color(0xFF6A994E)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF386641).withAlpha(50),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _isLoading ? null : _signUp,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (_isLoading)
                                          const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        else
                                          const Text(
                                            'CONTINUER',
                                            style: TextStyle(
                                              fontFamily: 'Quicksand',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        if (!_isLoading)
                                          const Icon(
                                            Icons.arrow_forward,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Lien vers la connexion
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      const begin = Offset(-1.0, 0.0);
                                      const end = Offset.zero;
                                      const curve = Curves.easeInOut;
                                      
                                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                      var offsetAnimation = animation.drive(tween);
                                      
                                      return SlideTransition(
                                        position: offsetAnimation,
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                          child: child,
                                        ),
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 300),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: const Text(
                                  'Vous avez déjà un compte ? Connectez-vous',
                                  style: TextStyle(
                                    fontFamily: 'Quicksand',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6A994E),
                                    decoration: TextDecoration.underline,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/Users/auth_service.dart';
import '../../services/Users/user_orchestra_service.dart';
import '../../services/Users/user_profile_service.dart';
import '../../pages/home_screen.dart';
import 'questionnaire_screen.dart';
import '../../services/Users/onboarding_service.dart';
import '../../ui/responsive/responsive.dart';

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
      final navigator = Navigator.of(context);
      // Créer l'utilisateur via AuthService
      final userCredential = await AuthService.signUpWithEmail(email, password);

      // Mettre à jour le profil utilisateur avec le nom
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);

        // Écrire la structure complète du profil et démarrer la synchronisation
        try {
          await UserProfileService.createOrUpdateUserProfile(
              uid: userCredential.user!.uid,
              displayName: name,
              email: email,
              photoURL: userCredential.user!.photoURL);
          await UserOrchestra.startRealtime();
        } catch (syncError) {
          debugPrint('Profil/sync error: $syncError');
        }
      }

      if (!mounted) return;

      // Vérifier si onboarding requis, sinon Home
      final needs = await QuestionnaireService.needsOnboarding();
      if (needs) {
        await navigator.push<bool>(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
      
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
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          final double contentTop = m.isTablet
              ? m.dp(70, tabletFactor: 1.0, min: 56, max: 120)
              : m.dp(70, min: 48, max: 110);
          final double rawContentWidth = constraints.maxWidth * 0.85;
          final double actualContentWidth = m.isTablet
              ? rawContentWidth.clamp(360.0, 520.0)
              : rawContentWidth.clamp(300.0, 400.0);
          final double fieldHeight = m.dp(70, tabletFactor: 1.05, min: 58, max: 84);
          return Stack(
            clipBehavior: Clip.none,
            children: [
          // Contenu principal centré
          Positioned(
            top: contentTop, // Responsive top
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: actualContentWidth,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
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
                    
                    // Champ Nom avec mascotte ancrée au carré
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          height: fieldHeight,
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
                        Positioned(
                          right: m.dp(20, min: 6, max: 20),
                          top: -(fieldHeight * 0.67),
                          child: Image.asset(
                            'assets/Images/Bouton/mascotte.png',
                            width: m.dp(60, tabletFactor: 1.2, min: 40, max: 64),
                            height: m.dp(60, tabletFactor: 1.2, min: 40, max: 64),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
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
                    
                    const SizedBox(height: 20),
                    
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
                    
                    const SizedBox(height: 20),
                    // Boutons sociaux (Google + Téléphone) entre Mot de passe et S'INSCRIRE
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google
                        ElevatedButton.icon(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            final cred = await AuthService.signInWithGoogle();
                            if (cred == null) return;
                            if (!mounted) return;
                            await UserOrchestra.startRealtime();
                            if (!mounted) return;
                            navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF334355),
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: SvgPicture.asset('assets/PAGE/Authentification/google icon.svg', width: 20, height: 20),
                          label: const Text('Google'),
                        ),
                        const SizedBox(width: 12),
                        // Téléphone
                        ElevatedButton.icon(
                          onPressed: () async {
                            final phone = await showDialog<String>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) {
                                final entries = const [
                                  ['🇫🇷', '+33'], ['🇧🇪', '+32'], ['🇨🇭', '+41'], ['🇪🇸', '+34'], ['🇮🇹', '+39'],
                                  ['🇵🇹', '+351'], ['🇳🇱', '+31'], ['🇱🇺', '+352'], ['🇮🇪', '+353'], ['🇩🇪', '+49'],
                                  ['🇬🇧', '+44'], ['🇺🇸', '+1'], ['🇨🇦', '+1'], ['🇲🇦', '+212'], ['🇩🇿', '+213'],
                                  ['🇹🇳', '+216'], ['🇳🇴', '+47'], ['🇸🇪', '+46'], ['🇫🇮', '+358'], ['🇩🇰', '+45'],
                                  ['🇵🇱', '+48'], ['🇨🇿', '+420'], ['🇸🇰', '+421'], ['🇷🇴', '+40'], ['🇭🇺', '+36'],
                                  ['🇬🇷', '+30'], ['🇹🇷', '+90']
                                ];
                                String selectedPrefix = '+33';
                                final localCtrl = TextEditingController();
                                return StatefulBuilder(
                                  builder: (ctx, setState) => AlertDialog(
                                    title: const Text('Numéro de téléphone'),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF3F7),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedPrefix,
                                                  menuMaxHeight: 320,
                                                  isDense: true,
                                                  items: entries.map((e) {
                                                    return DropdownMenuItem<String>(
                                                      value: e[1],
                                                      child: Row(children: [Text('${e[0]}  ${e[1]}')]),
                                                    );
                                                  }).toList(),
                                                  onChanged: (v) { if (v != null) setState(() => selectedPrefix = v); },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: localCtrl,
                                                keyboardType: TextInputType.phone,
                                                decoration: const InputDecoration(hintText: '6 12 34 56 78'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                                      ElevatedButton(
                                        onPressed: () {
                                          final local = localCtrl.text.replaceAll(' ', '').trim();
                                          Navigator.pop(ctx, '$selectedPrefix$local');
                                        },
                                        child: const Text('Continuer'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                            if (phone == null || phone.isEmpty) {
                              if (!mounted) return;
                              setState(() => _errorMessage = 'Entrez un numéro valide au format international (+33...)');
                              return;
                            }
                            await AuthService.verifyPhoneNumber(
                              phoneNumber: phone,
                              onCodeSent: (vId) async {
                                if (!mounted) return;
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                messenger.showSnackBar(const SnackBar(content: Text('SMS envoyé.')));
                                final code = await showDialog<String>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) {
                                    final ctrl = TextEditingController();
                                    return AlertDialog(
                                      title: const Text('Code SMS'),
                                      content: TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Code à 6 chiffres')),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                                        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Valider')),
                                      ],
                                    );
                                  },
                                );
                                if (code == null) return;
                                final cred = await AuthService.signInWithSmsCode(verificationId: vId, smsCode: code);
                                if (cred == null) return;
                                await UserOrchestra.startRealtime();
                                navigator.pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
                              },
                              onError: (msg) {
                                if (!mounted) return;
                                setState(() => _errorMessage = msg);
                                _isLoading = false;
                              },
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF334355),
                            elevation: 1,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          icon: const Icon(Icons.phone_iphone, size: 20),
                          label: const Text('Téléphone'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
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
              ],
            ),
              ),
            ),
          ),
          
          // (Supprimé) mascotte globale
        ],
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/Users/auth_service.dart';
// import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform; // Unused
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'register_screen.dart';
import '../../ui/responsive/responsive.dart';
import '../home_screen.dart';
import '../../services/Users/user_orchestra_service.dart';
import 'questionnaire_screen.dart';
import '../../services/Users/onboarding_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _errorMessage = null;
    });

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Veuillez remplir tous les champs';
      });
      return;
    }

    // Règles de robustesse: 8+ caractères, 1 majuscule, 1 chiffre
    final bool hasMinLength = password.length >= 8;
    final bool hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final bool hasDigit = RegExp(r'\d').hasMatch(password);
    if (!(hasMinLength && hasUpper && hasDigit)) {
      setState(() {
        _errorMessage = 'Le mot de passe doit avoir au moins 8 caractères, une majuscule et un chiffre.';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      
      // Démarrer la synchronisation via l'orchestrateur
      await UserOrchestra.startRealtime();

      if (!mounted) return;

      final needs = await QuestionnaireService.needsOnboarding();
      if (!mounted) return;
      if (needs) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          _errorMessage = 'Adresse email ou mot de passe incorrect';
          break;
        case 'invalid-email':
          _errorMessage = 'Adresse email invalide';
          break;
        default:
          _errorMessage = 'Une erreur s\'est produite';
      }
      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur inconnue. Réessayez plus tard.';
      });
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _errorMessage = null);
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) {
        setState(() => _errorMessage = 'Connexion Google annulée ou indisponible');
        return;
      }
      if (!mounted) return;
      await UserOrchestra.startRealtime();
      if (!mounted) return;
      final needs = await QuestionnaireService.needsOnboarding();
      if (!mounted) return;
      if (needs) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Google Sign-In a échoué: ${e.toString()}');
    }
  }

  // Facebook retiré du périmètre défini

  // Future<void> _handleApple() async { /* désactivé */ }

  // Future<void> _handleMagicLink() async { /* désactivé */ }

  // Gérer les liens magiques quand l’app est ouverte via un lien (deep link/Dynamic Links)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tentative simple: si un lien est reçu via initialLink dans ModalRoute
    final uri = ModalRoute.of(context)?.settings.name;
    if (uri != null && uri.contains('link=')) {
      // Extraire le lien profond s’il est encodé en param
      final link = Uri.decodeComponent(uri.split('link=').last);
      _completeMagicLinkIfNeeded(link);
    }
  }

  Future<void> _completeMagicLinkIfNeeded(String link) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return; // On exige l’email saisi pour finaliser
    final cred = await AuthService.completeEmailLinkSignIn(email: email, link: link);
    if (cred == null) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Lien invalide ou expiré');
      return;
    }
    if (!mounted) return;
    await UserOrchestra.startRealtime();
    if (!mounted) return;
    final needs = await QuestionnaireService.needsOnboarding();
    if (!mounted) return;
    if (needs) {
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<void> _handlePhone() async {
    setState(() => _errorMessage = null);
    final phone = await _askPhoneNumber();
    if (phone == null || phone.isEmpty) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Entrez un numéro valide au format international (+33...)');
      return;
    }
    await AuthService.verifyPhoneNumber(
      phoneNumber: phone,
      onCodeSent: (vId) async {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SMS envoyé.')));
        final code = await _askSmsCode();
        if (code == null) return;
        final cred = await AuthService.signInWithSmsCode(verificationId: vId, smsCode: code);
        if (cred == null) {
          if (!mounted) return;
          setState(() => _errorMessage = 'Code invalide');
          return;
        }
        if (!mounted) return;
        await UserOrchestra.startRealtime();
        if (!mounted) return;
        final needs = await QuestionnaireService.needsOnboarding();
        if (!mounted) return;
        if (needs) {
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
          );
        }
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _errorMessage = msg);
      },
    );
  }

  Future<void> _handleForgotPassword() async {
    setState(() => _errorMessage = null);
    String email = _emailController.text.trim();
    if (email.isEmpty) {
      final asked = await _askEmailForReset();
      if (asked == null || asked.trim().isEmpty) return; // pas de popup
      email = asked.trim();
    }
    final ok = await AuthService.sendPasswordResetEmail(email: email);
    if (!mounted) return;
    if (ok) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFF3F5F9),
          title: const Text(
            'Email envoyé',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.bold,
              color: Color(0xFF334355),
            ),
          ),
          content: const Text(
            'Vérifiez votre boîte de réception et le dossier spam.',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 16,
              color: Color(0xFF606D7C),
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE1E7EE),
                foregroundColor: const Color(0xFF334355),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDADADA), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFFF3F5F9),
          title: const Text(
            'Échec',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.bold,
              color: Color(0xFFBC4749),
            ),
          ),
          content: const Text(
            'Impossible d’envoyer l’email. Vérifiez l’adresse et réessayez.',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 16,
              color: Color(0xFF606D7C),
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE1E7EE),
                foregroundColor: const Color(0xFF334355),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFDADADA), width: 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<String?> _askEmailForReset() async {
    final ctrl = TextEditingController(text: _emailController.text.trim());
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF3F5F9),
        title: const Text(
          'Réinitialiser le mot de passe',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
            color: Color(0xFF334355),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nous allons vous envoyer un email pour réinitialiser votre mot de passe.',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontSize: 16,
                color: Color(0xFF606D7C),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Adresse email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF334355)),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE1E7EE),
              foregroundColor: const Color(0xFF334355),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFDADADA), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  Future<String?> _askPhoneNumber() async {
    final localCtrl = TextEditingController();
    final entries = const [
      ['🇫🇷', '+33'], ['🇧🇪', '+32'], ['🇨🇭', '+41'], ['🇪🇸', '+34'], ['🇮🇹', '+39'],
      ['🇵🇹', '+351'], ['🇳🇱', '+31'], ['🇱🇺', '+352'], ['🇮🇪', '+353'], ['🇩🇪', '+49'],
      ['🇬🇧', '+44'], ['🇺🇸', '+1'], ['🇨🇦', '+1'], ['🇲🇦', '+212'], ['🇩🇿', '+213'],
      ['🇹🇳', '+216'], ['🇳🇴', '+47'], ['🇸🇪', '+46'], ['🇫🇮', '+358'], ['🇩🇰', '+45'],
      ['🇵🇱', '+48'], ['🇨🇿', '+420'], ['🇸🇰', '+421'], ['🇷🇴', '+40'], ['🇭🇺', '+36'],
      ['🇬🇷', '+30'], ['🇹🇷', '+90']
    ];
    String selectedPrefix = '+33';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
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
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF334355)),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final local = localCtrl.text.replaceAll(' ', '').trim();
                Navigator.pop(ctx, '$selectedPrefix$local');
              },
              child: const Text('Continuer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askSmsCode() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Code SMS'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Entrez le code à 6 chiffres'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF334355)),
            child: const Text('Annuler'),
          ),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Valider')),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final m = buildResponsiveMetrics(context, constraints);
          final double contentTop = m.isTablet ? m.dp(80, tabletFactor: 1.0, min: 60, max: 140) : m.dp(80, min: 56, max: 120);
          final double fieldHeight = m.dp(70, tabletFactor: 1.05, min: 58, max: 84);
          final double rawContentWidth = constraints.maxWidth * 0.85;
          final double actualContentWidthLB = m.isTablet
              ? rawContentWidth.clamp(360.0, 520.0)
              : rawContentWidth.clamp(300.0, 400.0);
          return Stack(
            children: [
          // Contenu principal centré
          Positioned(
            top: contentTop,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: actualContentWidthLB,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Connexion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF344356),
                        fontFamily: 'Quicksand',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Connectez-vous avec votre compte',
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
                    const SizedBox(height: 20),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFF606D7C),
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBC4749).withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBC4749), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFBC4749), size: 20),
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
                    const SizedBox(height: 14),
                    // Séparateur "ou"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF344356).withAlpha((0.15 * 255).toInt()),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'ou',
                            style: const TextStyle(
                              fontFamily: 'Quicksand',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF606D7C),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFF344356).withAlpha((0.15 * 255).toInt()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Boutons sociaux (Google + Téléphone) avec icônes alignées
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _handleGoogle,
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
                        ElevatedButton.icon(
                          onPressed: _handlePhone,
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
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _handleLogin,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6A994E),
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
                            const Center(
                              child: Text(
                                'CONTINUER',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Quicksand',
                                ),
                              ),
                            ),
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
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'assets/Images/Bouton/bouton droite.svg',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  colorFilter: const ColorFilter.mode(Color(0xFF6A994E), BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          "Vous n'avez pas de compte ? ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF344356),
                            fontFamily: 'Quicksand',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  const begin = Offset(1.0, 0.0);
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
                          child: const Text(
                            "Créez-en un",
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

          // (Supprimé) mascotte globale
        ],
          );
        },
      ),
    );
  }
}

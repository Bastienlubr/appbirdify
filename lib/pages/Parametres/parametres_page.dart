import 'package:flutter/material.dart';
import '../../ui/responsive/responsive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/abonnement/premium_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/Users/user_orchestra_service.dart';
import '../../main.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  String _displayName = 'Utilisateur';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadInitialName();
  }

  Future<void> _loadInitialName() async {
    var user = FirebaseAuth.instance.currentUser;
    try {
      await user?.reload();
      user = FirebaseAuth.instance.currentUser; // rafraîchir l'instance
    } catch (_) {}
    String name = user?.displayName?.trim() ?? '';
    _email = user?.email ?? '';
    if (name.isEmpty && user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
        final data = doc.data();
        if (data != null) {
          final profil = data['profil'];
          if (profil is Map && profil['nomAffichage'] is String) {
            name = (profil['nomAffichage'] as String).trim();
          }
          if (profil is Map && profil['email'] is String && (profil['email'] as String).trim().isNotEmpty) {
            _email = (profil['email'] as String).trim();
          }
        }
      } catch (_) {}
    }
    if (name.isEmpty && user?.email != null) {
      name = user!.email!.split('@').first;
    }
    if (mounted) {
      setState(() {
        _displayName = name.isEmpty ? 'Utilisateur' : name;
        _email = _email.isEmpty ? (user?.email ?? '') : _email;
      });
    }
  }

  Future<void> _promptEditName(ResponsiveMetrics m) async {
    final TextEditingController controller = TextEditingController(text: _displayName);
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF3F5F9),
          title: const Text(
            'Modifier le nom',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.bold,
              color: Color(0xFF334355),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Votre nom'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.length < 2) return 'Entrez au moins 2 caractères';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
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
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    await _applyNewName(result);
    if (!mounted) return;
    setState(() => _displayName = result);
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Nom mis à jour: $result')));
  }

  Future<void> _applyNewName(String newName) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        try {
          await FirebaseFirestore.instance
              .collection('utilisateurs')
              .doc(user.uid)
              .set({'profil': {'nomAffichage': newName}}, SetOptions(merge: true));
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _promptEditEmail(ResponsiveMetrics m) async {
    final TextEditingController controller = TextEditingController(text: _email);
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF3F5F9),
          title: const Text(
            'Modifier l\'email',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.bold,
              color: Color(0xFF334355),
            ),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'nouveau@mail.com'),
              validator: (v) {
                final s = (v ?? '').trim();
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(s)) return 'Entrez un email valide';
                return null;
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
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
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final ok = await _applyNewEmail(result);
    if (!mounted) return;
    if (ok) {
      setState(() => _email = result);
      messenger.showSnackBar(const SnackBar(content: Text('Email mis à jour')));
    } else {
      // Tenter une réauthentification par mot de passe, puis réessayer
      final reauthOk = await _promptReauthAndRetryEmail(result);
      if (reauthOk) {
        if (!mounted) return;
        setState(() => _email = result);
        messenger.showSnackBar(const SnackBar(content: Text('Email mis à jour après réauthentification')));
      } else {
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Impossible de mettre à jour l\'email (réauthentification nécessaire)')));
      }
    }
  }

  Future<bool> _applyNewEmail(String newEmail) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      await user.verifyBeforeUpdateEmail(
        newEmail,
        ActionCodeSettings(
          url: 'https://appbirdify.page.link/update-email',
          handleCodeInApp: true,
          androidPackageName: 'com.mindbird.appbirdify',
          androidInstallApp: true,
          androidMinimumVersion: '21',
          iOSBundleId: 'com.mindbird.appbirdify',
        ),
      );
      // L’email sera mis à jour après vérification par l’utilisateur
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _promptReauthAndRetryEmail(String newEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (user.email == null || user.email!.isEmpty)) return false;
    // Si compte Google, proposer réauth Google
    final bool isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogle) {
      try {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(credential);
          await user.verifyBeforeUpdateEmail(
            newEmail,
            ActionCodeSettings(
              url: 'https://appbirdify.page.link/update-email',
              handleCodeInApp: true,
              androidPackageName: 'com.mindbird.appbirdify',
              androidInstallApp: true,
              androidMinimumVersion: '21',
              iOSBundleId: 'com.mindbird.appbirdify',
            ),
          );
          return true;
        }
      } catch (_) {
      }
    }

    if (!mounted) return false;
    final formKey = GlobalKey<FormState>();
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF3F5F9),
        title: const Text(
          'Réauthentification requise',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
            color: Color(0xFF334355),
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
            validator: (v) => (v == null || v.isEmpty) ? 'Entrez votre mot de passe' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
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
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: ctrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(
        newEmail,
        ActionCodeSettings(
          url: 'https://appbirdify.page.link/update-email',
          handleCodeInApp: true,
          androidPackageName: 'com.mindbird.appbirdify',
          androidInstallApp: true,
          androidMinimumVersion: '21',
          iOSBundleId: 'com.mindbird.appbirdify',
        ),
      );
      return true;
    } on FirebaseAuthException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _promptEditPassword(ResponsiveMetrics m) async {
    final formKey = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF3F5F9),
        title: const Text(
          'Changer le mot de passe',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.bold,
            color: Color(0xFF334355),
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe actuel'),
                validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
              ),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => (v == null || v.length < 6) ? '6 caractères min.' : null,
              ),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
                validator: (v) => (v != newCtrl.text) ? 'La confirmation ne correspond pas' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
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
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Utilisateur invalide')),
      );
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: currentCtrl.text);
      await user.reauthenticateWithCredential(cred);
      if (!mounted) return;
      await user.updatePassword(newCtrl.text);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Mot de passe mis à jour')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Erreur: ${e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Échec de la mise à jour')),
      );
    }
  }

  Future<void> _handleLogout() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Arrêter les services temps réel / premium
      try { UserOrchestra.stop(); } catch (_) {}

      // Déconnexion Google si nécessaire (meilleur nettoyage des sessions)
      try { await GoogleSignIn().signOut(); } catch (_) {}

      // Déconnexion Firebase
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      // Retour à l'écran racine (RootDecider gère la redirection Login)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RootDecider()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Échec de la déconnexion')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);
        const Color bg = Color(0xFFF2F5F8);
        const Color textColor = Color(0xFF334355);
        const Color iconBg = Color(0xFFD2DBB2);
        const Color iconColor = Colors.white;

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(m.spacing, m.dp(8), m.spacing, m.dp(4)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SvgBackButton(
                        onTap: () => Navigator.of(context).maybePop(),
                        size: m.dp(56),
                        iconSize: m.dp(30),
                        color: const Color(0xFF334355),
                      ),
                      SizedBox(
                        height: m.dp(56),
                        child: Center(
                          child: Text(
                            'Paramètres',
                            style: TextStyle(
                              fontFamily: 'Quicksand',
                              fontWeight: FontWeight.w900,
                              fontSize: m.font(24, min: 22, max: 30),
                              letterSpacing: 0.5,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: m.dp(56), height: m.dp(56)),
                    ],
                  ),
                ),

                SizedBox(height: m.dp(6)),

                // Content
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(m.spacing, m.dp(8), m.spacing, m.dp(20)),
                    children: [
                      _SectionTitle(title: 'Profil', m: m),
                      _CardContainer(
                        m: m,
                        child: Column(
                          children: [
                            _SettingsTile(
                              m: m,
                              leading: Icons.person,
                              title: 'Nom',
                              subtitle: _displayName,
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () => _promptEditName(m),
                            ),
                            _Divider(m: m),
                            _SettingsTile(
                              m: m,
                              leading: Icons.email_outlined,
                              title: 'Email',
                              subtitle: _email.isEmpty ? '—' : _email,
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () => _promptEditEmail(m),
                            ),
                            _Divider(m: m),
                            _SettingsTile(
                              m: m,
                              leading: Icons.lock_outline,
                              title: 'Mot de passe',
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () => _promptEditPassword(m),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: m.gapMedium()),
                      _SectionTitle(title: 'Abonnement', m: m),
                      _CardContainer(
                        m: m,
                        child: Column(
                          children: [
                            _SettingsTile(
                              m: m,
                              leading: Icons.restore,
                              title: 'Restaurer mes achats',
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () async {
                                try {
                                  await PremiumService.instance.restore();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Restauration lancée')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Restauration impossible: $e')),
                                    );
                                  }
                                }
                              },
                            ),
                            _Divider(m: m),
                            _SettingsTile(
                              m: m,
                              leading: Icons.sync,
                              title: "Actualiser l'état de l'abonnement",
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () async {
                                final ok = await PremiumService.instance.forceResync();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ok ? 'Statut actualisé' : 'Impossible d\'actualiser')),
                                  );
                                }
                              },
                            ),
                            _Divider(m: m),
                            ValueListenableBuilder<bool>(
                              valueListenable: PremiumService.instance.isPremium,
                              builder: (context, isPremium, _) {
                                if (!isPremium) {
                                  return const SizedBox.shrink();
                                }
                                return _SettingsTile(
                                  m: m,
                                  leading: Icons.workspace_premium,
                                  title: 'Gérer mon abonnement',
                                  iconBg: iconBg,
                                  iconColor: iconColor,
                                  onTap: () => Navigator.of(context).pushNamed('/abonnement/gerer'),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: m.gapMedium()),
                      _SectionTitle(title: "Aide & confidentialité", m: m),
                      _CardContainer(
                        m: m,
                        child: Column(
                          children: [
                            _SettingsTile(
                              m: m,
                              leading: Icons.help_outline,
                              title: "Centre d'aide",
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () {},
                            ),
                            _Divider(m: m),
                            _SettingsTile(
                              m: m,
                              leading: Icons.policy_outlined,
                              title: 'Confidentialité et Conditions',
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () {},
                            ),
                            _Divider(m: m),
                            _SettingsTile(
                              m: m,
                              leading: Icons.support_agent,
                              title: 'Contactez-nous',
                              iconBg: iconBg,
                              iconColor: iconColor,
                              onTap: () {},
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: m.gapLarge()),
                      Center(
                        child: InkWell(
                          onTap: _handleLogout,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: m.dp(8), horizontal: m.dp(12)),
                            child: const Text(
                              'Déconnexion',
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 1,
                                color: Color(0xFFBC4749),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SvgBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color color;
  const _SvgBackButton({required this.onTap, this.size = 44, this.iconSize = 22, this.color = const Color(0xFF334355)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all((size - iconSize) / 2),
            child: _ArrowSvg(size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}

class _ArrowSvg extends StatelessWidget {
  final double size;
  final Color color;
  const _ArrowSvg({required this.size, this.color = const Color(0xFF334355)});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/Images/Bouton/cross.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      placeholderBuilder: (_) => Icon(Icons.arrow_back, size: size, color: color),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ResponsiveMetrics m;
  const _SectionTitle({required this.title, required this.m});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: m.dp(4), bottom: m.dp(8)),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w700,
          fontSize: m.font(15, min: 14, max: 18),
          color: const Color(0xFF334355),
        ),
      ),
    );
  }
}

class _CardContainer extends StatelessWidget {
  final Widget child;
  final ResponsiveMetrics m;
  const _CardContainer({required this.child, required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12 * (m.isTablet ? 1.0 : 0.8),
            offset: Offset(0, 3 * (m.isTablet ? 1.0 : 0.8)),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Divider extends StatelessWidget {
  final ResponsiveMetrics m;
  const _Divider({required this.m});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: m.dp(16)),
      color: const Color(0x14334355),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final ResponsiveMetrics m;
  final IconData leading;
  final String title;
  final String? subtitle;
  final Color iconBg;
  final Color iconColor;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.m,
    required this.leading,
    required this.title,
    this.subtitle,
    required this.iconBg,
    required this.iconColor,
    required this.onTap,
  });

  String _svgForTitle() {
    final lower = title.toLowerCase();
    if (lower.contains('nom')) return 'assets/PAGE/Paramètre/Nom.svg';
    if (lower.contains('email')) return 'assets/PAGE/Paramètre/email.svg';
    if (lower.contains('mot de passe')) return 'assets/PAGE/Paramètre/motdepasse.svg';
    if (lower.contains('abonnement')) return 'assets/PAGE/Paramètre/abonnement.svg';
    if (lower.contains("centre d'aide") || lower.contains('aide')) return 'assets/PAGE/Paramètre/centre d\'aide.svg';
    if (lower.contains('confidentialité') || lower.contains('conditions')) return 'assets/PAGE/Paramètre/Confidentialité et conditions.svg';
    if (lower.contains('contact')) return 'assets/PAGE/Paramètre/contactez-nous.svg';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final String svg = _svgForTitle();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: m.dp(12), vertical: m.dp(12)),
          child: Row(
            children: [
              Container(
                width: m.dp(38),
                height: m.dp(38),
                decoration: const ShapeDecoration(
                  color: Color(0xFFD2DBB2),
                  shape: OvalBorder(),
                ),
                child: svg.isNotEmpty
                    ? Padding(
                        padding: EdgeInsets.all(m.dp(9)),
                        child: SvgPicture.asset(
                          svg,
                          width: m.dp(20),
                          height: m.dp(20),
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                        ),
                      )
                    : Icon(leading, size: m.dp(20), color: iconColor),
              ),
              SizedBox(width: m.dp(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w700,
                        fontSize: m.font(16, min: 15, max: 20),
                        color: const Color(0xFF334355),
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: m.dp(2)),
                      Opacity(
                        opacity: 0.6,
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'Quicksand',
                            fontWeight: FontWeight.w400,
                            fontSize: m.font(13, min: 12, max: 16),
                            color: const Color(0xFF334355),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Transform.translate(
                offset: Offset(-m.dp(6), 0),
                child: SvgPicture.asset(
                  'assets/Images/Bouton/bouton droite.svg',
                  width: m.dp(18),
                  height: m.dp(18),
                  fit: BoxFit.contain,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


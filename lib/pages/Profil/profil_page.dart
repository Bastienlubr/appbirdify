import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
// import 'package:image_cropper/image_cropper.dart';
import '../../services/Users/user_profile_service.dart';
import '../../ui/responsive/responsive.dart';
import '../../widgets/biome_carousel_enhanced.dart';

/// Page Profil (squelette UI basé sur Figma) — fonctionnalités à brancher ensuite.
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  bool _showAllBadges = false;
  bool _isUploadingAvatar = false;
  int _avatarVersion = 0; // pour forcer le rafraîchissement de l'image

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final m = buildResponsiveMetrics(context, constraints);

        final double sectionGap = m.gapLarge();
        final double titleSize = m.font(15);
        final double nameSize = m.font(30);
        final double cardHeight = m.dp(110, tabletFactor: 1.15, min: 96, max: 160);
        final double statNumberSize = m.font(20);
        final double statLabelSize = m.font(14);

        return Scaffold(
          backgroundColor: const Color(0xFFF2F5F8),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(m.spacing, m.gapLarge(), m.spacing, m.dp(48)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(nameSize, m),
                  SizedBox(height: sectionGap * 0.6),
                  // Nouveau tableau de bord conforme à la maquette fournie
                  const TableauDeBord(),
                  SizedBox(height: sectionGap * 0.8),
                  _buildBilanOrnithologique(titleSize, m),
                  const SizedBox(height: 0),
                  _buildBadges(titleSize, m),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double nameSize, ResponsiveMetrics m) {
    final double avatarOuter = m.isTablet ? m.dp(183, tabletFactor: 1.1, min: 160, max: 240) : 183;
    final double avatarInner = m.isTablet ? m.dp(158, tabletFactor: 1.1, min: 140, max: 210) : 158;
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: avatarOuter,
                height: avatarOuter,
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: const OvalBorder(),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x153C7FD0),
                      blurRadius: 19,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _onChangeAvatar,
                child: Container(
                  width: avatarInner,
                  height: avatarInner,
                  decoration: const ShapeDecoration(
                    color: Color(0xFFEBEBEB),
                    shape: OvalBorder(),
                  ),
                  child: FutureBuilder<String?>(
                    future: _fetchPhotoUrl(),
                    builder: (context, snapshot) {
                      final url = snapshot.data;
                      if (url != null && url.isNotEmpty) {
                        final bust = _avatarVersion;
                        final sep = url.contains('?') ? '&' : '?';
                        final bustedUrl = '$url${sep}v=$bust';
                        return ClipOval(
                          child: Image.network(
                            bustedUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 64, color: Color(0xFF9AA2A9)),
                          ),
                        );
                      }
                      return const Icon(Icons.person, size: 64, color: Color(0xFF9AA2A9));
                    },
                  ),
                ),
              ),
              if (_isUploadingAvatar)
                Positioned.fill(
                  child: ClipOval(
                    child: Container(
                      color: const Color(0x66000000),
                      child: const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: m.gapMedium()),
          FutureBuilder<String>(
            future: _fetchDisplayName(),
            builder: (context, snapshot) {
              final String displayName = snapshot.data?.trim().isNotEmpty == true
                  ? snapshot.data!.trim()
                  : 'Utilisateur';
              return Text(
                displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: nameSize,
                  height: 1.33,
                  color: const Color(0xFF334355),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<String> _fetchDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Invité';

    final String? authName = user.displayName;
    if (authName != null && authName.trim().isNotEmpty) {
      return authName.trim();
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final profil = data['profil'];
        if (profil is Map) {
          final nom = profil['nomAffichage'];
          if (nom is String && nom.trim().isNotEmpty) {
            return nom.trim();
          }
        }
      }
    } catch (_) {}

    final email = user.email;
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }
    return 'Utilisateur';
  }

  Future<String?> _fetchPhotoUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    // Priorité: photoURL Auth
    final authPhoto = user.photoURL;
    if (authPhoto != null && authPhoto.isNotEmpty) return authPhoto;

    // Fallback Firestore: utilisateurs/{uid}/profil.photoURL
    try {
      final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
      final data = doc.data();
      if (data != null) {
        final profil = data['profil'];
        if (profil is Map) {
          final p = profil['urlAvatar'];
          if (p is String && p.isNotEmpty) return p;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onChangeAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      
      // Recadrage simple intégré (dialog avec zoom/pan), sans plugin natif
      final Uint8List? croppedBytes = await _openAvatarCropper(context, picked.path);
      if (croppedBytes == null) return; // annulé
      String finalPath = picked.path;
      try {
        final temp = File(p.join(p.dirname(picked.path), '${p.basenameWithoutExtension(picked.path)}_cropped.png'));
        await temp.writeAsBytes(croppedBytes);
        finalPath = temp.path;
      } catch (_) {}
      if (mounted) setState(() => _isUploadingAvatar = true);
      final File file = File(finalPath);
      if (kDebugMode) {
        debugPrint('📸 Avatar sélectionné: path=${picked.path}');
        debugPrint('✂️  Utilisé: path=$finalPath size=${await file.length()} bytes');
      }
      // Nommer le fichier selon le nom d'utilisateur (sanitisé), avec fallback UID
      String displayName = user.displayName ?? '';
      if (displayName.trim().isEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
          displayName = (doc.data()?['profil']?['nomAffichage'] as String?) ?? '';
        } catch (_) {}
      }
      if (displayName.trim().isEmpty) {
        displayName = user.uid;
      }
      final String fileSafeName = _sanitizeFileName(displayName);

      // Écrase toujours un seul fichier PNG pour éviter d'accumuler des versions
      final String contentType = 'image/png';
      final storageRef = FirebaseStorage.instance.ref().child('avatars/${user.uid}/$fileSafeName.png');
      if (kDebugMode) {
        debugPrint('⬆️ Upload avatar -> bucket=${FirebaseStorage.instance.bucket} path=${storageRef.fullPath} contentType=$contentType');
      }
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: contentType),
      );
      final url = await storageRef.getDownloadURL();

      // Supprime d'anciennes variantes si elles existent
      try { await FirebaseStorage.instance.ref().child('avatars/${user.uid}/avatar.png').delete(); } catch (_) {}
      try { await FirebaseStorage.instance.ref().child('avatars/${user.uid}/avatar.jpg').delete(); } catch (_) {}
      try { await FirebaseStorage.instance.ref().child('avatars/${user.uid}/avatar.jpeg').delete(); } catch (_) {}
      // Supprimer l'ancien fichier pointé par urlAvatar si différent
      try {
        final prevDoc = await FirebaseFirestore.instance.collection('utilisateurs').doc(user.uid).get();
        final prevUrl = (prevDoc.data()?['profil']?['urlAvatar'] as String?) ?? '';
        if (prevUrl.isNotEmpty && prevUrl != url) {
          try { await FirebaseStorage.instance.refFromURL(prevUrl).delete(); } catch (_) {}
        }
      } catch (_) {}

      await UserProfileService.updateAvatarUrl(uid: user.uid, urlAvatar: url);
      // Optionnel: mettre à jour aussi le profil Auth
      await user.updatePhotoURL(url);

      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _avatarVersion++; // force le refresh visuel
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour')),
      );
    } on FirebaseException catch (e) {
      // On garde silencieux côté UI pour l’instant
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Échec de l'upload de l'avatar (${e.code}): ${e.message ?? e.toString()}")),
        );
      }
      if (kDebugMode) {
        debugPrint('❌ Upload avatar error: code=${e.code} message=${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Échec de l'upload de l'avatar: $e")),
        );
      }
    }
  }

  Future<Uint8List?> _openAvatarCropper(BuildContext context, String path) async {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _AvatarCropperDialog(imagePath: path);
      },
    );
  }

  Widget _buildDashboard(double titleSize, double cardHeight, double numberSize, double labelSize, ResponsiveMetrics m) {
    final Color borderColor = const Color(0xFF473C33);
    final Color chipColor = const Color(0xFFD2DBB2);
    final Radius r = Radius.circular(m.dp(12));

    Widget statChip({required String number, required String label, IconData? icon}) {
      return Container(
        height: 37,
        decoration: ShapeDecoration(
          color: chipColor,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 2, color: borderColor),
            borderRadius: BorderRadius.all(r),
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: m.dp(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: const Color(0xC4334355)),
              const SizedBox(width: 8),
            ],
            Text(
              number,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                fontSize: numberSize,
                color: const Color(0xC4334355),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w400,
                fontSize: labelSize,
                color: const Color(0xC4334355),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tableau de bord',
          style: TextStyle(
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w700,
            fontSize: titleSize,
            color: const Color(0xFF334355),
            height: 2.0,
          ),
        ),
        SizedBox(height: m.gapSmall()),
        Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.all(r),
            border: Border.all(width: 2, color: borderColor),
          ),
          padding: EdgeInsets.symmetric(horizontal: m.dp(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    statChip(number: '0', label: "Nombre d'épreuves", icon: Icons.assignment_turned_in),
                    SizedBox(height: m.gapSmall()),
                    statChip(number: '0', label: 'Jour d’activité', icon: Icons.local_fire_department),
                  ],
                ),
              ),
              VerticalDivider(width: m.dp(16), thickness: 1, color: const Color(0xBF473C33)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    statChip(number: '0', label: 'Sessions lancées', icon: Icons.play_circle),
                    SizedBox(height: m.gapSmall()),
                    statChip(number: '0', label: 'Niveaux débloqués', icon: Icons.landscape),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBilanOrnithologique(double titleSize, ResponsiveMetrics m) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 0),
          child: Text(
            'Bilan ornithologique',
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w700,
              fontSize: titleSize,
              color: const Color(0xFF334355),
              height: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: m.dp(210, tabletFactor: 1.0, min: 190, max: 280),
          child: Stack(
            children: [
              BiomeCarouselEnhanced(
                loopInfinite: true,
                showDots: false,
                viewportFraction: 0.5,
                onBiomeSelected: (biome) {
                  _showBiomePopup(biome.name);
                },
              ),
              // Fade gauche
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: m.dp(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFFF2F5F8),
                          const Color(0xFFF2F5F8).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Fade droit
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    width: m.dp(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          const Color(0xFFF2F5F8),
                          const Color(0xFFF2F5F8).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _assetForBiome(String biome) {
    switch (biome.toLowerCase()) {
      case 'urbain':
        return 'assets/Images/Milieu/Milieu_urbain.png';
      case 'forestier':
        return 'assets/Images/Milieu/Milieu_forestier.png';
      case 'agricole':
        return 'assets/Images/Milieu/Milieu_agricole.png';
      case 'humide':
        return 'assets/Images/Milieu/Milieu_humide.png';
      case 'montagnard':
        return 'assets/Images/Milieu/Milieu_montagnard.png';
      case 'littoral':
        return 'assets/Images/Milieu/Milieu_littoral.png';
      default:
        return 'assets/Images/Milieu/Milieu_urbain.png';
    }
  }

  void _showBiomePopup(String biome) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Bilan — $biome', style: const TextStyle(fontFamily: 'Quicksand', fontWeight: FontWeight.w800)),
          content: const Text(
            'Popup placeholder: nom de session, espèces les plus jouées/moins appréciées, etc.',
            style: TextStyle(fontFamily: 'Quicksand'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBadges(double titleSize, ResponsiveMetrics m) {
    final List<Widget> mainBadges = [
      _BadgeCircle(label: 'Débutant'),
      _BadgeCircle(label: 'Explorateur'),
      _BadgeCircle(label: 'Virtuose'),
    ];

    final List<Widget> allBadges = List.generate(18, (i) => _BadgeCircle(label: 'Badge ${i + 1}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Badges',
              style: TextStyle(
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                fontSize: titleSize,
                color: const Color(0xFF334355),
                height: 1.2,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _showAllBadges = !_showAllBadges),
              child: Text(_showAllBadges ? 'Afficher moins' : 'Afficher plus'),
            ),
          ],
        ),
        const SizedBox(height: 0),
        SizedBox(
          height: m.dp(140, tabletFactor: 1.1, min: 120, max: 200),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => mainBadges[index],
            separatorBuilder: (_, __) => SizedBox(width: m.dp(12)),
            itemCount: mainBadges.length,
          ),
        ),
        if (!_showAllBadges) SizedBox(height: m.dp(12)),
        if (_showAllBadges) ...[
          SizedBox(height: m.gapMedium()),
          Wrap(
            spacing: m.dp(12),
            runSpacing: m.dp(12),
            children: allBadges,
          ),
        ],
      ],
    );
  }
}

class _BiomeCard extends StatelessWidget {
  final String title;
  final String assetPath;
  final double height;
  final VoidCallback onTap;

  const _BiomeCard({required this.title, required this.assetPath, required this.height, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: height,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(width: 3, color: const Color(0xFF473C33)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _BadgeCircle extends StatelessWidget {
  final String label;
  const _BadgeCircle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 101,
          height: 101,
          decoration: const ShapeDecoration(
            color: Color(0xFFEBEBEB),
            shape: OvalBorder(),
            shadows: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.emoji_events, color: Color(0xFF6A994E), size: 40),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w600,
              color: Color(0xFF334355),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tableau de bord fidèle au layout communiqué (positions absolues, tailles fixes)
class TableauDeBord extends StatelessWidget {
  const TableauDeBord({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double chipHeight = 56;
        const double columnGap = 4;
        const double innerGap = 10;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Tableau de bord',
                style: TextStyle(
                  color: Color(0xFF334355),
                  fontSize: 17,
                  fontFamily: 'Quicksand',
                  fontWeight: FontWeight.w700,
                  height: 2.0,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatChipAsset(
                        height: chipHeight,
                        assetPath: 'assets/PAGE/Profil/nombres de sessions.png',
                        numberText: '0',
                        label: "Nombre d'épreuves",
                      ),
                      const SizedBox(height: innerGap),
                      _StatChipAsset(
                        height: chipHeight,
                        assetPath: 'assets/Images/Bouton/strick.png',
                        numberText: '0',
                        label: "Meilleure série d'activités",
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: columnGap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatChipAsset(
                        height: chipHeight,
                        assetPath: 'assets/PAGE/Profil/Famille favorite.png',
                        numberText: null,
                        label: 'Famille favorite',
                        secondary: 'Corvidés',
                      ),
                      const SizedBox(height: innerGap),
                      _StatChipAsset(
                        height: chipHeight,
                        assetPath: 'assets/PAGE/Profil/biome favoris.png',
                        numberText: null,
                        label: 'Habitat favori',
                        secondary: 'Milieu Urbain',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatChipAsset extends StatelessWidget {
  final double height;
  final String assetPath;
  final String? numberText;
  final String label;
  final String? secondary;

  const _StatChipAsset({
    required this.height,
    required this.assetPath,
    required this.label,
    this.numberText,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: ShapeDecoration(
        color: const Color(0xFFD2DBB2),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 3, color: Color(0xFF473C33)),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: (height - 14),
            height: (height - 14),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 1),
          if (numberText != null) ...[
            Text(
              numberText!,
              style: const TextStyle(
                color: Color(0xC4334355),
                fontSize: 22,
                fontFamily: 'Quicksand',
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: secondary != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xC4334355),
                          fontSize: 14,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        secondary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xC4334355),
                          fontSize: 14,
                          fontFamily: 'Quicksand',
                          fontWeight: FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                    ],
                  )
                : Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xC4334355),
                      fontSize: 14,
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


class _AvatarCropperDialog extends StatefulWidget {
  final String imagePath;
  const _AvatarCropperDialog({required this.imagePath});

  @override
  State<_AvatarCropperDialog> createState() => _AvatarCropperDialogState();
}

class _AvatarCropperDialogState extends State<_AvatarCropperDialog> {
  final ValueNotifier<Rect> _cropRect = ValueNotifier<Rect>(const Rect.fromLTWH(0, 0, 1, 1));
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _scaleInitialized = false;
  double _minScale = 1.0;
  final double _maxScale = 4.0;
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _lastFocal = Offset.zero;
  final GlobalKey _rbKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recadrer'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<ui.Image>(
            future: _loadUiImage(widget.imagePath),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final img = snap.data!;
              if (!_scaleInitialized) {
                const double view = 300.0;
                final double fitWidth = view / img.width;
                final double fitHeight = view / img.height;
                _minScale = math.min(fitWidth, fitHeight);
                _scale = _minScale;
                _offset = Offset.zero;
                _scaleInitialized = true;
              }
              return GestureDetector(
                onScaleStart: (d) {
                  _baseScale = _scale;
                  _baseOffset = _offset;
                  _lastFocal = d.focalPoint;
                },
                onScaleUpdate: (d) {
                  const double view = 300.0;
                  final newScale = (_baseScale * d.scale).clamp(_minScale, _maxScale);
                  final deltaFocal = d.focalPoint - _lastFocal;
                  _lastFocal = d.focalPoint;
                  Offset candidate = _baseOffset + deltaFocal / newScale;
                  candidate = _clampOffset(img, const Size(view, view), newScale, candidate);
                  setState(() {
                    _scale = newScale;
                    _offset = candidate;
                  });
                },
                child: RepaintBoundary(
                  key: _rbKey,
                  child: CustomPaint(
                    painter: _CropPainter(img: img, scale: _scale, offset: _offset),
                    size: const Size(300, 300),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Annuler')),
        ElevatedButton(onPressed: _exportCropped, child: const Text('Valider')),
      ],
    );
  }

  Future<void> _exportCropped() async {
    final RenderRepaintBoundary boundary = _rbKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    if (!mounted) return;
    Navigator.pop(context, bytes);
  }

  Future<ui.Image> _loadUiImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image img;
  final double scale;
  final Offset offset;
  _CropPainter({required this.img, required this.scale, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      (img.width / 2 - (size.width / 2) / scale) - offset.dx,
      (img.height / 2 - (size.height / 2) / scale) - offset.dy,
      size.width / scale,
      size.height / scale,
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint();
    canvas.drawImageRect(img, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.scale != scale || oldDelegate.offset != offset || oldDelegate.img != img;
  }
}

Offset _clampOffset(ui.Image img, Size view, double scale, Offset offset) {
  // Empêche de sortir des bords: garde au moins un recouvrement total
  final double halfW = (view.width / 2) / scale;
  final double halfH = (view.height / 2) / scale;
  final double minX = -(img.width / 2 - halfW);
  final double maxX = (img.width / 2 - halfW);
  final double minY = -(img.height / 2 - halfH);
  final double maxY = (img.height / 2 - halfH);
  double x = offset.dx.clamp(minX, maxX);
  double y = offset.dy.clamp(minY, maxY);
  return Offset(x, y);
}

String _sanitizeFileName(String name) {
  // Remplace caractères non autorisés par '_', limite la longueur
  final sanitized = name
      .replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return sanitized.isEmpty ? 'avatar' : sanitized.substring(0, sanitized.length.clamp(1, 40));
}


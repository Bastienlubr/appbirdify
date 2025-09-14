import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Service chargé de suivre et précharger la photo de profil utilisateur.
class UserAvatarService {
  UserAvatarService._internal();
  static final UserAvatarService instance = UserAvatarService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final ValueNotifier<String?> avatarUrl = ValueNotifier<String?>(null);

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await stop();
    // Première valeur depuis Auth (prioritaire)
    final authPhoto = user.photoURL;
    if (authPhoto != null && authPhoto.isNotEmpty) {
      _setAndPrefetch(authPhoto);
    }
    // Écoute Firestore pour urlAvatar
    _profileSub = _db.collection('utilisateurs').doc(user.uid).snapshots().listen((doc) {
      final String? fsUrl = (doc.data()?['profil']?['urlAvatar'] as String?)?.trim();
      final String? best = (fsUrl != null && fsUrl.isNotEmpty) ? fsUrl : (authPhoto ?? '');
      if (best != null && best.isNotEmpty) {
        _setAndPrefetch(best);
      }
    });
  }

  Future<void> stop() async {
    await _profileSub?.cancel();
    _profileSub = null;
  }

  void _setAndPrefetch(String url) {
    if (avatarUrl.value == url) return;
    avatarUrl.value = url;
    // Préchargement mémoire + disque avec limites (préserve data/stockage)
    // memCache ~256-384px; disque ~512-768px
    try {
      final provider = CachedNetworkImageProvider(
        url,
        maxHeight: 768,
        maxWidth: 768,
      );
      // Le precache nécessite un BuildContext; fallback via imageConfiguration par défaut
      // Ici on déclenche au moins la récupération/caching disque
      provider.resolve(const ImageConfiguration());
    } catch (_) {}
  }
}



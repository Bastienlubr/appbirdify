import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/bird_detail_data.dart';
import '../services/mission_preloader.dart';

/// Repository des fiches oiseaux.
/// Par défaut lit Firestore (miroir OFB). Fallback: données locales depuis MissionPreloader.
class BirdDetailRepository {
  final FirebaseFirestore _firestore;
  BirdDetailRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Chemin Firestore prévu: `ofb_oiseaux/{birdId}`
  Future<BirdDetailData?> fetchById(String birdId) async {
    try {
      final doc = await _firestore.collection('ofb_oiseaux').doc(birdId).get();
      if (doc.exists && doc.data() != null) {
        return BirdDetailData.fromMap(doc.id, doc.data()!);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Firestore OFB fetch error: $e');
    }

    // Fallback local minimal
    try {
      final b = MissionPreloader.getBirdData(birdId) ?? MissionPreloader.findBirdByName(birdId);
      if (b != null) {
        return BirdDetailData(
          birdId: b.id,
          commonName: b.nomFr,
          scientificName: '${b.genus} ${b.species}'.trim(),
          family: '',
          imageUrl: b.urlImage,
          identification: '',
          habitat: '',
          alimentation: '',
          reproduction: '',
          repartition: '',
        );
      }
    } catch (_) {}

    return null;
  }
}



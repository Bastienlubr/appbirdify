import 'package:flutter/foundation.dart';

/// Données enrichies pour l'affichage de la fiche espèce.
/// Source prévue: OFB (miroir Firestore ou API live), avec fallback local.
class BirdDetailData {
  final String birdId;
  final String commonName; // Nom français
  final String scientificName; // ex: Coracias garrulus
  final String family; // ex: Coraciidés (si connu)
  final String imageUrl; // Image de couverture

  // Sections de contenu
  final String identification;
  final String habitat;
  final String alimentation;
  final String reproduction;
  final String repartition;

  const BirdDetailData({
    required this.birdId,
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.imageUrl,
    required this.identification,
    required this.habitat,
    required this.alimentation,
    required this.reproduction,
    required this.repartition,
  });

  factory BirdDetailData.fromMap(String id, Map<String, dynamic> data) {
    String readString(String key, {String defaultValue = ''}) {
      final v = data[key];
      if (v is String) return v;
      return defaultValue;
    }

    return BirdDetailData(
      birdId: id,
      commonName: readString('commonName'),
      scientificName: readString('scientificName'),
      family: readString('family'),
      imageUrl: readString('imageUrl'),
      identification: readString('identification'),
      habitat: readString('habitat'),
      alimentation: readString('alimentation'),
      reproduction: readString('reproduction'),
      repartition: readString('repartition'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commonName': commonName,
      'scientificName': scientificName,
      'family': family,
      'imageUrl': imageUrl,
      'identification': identification,
      'habitat': habitat,
      'alimentation': alimentation,
      'reproduction': reproduction,
      'repartition': repartition,
    };
  }

  @override
  String toString() =>
      'BirdDetailData($birdId, $commonName, $scientificName, $family)';
}



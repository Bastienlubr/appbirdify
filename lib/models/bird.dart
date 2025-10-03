import 'package:flutter/foundation.dart';

class Bird {
  final String id;
  final String genus;
  final String species;
  final String nomFr;
  final String urlMp3;
  final String urlImage;
  final Set<String> milieux;

  // Constructeur complet
  Bird({
    required this.id,
    required this.genus,
    required this.species,
    required this.nomFr,
    required this.urlMp3,
    required this.urlImage,
    required this.milieux,
  });

  // Méthode fromJson pour créer un objet Bird à partir d'un Map
  factory Bird.fromJson(Map<String, dynamic> json) {
    return Bird(
      id: json['id'] as String,
      genus: json['genus'] as String,
      species: json['species'] as String,
      nomFr: json['nomFr'] as String,
      urlMp3: json['urlMp3'] as String,
      urlImage: json['urlImage'] as String,
      milieux: Set<String>.from(json['milieux'] as List),
    );
  }

  // Méthode toJson pour convertir l'objet Bird en Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'genus': genus,
      'species': species,
      'nomFr': nomFr,
      'urlMp3': urlMp3,
      'urlImage': urlImage,
      'milieux': milieux.toList(),
    };
  }

  // Méthode fromCsvRow pour créer un objet Bird à partir d'une ligne CSV
  factory Bird.fromCsvRow(Map<String, String> csvRow) {
    // Extraire le genre et l'espèce du nom scientifique
    final scientificName = csvRow['Nom_scientifique'] ?? '';
    final parts = scientificName.split(' ');
    final genus = parts.isNotEmpty ? parts[0] : '';
    final species = parts.length > 1 ? parts[1] : '';

    // Créer un ID unique basé sur le nom scientifique
    final id = scientificName.replaceAll(' ', '_').toLowerCase();

    // Extraire et normaliser les milieux
    final milieux = <String>{};
    String normalizeBiome(String raw) {
      final n = (raw).toLowerCase().trim();
      if (n.isEmpty) return '';
      if (n.contains('urbain')) return 'urbain';
      if (n.contains('forest')) return 'forestier';
      if (n.contains('agric')) return 'agricole';
      if (n.contains('mont')) return 'montagnard';
      if (n.contains('littoral') || n.contains('cote') || n.contains('côte')) return 'littoral';
      if (n.contains('humide') || n.contains('marais') || n.contains("plan d'eau") || n.contains('eau')) return 'humide';
      return n; // fallback brut si inconnu
    }

    // Nouvelles colonnes Birdify
    final habitatPrincipal = csvRow['Habitat_principal'] ?? '';
    final habitatSecondaire = csvRow['Habitat_secondaire'] ?? '';
    final p = normalizeBiome(habitatPrincipal.replaceAll('Milieu', ''));
    final s = normalizeBiome(habitatSecondaire.replaceAll('Milieu', ''));
    if (p.isNotEmpty) milieux.add(p);
    if (s.isNotEmpty) milieux.add(s);

    // Fallback anciennes colonnes éventuelles
    final legacy = <String, String>{
      'Plaine': 'agricole',
      'Forêt': 'forestier',
      'Montagne': 'montagnard',
      'Marais': 'humide',
      "Plan d'eau": 'humide',
      'Littoral': 'littoral',
      'Urbain': 'urbain',
    };
    for (final entry in legacy.entries) {
      if ((csvRow[entry.key] ?? '').toString().trim().isNotEmpty) {
        milieux.add(entry.value);
      }
    }

    // Sanitize URLs for web (encode apostrophes that break browser fetch/image)
    String sanitizedImageUrl = csvRow['photo'] ?? '';
    String sanitizedAudioUrl = csvRow['LienURL'] ?? '';
    // Conserver le domaine du bucket tel que fourni (ex: .firebasestorage.app)
    if (kIsWeb) {
      String normalizeGsUrl(String input) {
        try {
          if (!input.startsWith('https://firebasestorage.googleapis.com/')) return input;
          final uri = Uri.parse(input);
          final qp = Map<String, String>.from(uri.queryParameters);
          // Conserver le token: requis en cas d'objet privé/App Check
          if (!qp.containsKey('alt')) {
            qp['alt'] = 'media';
          }
          // Remap bucket si ancien appspot.com
          final List<String> seg = List<String>.from(uri.pathSegments);
          final int bIdx = seg.indexOf('b');
          if (bIdx >= 0 && bIdx + 1 < seg.length) {
            final String bucket = seg[bIdx + 1];
            if (bucket.endsWith('.appspot.com')) {
              seg[bIdx + 1] = bucket.replaceAll('.appspot.com', '.firebasestorage.app');
            }
          }
          final normalized = Uri(
            scheme: uri.scheme,
            host: uri.host,
            pathSegments: seg,
            queryParameters: qp.isEmpty ? null : qp,
          );
          return normalized.toString().replaceAll("'", '%27');
        } catch (_) {
          return input.replaceAll("'", '%27');
        }
      }

      if (sanitizedImageUrl.isNotEmpty) {
        sanitizedImageUrl = normalizeGsUrl(sanitizedImageUrl);
      }
      if (sanitizedAudioUrl.isNotEmpty) {
        sanitizedAudioUrl = normalizeGsUrl(sanitizedAudioUrl);
      }
    }

    return Bird(
      id: id,
      genus: genus,
      species: species,
      nomFr: csvRow['Nom_français'] ?? '',
      urlMp3: sanitizedAudioUrl,
      urlImage: sanitizedImageUrl,
      milieux: milieux,
    );
  }

  // Méthode toString pour le débogage
  @override
  String toString() {
    return 'Bird(id: $id, genus: $genus, species: $species, nomFr: $nomFr, urlMp3: $urlMp3, urlImage: $urlImage, milieux: $milieux)';
  }

  // Méthode equals pour comparer deux objets Bird
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Bird &&
        other.id == id &&
        other.genus == genus &&
        other.species == species &&
        other.nomFr == nomFr &&
        other.urlMp3 == urlMp3 &&
        other.urlImage == urlImage &&
        other.milieux == milieux;
  }

  // Méthode hashCode pour la cohérence avec equals
  @override
  int get hashCode {
    return Object.hash(id, genus, species, nomFr, urlMp3, urlImage, milieux);
  }
} 
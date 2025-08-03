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

    // Extraire les milieux
    final milieux = <String>{};
    // TODO: Mettre à jour avec les vrais milieux basés sur les fichiers CSV
    final milieuColumns = ['Plaine', 'Forêt', 'Montagne', 'Marais', 'Plan d\'eau', 'Littoral'];
    for (final milieu in milieuColumns) {
      if (csvRow[milieu]?.isNotEmpty == true) {
        milieux.add(milieu.toLowerCase());
      }
    }

    return Bird(
      id: id,
      genus: genus,
      species: species,
      nomFr: csvRow['Nom_français'] ?? '',
      urlMp3: csvRow['LienURL'] ?? '',
      urlImage: csvRow['photo'] ?? '',
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
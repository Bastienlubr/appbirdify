import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle complet pour une fiche oiseau
class FicheOiseau {
  final String idOiseau;
  final String nomFrancais;
  final String? nomAnglais;
  final String nomScientifique;
  final String famille;
  final String ordre;
  final Taille taille;
  final Poids poids;
  final String? longevite;
  final Identification identification;
  final Habitat habitat;
  final Alimentation alimentation;
  final Reproduction reproduction;
  final Repartition repartition;
  final ProtectionEtatActuel? protectionEtatActuel;
  final Vocalisations vocalisations;
  final Comportement comportement;
  final Conservation conservation;
  final Medias medias;
  final Sources sources;
  final Metadata metadata;

  FicheOiseau({
    required this.idOiseau,
    required this.nomFrancais,
    this.nomAnglais,
    required this.nomScientifique,
    required this.famille,
    required this.ordre,
    required this.taille,
    required this.poids,
    this.longevite,
    required this.identification,
    required this.habitat,
    required this.alimentation,
    required this.reproduction,
    required this.repartition,
    this.protectionEtatActuel,
    required this.vocalisations,
    required this.comportement,
    required this.conservation,
    required this.medias,
    required this.sources,
    required this.metadata,
  });

  /// Crée depuis Firestore
  factory FicheOiseau.fromFirestore(Map<String, dynamic> data) {
    return FicheOiseau(
      idOiseau: data['idOiseau'] as String? ?? '',
      nomFrancais: data['nomFrancais'] as String? ?? '',
      nomAnglais: data['nomAnglais'] as String?,
      nomScientifique: data['nomScientifique'] as String? ?? '',
      famille: data['famille'] as String? ?? '',
      ordre: data['ordre'] as String? ?? '',
      taille: Taille.fromFirestore(data['taille'] as Map<String, dynamic>? ?? {}),
      poids: Poids.fromFirestore(data['poids'] as Map<String, dynamic>? ?? {}),
      longevite: data['longevite'] as String?,
      identification: Identification.fromFirestore(data['identification'] as Map<String, dynamic>? ?? {}),
      habitat: Habitat.fromFirestore(data['habitat'] as Map<String, dynamic>? ?? {}),
      alimentation: Alimentation.fromFirestore(data['alimentation'] as Map<String, dynamic>? ?? {}),
      reproduction: Reproduction.fromFirestore(data['reproduction'] as Map<String, dynamic>? ?? {}),
      repartition: Repartition.fromFirestore(data['repartition'] as Map<String, dynamic>? ?? {}),
      protectionEtatActuel: (data['protectionEtatActuel'] is Map<String, dynamic>)
          ? ProtectionEtatActuel.fromFirestore(data['protectionEtatActuel'] as Map<String, dynamic>)
          : null,
      vocalisations: Vocalisations.fromFirestore(data['vocalisations'] as Map<String, dynamic>? ?? {}),
      comportement: Comportement.fromFirestore(data['comportement'] as Map<String, dynamic>? ?? {}),
      conservation: Conservation.fromFirestore(data['conservation'] as Map<String, dynamic>? ?? {}),
      medias: Medias.fromFirestore(data['medias'] as Map<String, dynamic>? ?? {}),
      sources: Sources.fromFirestore(data['sources'] as Map<String, dynamic>? ?? {}),
      metadata: Metadata.fromFirestore(data['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// Convertit vers Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'idOiseau': idOiseau,
      'nomFrancais': nomFrancais,
      'nomAnglais': nomAnglais,
      'nomScientifique': nomScientifique,
      'famille': famille,
      'ordre': ordre,
      'taille': taille.toFirestore(),
      'poids': poids.toFirestore(),
      'longevite': longevite,
      'identification': identification.toFirestore(),
      'habitat': habitat.toFirestore(),
      'alimentation': alimentation.toFirestore(),
      'reproduction': reproduction.toFirestore(),
      'repartition': repartition.toFirestore(),
      if (protectionEtatActuel != null) 'protectionEtatActuel': protectionEtatActuel!.toFirestore(),
      'vocalisations': vocalisations.toFirestore(),
      'comportement': comportement.toFirestore(),
      'conservation': conservation.toFirestore(),
      'medias': medias.toFirestore(),
      'sources': sources.toFirestore(),
      'metadata': metadata.toFirestore(),
    };
  }

  /// Crée depuis JSON
  factory FicheOiseau.fromJson(Map<String, dynamic> json) {
    return FicheOiseau(
      idOiseau: json['idOiseau'] as String? ?? '',
      nomFrancais: json['nomFrancais'] as String? ?? '',
      nomAnglais: json['nomAnglais'] as String?,
      nomScientifique: json['nomScientifique'] as String? ?? '',
      famille: json['famille'] as String? ?? '',
      ordre: json['ordre'] as String? ?? '',
      taille: Taille.fromJson(json['taille'] as Map<String, dynamic>? ?? {}),
      poids: Poids.fromJson(json['poids'] as Map<String, dynamic>? ?? {}),
      longevite: json['longevite'] as String?,
      identification: Identification.fromJson(json['identification'] as Map<String, dynamic>? ?? {}),
      habitat: Habitat.fromJson(json['habitat'] as Map<String, dynamic>? ?? {}),
      alimentation: Alimentation.fromJson(json['alimentation'] as Map<String, dynamic>? ?? {}),
      reproduction: Reproduction.fromJson(json['reproduction'] as Map<String, dynamic>? ?? {}),
      repartition: Repartition.fromJson(json['repartition'] as Map<String, dynamic>? ?? {}),
      protectionEtatActuel: (json['protectionEtatActuel'] is Map<String, dynamic>)
          ? ProtectionEtatActuel.fromJson(json['protectionEtatActuel'] as Map<String, dynamic>)
          : null,
      vocalisations: Vocalisations.fromJson(json['vocalisations'] as Map<String, dynamic>? ?? {}),
      comportement: Comportement.fromJson(json['comportement'] as Map<String, dynamic>? ?? {}),
      conservation: Conservation.fromJson(json['conservation'] as Map<String, dynamic>? ?? {}),
      medias: Medias.fromJson(json['medias'] as Map<String, dynamic>? ?? {}),
      sources: Sources.fromJson(json['sources'] as Map<String, dynamic>? ?? {}),
      metadata: Metadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// Convertit vers JSON
  Map<String, dynamic> toJson() {
    return {
      'idOiseau': idOiseau,
      'nomFrancais': nomFrancais,
      'nomAnglais': nomAnglais,
      'nomScientifique': nomScientifique,
      'famille': famille,
      'ordre': ordre,
      'taille': taille.toJson(),
      'poids': poids.toJson(),
      'longevite': longevite,
      'identification': identification.toJson(),
      'habitat': habitat.toJson(),
      'alimentation': alimentation.toJson(),
      'reproduction': reproduction.toJson(),
      'repartition': repartition.toJson(),
      if (protectionEtatActuel != null) 'protectionEtatActuel': protectionEtatActuel!.toJson(),
      'vocalisations': vocalisations.toJson(),
      'comportement': comportement.toJson(),
      'conservation': conservation.toJson(),
      'medias': medias.toJson(),
      'sources': sources.toJson(),
      'metadata': metadata.toJson(),
    };
  }
}

/// Classe pour la taille de l'oiseau
class Taille {
  final String? longueur;
  final String? envergure;
  final String? description;

  Taille({
    this.longueur,
    this.envergure,
    this.description,
  });

  factory Taille.fromFirestore(Map<String, dynamic> data) {
    return Taille(
      longueur: _convertToString(data['longueur']),
      envergure: _convertToString(data['envergure']),
      description: _convertToString(data['description']),
    );
  }

  factory Taille.fromJson(Map<String, dynamic> json) {
    return Taille(
      longueur: _convertToString(json['longueur']),
      envergure: _convertToString(json['envergure']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'longueur': longueur,
      'envergure': envergure,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'longueur': longueur,
      'envergure': envergure,
      'description': description,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour le poids de l'oiseau
class Poids {
  final String? poidsMoyen;
  final String? variation;
  final String? description;
  
  Poids({
    this.poidsMoyen,
    this.variation,
    this.description,
  });

  factory Poids.fromFirestore(Map<String, dynamic> data) {
    return Poids(
      poidsMoyen: _convertToString(data['poidsMoyen']),
      variation: _convertToString(data['variation']),
      description: _convertToString(data['description']),
    );
  }

  factory Poids.fromJson(Map<String, dynamic> json) {
    return Poids(
      poidsMoyen: _convertToString(json['poidsMoyen']),
      variation: _convertToString(json['variation']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poidsMoyen': poidsMoyen,
      'variation': variation,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'poidsMoyen': poidsMoyen,
      'variation': variation,
      'description': description,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour l'identification de l'oiseau
class Identification {
  final String? description;
  final String? morphologie;
  final String? dimorphismeSexuel;
  final String? plumageEte;
  final String? plumageHiver;
  final String? especesSimilaires;
  final String? caracteristiques;
  final Mesures? mesures; // nouveau schéma minimal
  final EspecesRessemblantes? especesRessemblantes; // nouveau schéma minimal

  Identification({
    this.description,
    this.morphologie,
    this.dimorphismeSexuel,
    this.plumageEte,
    this.plumageHiver,
    this.especesSimilaires,
    this.caracteristiques,
    this.mesures,
    this.especesRessemblantes,
  });

  factory Identification.fromFirestore(Map<String, dynamic> data) {
    return Identification(
      description: _convertToString(data['description']),
      morphologie: _convertToString(data['morphologie']),
      dimorphismeSexuel: _convertToString(data['dimorphismeSexuel']),
      plumageEte: _convertToString(data['plumageEte']),
      plumageHiver: _convertToString(data['plumageHiver']),
      especesSimilaires: _convertToString(data['especesSimilaires']),
      caracteristiques: _convertToString(data['caracteristiques']),
      mesures: (data['mesures'] is Map<String, dynamic>)
          ? Mesures.fromFirestore(data['mesures'] as Map<String, dynamic>)
          : null,
      especesRessemblantes: (data['especesRessemblantes'] is Map<String, dynamic>)
          ? EspecesRessemblantes.fromFirestore(data['especesRessemblantes'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Identification.fromJson(Map<String, dynamic> json) {
    return Identification(
      description: _convertToString(json['description']),
      morphologie: _convertToString(json['morphologie']),
      dimorphismeSexuel: _convertToString(json['dimorphismeSexuel']),
      plumageEte: _convertToString(json['plumageEte']),
      plumageHiver: _convertToString(json['plumageHiver']),
      especesSimilaires: _convertToString(json['especesSimilaires']),
      caracteristiques: _convertToString(json['caracteristiques']),
      mesures: (json['mesures'] is Map<String, dynamic>)
          ? Mesures.fromJson(json['mesures'] as Map<String, dynamic>)
          : null,
      especesRessemblantes: (json['especesRessemblantes'] is Map<String, dynamic>)
          ? EspecesRessemblantes.fromJson(json['especesRessemblantes'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'morphologie': morphologie,
      'dimorphismeSexuel': dimorphismeSexuel,
      'plumageEte': plumageEte,
      'plumageHiver': plumageHiver,
      'especesSimilaires': especesSimilaires,
      'caracteristiques': caracteristiques,
      if (mesures != null) 'mesures': mesures!.toFirestore(),
      if (especesRessemblantes != null) 'especesRessemblantes': especesRessemblantes!.toFirestore(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'morphologie': morphologie,
      'dimorphismeSexuel': dimorphismeSexuel,
      'plumageEte': plumageEte,
      'plumageHiver': plumageHiver,
      'especesSimilaires': especesSimilaires,
      'caracteristiques': caracteristiques,
      if (mesures != null) 'mesures': mesures!.toJson(),
      if (especesRessemblantes != null) 'especesRessemblantes': especesRessemblantes!.toJson(),
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

class Mesures {
  final String? poids;
  final String? taille;
  final String? envergure;

  Mesures({this.poids, this.taille, this.envergure});

  factory Mesures.fromFirestore(Map<String, dynamic> data) {
    return Mesures(
      poids: Identification._convertToString(data['poids']),
      taille: Identification._convertToString(data['taille']),
      envergure: Identification._convertToString(data['envergure']),
    );
  }

  factory Mesures.fromJson(Map<String, dynamic> json) {
    return Mesures(
      poids: Identification._convertToString(json['poids']),
      taille: Identification._convertToString(json['taille']),
      envergure: Identification._convertToString(json['envergure']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'poids': poids,
      'taille': taille,
      'envergure': envergure,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'poids': poids,
      'taille': taille,
      'envergure': envergure,
    };
  }
}

class EspecesRessemblantes {
  final List<String> exemples;
  final String? differenciation;

  EspecesRessemblantes({required this.exemples, this.differenciation});

  factory EspecesRessemblantes.fromFirestore(Map<String, dynamic> data) {
    return EspecesRessemblantes(
      exemples: _convertToList(data['exemples']),
      differenciation: Identification._convertToString(data['differenciation']),
    );
  }

  factory EspecesRessemblantes.fromJson(Map<String, dynamic> json) {
    return EspecesRessemblantes(
      exemples: _convertToList(json['exemples']),
      differenciation: Identification._convertToString(json['differenciation']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'exemples': exemples,
      'differenciation': differenciation,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'exemples': exemples,
      'differenciation': differenciation,
    };
  }

  static List<String> _convertToList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .map((e) => Identification._convertToString(e) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) return [value];
    return [];
  }
}

/// Classe pour l'habitat de l'oiseau
class Habitat {
  final List<String> milieux;
  final String? altitude;
  final String? vegetation;
  final String? saisonnalite;
  final String? description;
  final String? zonesObservation; // nouveau
  final Migration? migration; // nouveau

  Habitat({
    required this.milieux,
    this.altitude,
    this.vegetation,
    this.saisonnalite,
    this.description,
    this.zonesObservation,
    this.migration,
  });

  factory Habitat.fromFirestore(Map<String, dynamic> data) {
    return Habitat(
      milieux: _convertToList(data['milieux']),
      altitude: _convertToString(data['altitude']),
      vegetation: _convertToString(data['vegetation']),
      saisonnalite: _convertToString(data['saisonnalite']),
      description: _convertToString(data['description']),
      zonesObservation: _convertToString(data['zonesObservation']),
      migration: (data['migration'] is Map<String, dynamic>)
          ? Migration.fromFirestore(data['migration'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Habitat.fromJson(Map<String, dynamic> json) {
    return Habitat(
      milieux: _convertToList(json['milieux']),
      altitude: _convertToString(json['altitude']),
      vegetation: _convertToString(json['vegetation']),
      saisonnalite: _convertToString(json['saisonnalite']),
      description: _convertToString(json['description']),
      zonesObservation: _convertToString(json['zonesObservation']),
      migration: (json['migration'] is Map<String, dynamic>)
          ? Migration.fromJson(json['migration'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'milieux': milieux,
      'altitude': altitude,
      'vegetation': vegetation,
      'saisonnalite': saisonnalite,
      'description': description,
      'zonesObservation': zonesObservation,
      if (migration != null) 'migration': migration!.toFirestore(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'milieux': milieux,
      'altitude': altitude,
      'vegetation': vegetation,
      'saisonnalite': saisonnalite,
      'description': description,
      'zonesObservation': zonesObservation,
      if (migration != null) 'migration': migration!.toJson(),
    };
  }

  static List<String> _convertToList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => _convertToString(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (value is String) return [value];
    return [];
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

class Migration {
  final String? description;
  final Mois? mois;

  Migration({this.description, this.mois});

  factory Migration.fromFirestore(Map<String, dynamic> data) {
    return Migration(
      description: Habitat._convertToString(data['description']),
      mois: (data['mois'] is Map<String, dynamic>) ? Mois.fromFirestore(data['mois'] as Map<String, dynamic>) : null,
    );
  }

  factory Migration.fromJson(Map<String, dynamic> json) {
    return Migration(
      description: Habitat._convertToString(json['description']),
      mois: (json['mois'] is Map<String, dynamic>) ? Mois.fromJson(json['mois'] as Map<String, dynamic>) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      if (mois != null) 'mois': mois!.toFirestore(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      if (mois != null) 'mois': mois!.toJson(),
    };
  }
}

class Mois {
  final String? debut;
  final String? fin;

  Mois({this.debut, this.fin});

  factory Mois.fromFirestore(Map<String, dynamic> data) {
    return Mois(
      debut: Habitat._convertToString(data['debut']),
      fin: Habitat._convertToString(data['fin']),
    );
  }

  factory Mois.fromJson(Map<String, dynamic> json) {
    return Mois(
      debut: Habitat._convertToString(json['debut']),
      fin: Habitat._convertToString(json['fin']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'debut': debut,
      'fin': fin,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'debut': debut,
      'fin': fin,
    };
  }
}

/// Classe pour l'alimentation de l'oiseau
class Alimentation {
  final String? regimePrincipal;
  final List<String> proiesPrincipales;
  final List<String> techniquesChasse;
  final String? comportementAlimentaire;
  final String? description;

  Alimentation({
    this.regimePrincipal,
    required this.proiesPrincipales,
    required this.techniquesChasse,
    this.comportementAlimentaire,
    this.description,
  });

  factory Alimentation.fromFirestore(Map<String, dynamic> data) {
    return Alimentation(
      regimePrincipal: _convertToString(data['regimePrincipal']),
      proiesPrincipales: _convertToList(data['proiesPrincipales']),
      techniquesChasse: _convertToList(data['techniquesChasse']),
      comportementAlimentaire: _convertToString(data['comportementAlimentaire']),
      description: _convertToString(data['description']),
    );
  }

  factory Alimentation.fromJson(Map<String, dynamic> json) {
    return Alimentation(
      regimePrincipal: _convertToString(json['regimePrincipal']),
      proiesPrincipales: _convertToList(json['proiesPrincipales']),
      techniquesChasse: _convertToList(json['techniquesChasse']),
      comportementAlimentaire: _convertToString(json['comportementAlimentaire']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'regimePrincipal': regimePrincipal,
      'proiesPrincipales': proiesPrincipales,
      'techniquesChasse': techniquesChasse,
      'comportementAlimentaire': comportementAlimentaire,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'regimePrincipal': regimePrincipal,
      'proiesPrincipales': proiesPrincipales,
      'techniquesChasse': techniquesChasse,
      'comportementAlimentaire': comportementAlimentaire,
      'description': description,
    };
  }

  static List<String> _convertToList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => _convertToString(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (value is String) return [value];
    return [];
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour la reproduction de l'oiseau
class Reproduction {
  final String? saisonReproduction;
  final String? typeNid;
  final String? nombreOeufs;
  final String? dureeIncubation;
  final String? description;
  final Periode? periode; // nouveau
  final String? nbPontes; // nouveau
  final String? nbOeufsParPondee; // nouveau
  final String? incubationJours; // nouveau
  final Map<String, String>? details; // nouveau: sous-éléments détaillés

  Reproduction({
    this.saisonReproduction,
    this.typeNid,
    this.nombreOeufs,
    this.dureeIncubation,
    this.description,
    this.periode,
    this.nbPontes,
    this.nbOeufsParPondee,
    this.incubationJours,
    this.details,
  });

  factory Reproduction.fromFirestore(Map<String, dynamic> data) {
    final detailsFromField = _convertToStringMap(data['details']);
    final extracted = _extractDetailsFromMap(data);
    return Reproduction(
      saisonReproduction: _convertToString(data['saisonReproduction']),
      typeNid: _convertToString(data['typeNid']),
      nombreOeufs: _convertToString(data['nombreOeufs']),
      dureeIncubation: _convertToString(data['dureeIncubation']),
      description: _convertToString(data['description']),
      periode: (data['periode'] is Map<String, dynamic>) ? Periode.fromFirestore(data['periode'] as Map<String, dynamic>) : null,
      nbPontes: _convertToString(data['nbPontes']),
      nbOeufsParPondee: _convertToString(data['nbOeufsParPondee']),
      incubationJours: _convertToString(data['incubationJours']),
      details: detailsFromField ?? extracted,
    );
  }

  factory Reproduction.fromJson(Map<String, dynamic> json) {
    final detailsFromField = _convertToStringMap(json['details']);
    final extracted = _extractDetailsFromMap(json);
    return Reproduction(
      saisonReproduction: _convertToString(json['saisonReproduction']),
      typeNid: _convertToString(json['typeNid']),
      nombreOeufs: _convertToString(json['nombreOeufs']),
      dureeIncubation: _convertToString(json['dureeIncubation']),
      description: _convertToString(json['description']),
      periode: (json['periode'] is Map<String, dynamic>) ? Periode.fromJson(json['periode'] as Map<String, dynamic>) : null,
      nbPontes: _convertToString(json['nbPontes']),
      nbOeufsParPondee: _convertToString(json['nbOeufsParPondee']),
      incubationJours: _convertToString(json['incubationJours']),
      details: detailsFromField ?? extracted,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'saisonReproduction': saisonReproduction,
      'typeNid': typeNid,
      'nombreOeufs': nombreOeufs,
      'dureeIncubation': dureeIncubation,
      'description': description,
      if (periode != null) 'periode': periode!.toFirestore(),
      'nbPontes': nbPontes,
      'nbOeufsParPondee': nbOeufsParPondee,
      'incubationJours': incubationJours,
      if (details != null) 'details': details,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'saisonReproduction': saisonReproduction,
      'typeNid': typeNid,
      'nombreOeufs': nombreOeufs,
      'dureeIncubation': dureeIncubation,
      'description': description,
      if (periode != null) 'periode': periode!.toJson(),
      'nbPontes': nbPontes,
      'nbOeufsParPondee': nbOeufsParPondee,
      'incubationJours': incubationJours,
      if (details != null) 'details': details,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }

  static Map<String, String>? _convertToStringMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      final Map<String, String> result = {};
      value.forEach((key, v) {
        final k = key?.toString();
        final s = _convertToString(v);
        if (k != null && s != null && s.trim().isNotEmpty) {
          result[k] = s.trim();
        }
      });
      return result.isEmpty ? null : result;
    }
    return null;
  }

  static Map<String, String>? _extractDetailsFromMap(Map value) {
    // Récupère certaines clés connues soit à la racine, soit sous 'etapes'
    final Map sourceRoot = value;
    final Map sourceEtapes = (value['etapes'] is Map) ? (value['etapes'] as Map) : {};

    String? readFirst(List<String> keys) {
      for (final k in keys) {
        if (sourceRoot.containsKey(k)) {
          final s = _convertToString(sourceRoot[k]);
          if (s != null && s.trim().isNotEmpty) return s.trim();
        }
        if (sourceEtapes.containsKey(k)) {
          final s = _convertToString(sourceEtapes[k]);
          if (s != null && s.trim().isNotEmpty) return s.trim();
        }
      }
      return null;
    }

    final aliases = <String, List<String>>{
      'paradeNuptiale': ['paradeNuptiale', 'parade', 'periodeNuptiale'],
      'accouplement': ['accouplement'],
      'nidification': ['nidification'],
      'materiauxNid': ['materiauxNid', 'materiauxDuNid', 'materiaux'],
      'emplacementNid': ['emplacementNid', 'siteNid', 'emplacement'],
      'ponte': ['ponte', 'periodePonte'],
      'incubation': ['incubation'],
      'incubationParents': ['incubationMale', 'incubationMâle', 'incubationFemelle', 'incubationParents'],
      'nourrissage': ['nourrissage', 'nourrissageParents', 'dureeNourrissage'],
      'envol': ['ageEnvol', 'envolJeunes', 'envol'],
      'emancipation': ['ageEmancipation', 'émancipation', 'emancipation'],
    };

    final Map<String, String> result = {};
    for (final entry in aliases.entries) {
      final v = readFirst(entry.value);
      if (v != null && v.isNotEmpty) {
        result[entry.key] = v;
      }
    }
    return result.isEmpty ? null : result;
  }
}

class Periode {
  final String? debutMois;
  final String? finMois;

  Periode({this.debutMois, this.finMois});

  factory Periode.fromFirestore(Map<String, dynamic> data) {
    return Periode(
      debutMois: Reproduction._convertToString(data['debutMois']),
      finMois: Reproduction._convertToString(data['finMois']),
    );
  }

  factory Periode.fromJson(Map<String, dynamic> json) {
    return Periode(
      debutMois: Reproduction._convertToString(json['debutMois']),
      finMois: Reproduction._convertToString(json['finMois']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'debutMois': debutMois,
      'finMois': finMois,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'debutMois': debutMois,
      'finMois': finMois,
    };
  }
}

/// Classe pour la répartition géographique
class Repartition {
  final String? statutPresence;
  final Periodes periodes;
  final String? noteMigration;
  final String? description;

  Repartition({
    this.statutPresence,
    required this.periodes,
    this.noteMigration,
    this.description,
  });

  factory Repartition.fromFirestore(Map<String, dynamic> data) {
    return Repartition(
      statutPresence: _convertToString(data['statutPresence']),
      periodes: Periodes.fromFirestore(data['periodes'] as Map<String, dynamic>? ?? {}),
      noteMigration: _convertToString(data['noteMigration']),
      description: _convertToString(data['description']),
    );
  }

  factory Repartition.fromJson(Map<String, dynamic> json) {
    return Repartition(
      statutPresence: _convertToString(json['statutPresence']),
      periodes: Periodes.fromJson(json['periodes'] as Map<String, dynamic>? ?? {}),
      noteMigration: _convertToString(json['noteMigration']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'statutPresence': statutPresence,
      'periodes': periodes.toFirestore(),
      'noteMigration': noteMigration,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'statutPresence': statutPresence,
      'periodes': periodes.toJson(),
      'noteMigration': noteMigration,
      'description': description,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour Protection / État actuel
class ProtectionEtatActuel {
  final String? description;
  final String? statutFrance;
  final String? statutMonde;
  final String? actions;

  ProtectionEtatActuel({
    this.description,
    this.statutFrance,
    this.statutMonde,
    this.actions,
  });

  factory ProtectionEtatActuel.fromFirestore(Map<String, dynamic> data) {
    return ProtectionEtatActuel(
      description: _convertToString(data['description']),
      statutFrance: _convertToString(data['statutFrance']),
      statutMonde: _convertToString(data['statutMonde']),
      actions: _convertToString(data['actions']),
    );
  }

  factory ProtectionEtatActuel.fromJson(Map<String, dynamic> json) {
    return ProtectionEtatActuel(
      description: _convertToString(json['description']),
      statutFrance: _convertToString(json['statutFrance']),
      statutMonde: _convertToString(json['statutMonde']),
      actions: _convertToString(json['actions']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'statutFrance': statutFrance,
      'statutMonde': statutMonde,
      'actions': actions,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'statutFrance': statutFrance,
      'statutMonde': statutMonde,
      'actions': actions,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour les périodes de présence
class Periodes {
  final String? printemps;
  final String? ete;
  final String? automne;
  final String? hiver;

  Periodes({
    this.printemps,
    this.ete,
    this.automne,
    this.hiver,
  });

  factory Periodes.fromFirestore(Map<String, dynamic> data) {
    return Periodes(
      printemps: _convertToString(data['printemps']),
      ete: _convertToString(data['ete']),
      automne: _convertToString(data['automne']),
      hiver: _convertToString(data['hiver']),
    );
  }

  factory Periodes.fromJson(Map<String, dynamic> json) {
    return Periodes(
      printemps: _convertToString(json['printemps']),
      ete: _convertToString(json['ete']),
      automne: _convertToString(json['automne']),
      hiver: _convertToString(json['hiver']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'printemps': printemps,
      'ete': ete,
      'automne': automne,
      'hiver': hiver,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'printemps': printemps,
      'ete': ete,
      'automne': automne,
      'hiver': hiver,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Présent' : 'Absent';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour les vocalisations
class Vocalisations {
  final String? chantTerritorial;
  final String? crisAlarme;
  final String? crisContact;
  final String? description;
  final String? fichierAudio;

  Vocalisations({
    this.chantTerritorial,
    this.crisAlarme,
    this.crisContact,
    this.description,
    this.fichierAudio,
  });

  factory Vocalisations.fromFirestore(Map<String, dynamic> data) {
    return Vocalisations(
      chantTerritorial: _convertToString(data['chantTerritorial']),
      crisAlarme: _convertToString(data['crisAlarme']),
      crisContact: _convertToString(data['crisContact']),
      description: _convertToString(data['description']),
      fichierAudio: _convertToString(data['fichierAudio']),
    );
  }

  factory Vocalisations.fromJson(Map<String, dynamic> json) {
    return Vocalisations(
      chantTerritorial: _convertToString(json['chantTerritorial']),
      crisAlarme: _convertToString(json['crisAlarme']),
      crisContact: _convertToString(json['crisContact']),
      description: _convertToString(json['description']),
      fichierAudio: _convertToString(json['fichierAudio']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chantTerritorial': chantTerritorial,
      'crisAlarme': crisAlarme,
      'crisContact': crisContact,
      'description': description,
      'fichierAudio': fichierAudio,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'chantTerritorial': chantTerritorial,
      'crisAlarme': crisAlarme,
      'crisContact': crisContact,
      'description': description,
      'fichierAudio': fichierAudio,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour le comportement
class Comportement {
  final String? modeVie;
  final String? territorialite;
  final String? sociabilite;
  final String? description;

  Comportement({
    this.modeVie,
    this.territorialite,
    this.sociabilite,
    this.description,
  });

  factory Comportement.fromFirestore(Map<String, dynamic> data) {
    return Comportement(
      modeVie: _convertToString(data['modeVie']),
      territorialite: _convertToString(data['territorialite']),
      sociabilite: _convertToString(data['sociabilite']),
      description: _convertToString(data['description']),
    );
  }

  factory Comportement.fromJson(Map<String, dynamic> json) {
    return Comportement(
      modeVie: _convertToString(json['modeVie']),
      territorialite: _convertToString(json['territorialite']),
      sociabilite: _convertToString(json['sociabilite']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'modeVie': modeVie,
      'territorialite': territorialite,
      'sociabilite': sociabilite,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'modeVie': modeVie,
      'territorialite': territorialite,
      'sociabilite': sociabilite,
      'description': description,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour la conservation
class Conservation {
  final String? statutIUCN;
  final String? protectionLegale;
  final String? menaces;
  final String? actionsProtection;
  final String? description;

  Conservation({
    this.statutIUCN,
    this.protectionLegale,
    this.menaces,
    this.actionsProtection,
    this.description,
  });

  factory Conservation.fromFirestore(Map<String, dynamic> data) {
    return Conservation(
      statutIUCN: _convertToString(data['statutIUCN']),
      protectionLegale: _convertToString(data['protectionLegale']),
      menaces: _convertToString(data['menaces']),
      actionsProtection: _convertToString(data['actionsProtection']),
      description: _convertToString(data['description']),
    );
  }

  factory Conservation.fromJson(Map<String, dynamic> json) {
    return Conservation(
      statutIUCN: _convertToString(json['statutIUCN']),
      protectionLegale: _convertToString(json['protectionLegale']),
      menaces: _convertToString(json['menaces']),
      actionsProtection: _convertToString(json['actionsProtection']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'statutIUCN': statutIUCN,
      'protectionLegale': protectionLegale,
      'menaces': menaces,
      'actionsProtection': actionsProtection,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'statutIUCN': statutIUCN,
      'protectionLegale': protectionLegale,
      'menaces': menaces,
      'actionsProtection': actionsProtection,
      'description': description,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour les médias
class Medias {
  final String? imagePrincipale;
  final List<String> images;
  final String? video;
  final String? description;

  Medias({
    this.imagePrincipale,
    required this.images,
    this.video,
    this.description,
  });

  factory Medias.fromFirestore(Map<String, dynamic> data) {
    return Medias(
      imagePrincipale: _convertToString(data['imagePrincipale']),
      images: _convertToList(data['images']),
      video: _convertToString(data['video']),
      description: _convertToString(data['description']),
    );
  }

  factory Medias.fromJson(Map<String, dynamic> json) {
    return Medias(
      imagePrincipale: _convertToString(json['imagePrincipale']),
      images: _convertToList(json['images']),
      video: _convertToString(json['video']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'imagePrincipale': imagePrincipale,
      'images': images,
      'video': video,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'imagePrincipale': imagePrincipale,
      'images': images,
      'video': video,
      'description': description,
    };
  }

  static List<String> _convertToList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => _convertToString(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (value is String) return [value];
    return [];
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour les sources
class Sources {
  final List<String> references;
  final String? dateMiseAJour;
  final String? description;

  Sources({
    required this.references,
    this.dateMiseAJour,
    this.description,
  });

  factory Sources.fromFirestore(Map<String, dynamic> data) {
    return Sources(
      references: _convertToList(data['references']),
      dateMiseAJour: _convertToString(data['dateMiseAJour']),
      description: _convertToString(data['description']),
    );
  }

  factory Sources.fromJson(Map<String, dynamic> json) {
    return Sources(
      references: _convertToList(json['references']),
      dateMiseAJour: _convertToString(json['dateMiseAJour']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'references': references,
      'dateMiseAJour': dateMiseAJour,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'references': references,
      'dateMiseAJour': dateMiseAJour,
      'description': description,
    };
  }

  static List<String> _convertToList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => _convertToString(e) ?? '').where((e) => e.isNotEmpty).toList();
    }
    if (value is String) return [value];
    return [];
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour les métadonnées
class Metadata {
  final DateTime? dateCreation;
  final DateTime? dateModification;
  final String? version;
  final String? statut;
  final String? notes;

  Metadata({
    this.dateCreation,
    this.dateModification,
    this.version,
    this.statut,
    this.notes,
  });

  factory Metadata.fromFirestore(Map<String, dynamic> data) {
    return Metadata(
      dateCreation: _convertToDateTime(data['dateCreation']),
      dateModification: _convertToDateTime(data['dateModification']),
      version: _convertToString(data['version']),
      statut: _convertToString(data['statut']),
      notes: _convertToString(data['notes']),
    );
  }

  factory Metadata.fromJson(Map<String, dynamic> json) {
    return Metadata(
      dateCreation: _convertToDateTime(json['dateCreation']),
      dateModification: _convertToDateTime(json['dateModification']),
      version: _convertToString(json['version']),
      statut: _convertToString(json['statut']),
      notes: _convertToString(json['notes']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dateCreation': dateCreation?.toIso8601String(),
      'dateModification': dateModification?.toIso8601String(),
      'version': version,
      'statut': statut,
      'notes': notes,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'dateCreation': dateCreation?.toIso8601String(),
      'dateModification': dateModification?.toIso8601String(),
      'version': version,
      'statut': statut,
      'notes': notes,
    };
  }

  static DateTime? _convertToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

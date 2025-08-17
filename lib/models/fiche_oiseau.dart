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
  final String? dimorphismeSexuel;
  final String? plumageEte;
  final String? plumageHiver;
  final String? especesSimilaires;
  final String? caracteristiques;

  Identification({
    this.description,
    this.dimorphismeSexuel,
    this.plumageEte,
    this.plumageHiver,
    this.especesSimilaires,
    this.caracteristiques,
  });

  factory Identification.fromFirestore(Map<String, dynamic> data) {
    return Identification(
      description: _convertToString(data['description']),
      dimorphismeSexuel: _convertToString(data['dimorphismeSexuel']),
      plumageEte: _convertToString(data['plumageEte']),
      plumageHiver: _convertToString(data['plumageHiver']),
      especesSimilaires: _convertToString(data['especesSimilaires']),
      caracteristiques: _convertToString(data['caracteristiques']),
    );
  }

  factory Identification.fromJson(Map<String, dynamic> json) {
    return Identification(
      description: _convertToString(json['description']),
      dimorphismeSexuel: _convertToString(json['dimorphismeSexuel']),
      plumageEte: _convertToString(json['plumageEte']),
      plumageHiver: _convertToString(json['plumageHiver']),
      especesSimilaires: _convertToString(json['especesSimilaires']),
      caracteristiques: _convertToString(json['caracteristiques']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'description': description,
      'dimorphismeSexuel': dimorphismeSexuel,
      'plumageEte': plumageEte,
      'plumageHiver': plumageHiver,
      'especesSimilaires': especesSimilaires,
      'caracteristiques': caracteristiques,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'dimorphismeSexuel': dimorphismeSexuel,
      'plumageEte': plumageEte,
      'plumageHiver': plumageHiver,
      'especesSimilaires': especesSimilaires,
      'caracteristiques': caracteristiques,
    };
  }

  static String? _convertToString(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is String) return value;
    return value.toString();
  }
}

/// Classe pour l'habitat de l'oiseau
class Habitat {
  final List<String> milieux;
  final String? altitude;
  final String? vegetation;
  final String? saisonnalite;
  final String? description;

  Habitat({
    required this.milieux,
    this.altitude,
    this.vegetation,
    this.saisonnalite,
    this.description,
  });

  factory Habitat.fromFirestore(Map<String, dynamic> data) {
    return Habitat(
      milieux: _convertToList(data['milieux']),
      altitude: _convertToString(data['altitude']),
      vegetation: _convertToString(data['vegetation']),
      saisonnalite: _convertToString(data['saisonnalite']),
      description: _convertToString(data['description']),
    );
  }

  factory Habitat.fromJson(Map<String, dynamic> json) {
    return Habitat(
      milieux: _convertToList(json['milieux']),
      altitude: _convertToString(json['altitude']),
      vegetation: _convertToString(json['vegetation']),
      saisonnalite: _convertToString(json['saisonnalite']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'milieux': milieux,
      'altitude': altitude,
      'vegetation': vegetation,
      'saisonnalite': saisonnalite,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'milieux': milieux,
      'altitude': altitude,
      'vegetation': vegetation,
      'saisonnalite': saisonnalite,
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

  Reproduction({
    this.saisonReproduction,
    this.typeNid,
    this.nombreOeufs,
    this.dureeIncubation,
    this.description,
  });

  factory Reproduction.fromFirestore(Map<String, dynamic> data) {
    return Reproduction(
      saisonReproduction: _convertToString(data['saisonReproduction']),
      typeNid: _convertToString(data['typeNid']),
      nombreOeufs: _convertToString(data['nombreOeufs']),
      dureeIncubation: _convertToString(data['dureeIncubation']),
      description: _convertToString(data['description']),
    );
  }

  factory Reproduction.fromJson(Map<String, dynamic> json) {
    return Reproduction(
      saisonReproduction: _convertToString(json['saisonReproduction']),
      typeNid: _convertToString(json['typeNid']),
      nombreOeufs: _convertToString(json['nombreOeufs']),
      dureeIncubation: _convertToString(json['dureeIncubation']),
      description: _convertToString(json['description']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'saisonReproduction': saisonReproduction,
      'typeNid': typeNid,
      'nombreOeufs': nombreOeufs,
      'dureeIncubation': dureeIncubation,
      'description': description,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'saisonReproduction': saisonReproduction,
      'typeNid': typeNid,
      'nombreOeufs': nombreOeufs,
      'dureeIncubation': dureeIncubation,
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

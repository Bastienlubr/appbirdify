class Mission {
  final String id;
  final String milieu;
  final int index;
  final String status;
  final List<Map<String, dynamic>> questions;
  final String? title;
  final String? csvFile;
  final String? titreMission;
  final String? sousTitre;
  final String? iconUrl;
  final int lastStarsEarned;
  final bool hasBeenSeen;

  Mission({
    required this.id,
    required this.milieu,
    required this.index,
    required this.status,
    required this.questions,
    this.title,
    this.csvFile,
    this.titreMission,
    this.sousTitre,
    this.iconUrl,
    this.lastStarsEarned = 0,
    this.hasBeenSeen = false,
  });

  // Getters
  String get getId => id;
  String get getMilieu => milieu;
  int get getIndex => index;
  String get getStatus => status;
  List<Map<String, dynamic>> get getQuestions => questions;
  String? get getTitle => title;
  String? get getCsvFile => csvFile;
  String? get getTitreMission => titreMission;
  String? get getSousTitre => sousTitre;
  String? get getIconUrl => iconUrl;
  int get getLastStarsEarned => lastStarsEarned;

  // Méthode fromJson pour créer un objet Mission à partir d'un Map
  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      milieu: json['milieu'] as String,
      index: json['index'] as int,
      status: json['status'] as String,
      questions: List<Map<String, dynamic>>.from(json['questions'] as List),
      title: json['title'] as String?,
      csvFile: json['csvFile'] as String?,
      titreMission: json['titreMission'] as String?,
      sousTitre: json['sousTitre'] as String?,
      iconUrl: json['iconUrl'] as String?,
      lastStarsEarned: json['lastStarsEarned'] as int? ?? 0,
      hasBeenSeen: json['hasBeenSeen'] as bool? ?? false,
    );
  }

  // Méthode toJson pour convertir l'objet Mission en Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'milieu': milieu,
      'index': index,
      'status': status,
      'questions': questions,
      if (title != null) 'title': title,
      if (csvFile != null) 'csvFile': csvFile,
      if (titreMission != null) 'titreMission': titreMission,
      if (sousTitre != null) 'sousTitre': sousTitre,
      if (iconUrl != null) 'iconUrl': iconUrl,
      'lastStarsEarned': lastStarsEarned,
      'hasBeenSeen': hasBeenSeen,
    };
  }

  // Méthode toString pour le débogage
  @override
  String toString() {
    return 'Mission(id: $id, milieu: $milieu, index: $index, status: $status, questions: $questions, title: $title, csvFile: $csvFile, titreMission: $titreMission, sousTitre: $sousTitre, iconUrl: $iconUrl, lastStarsEarned: $lastStarsEarned)';
  }

  // Méthode equals pour comparer deux objets Mission
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Mission &&
        other.id == id &&
        other.milieu == milieu &&
        other.index == index &&
        other.status == status &&
        other.questions == questions &&
        other.title == title &&
        other.csvFile == csvFile &&
        other.titreMission == titreMission &&
        other.sousTitre == sousTitre &&
        other.iconUrl == iconUrl &&
        other.lastStarsEarned == lastStarsEarned;
  }

  // Méthode hashCode pour la cohérence avec equals
  @override
  int get hashCode {
    return Object.hash(id, milieu, index, status, questions, title, csvFile, titreMission, sousTitre, iconUrl, lastStarsEarned);
  }

  // Méthode copyWith pour créer une copie modifiée
  Mission copyWith({
    String? id,
    String? milieu,
    int? index,
    String? status,
    List<Map<String, dynamic>>? questions,
    String? title,
    String? csvFile,
    String? titreMission,
    String? sousTitre,
    String? iconUrl,
    int? lastStarsEarned,
    bool? hasBeenSeen,
  }) {
    return Mission(
      id: id ?? this.id,
      milieu: milieu ?? this.milieu,
      index: index ?? this.index,
      status: status ?? this.status,
      questions: questions ?? this.questions,
      title: title ?? this.title,
      csvFile: csvFile ?? this.csvFile,
      titreMission: titreMission ?? this.titreMission,
      sousTitre: sousTitre ?? this.sousTitre,
      iconUrl: iconUrl ?? this.iconUrl,
      lastStarsEarned: lastStarsEarned ?? this.lastStarsEarned,
      hasBeenSeen: hasBeenSeen ?? this.hasBeenSeen,
    );
  }
} 
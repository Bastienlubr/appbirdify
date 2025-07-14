class Mission {
  final String id;
  final String milieu;
  final int index;
  final String status;
  final List<Map<String, dynamic>> questions;
  final String? title;
  final String? csvFile;

  Mission({
    required this.id,
    required this.milieu,
    required this.index,
    required this.status,
    required this.questions,
    this.title,
    this.csvFile,
  });

  // Getters
  String get getId => id;
  String get getMilieu => milieu;
  int get getIndex => index;
  String get getStatus => status;
  List<Map<String, dynamic>> get getQuestions => questions;
  String? get getTitle => title;
  String? get getCsvFile => csvFile;

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
    };
  }

  // Méthode toString pour le débogage
  @override
  String toString() {
    return 'Mission(id: $id, milieu: $milieu, index: $index, status: $status, questions: $questions, title: $title, csvFile: $csvFile)';
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
        other.csvFile == csvFile;
  }

  // Méthode hashCode pour la cohérence avec equals
  @override
  int get hashCode {
    return Object.hash(id, milieu, index, status, questions, title, csvFile);
  }
} 
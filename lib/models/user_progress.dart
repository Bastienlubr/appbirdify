class UserProgress {
  final String idUser;
  final int unlockedMilieu;
  final Map<String, int> missionsDone;
  final bool premium;

  UserProgress({
    required this.idUser,
    required this.unlockedMilieu,
    required this.missionsDone,
    required this.premium,
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      idUser: json['idUser'] as String,
      unlockedMilieu: json['unlockedMilieu'] as int,
      missionsDone: Map<String, int>.from(json['missionsDone'] as Map),
      premium: json['premium'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idUser': idUser,
      'unlockedMilieu': unlockedMilieu,
      'missionsDone': missionsDone,
      'premium': premium,
    };
  }

  @override
  String toString() {
    return 'UserProgress{idUser: $idUser, unlockedMilieu: $unlockedMilieu, missionsDone: $missionsDone, premium: $premium}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserProgress &&
        other.idUser == idUser &&
        other.unlockedMilieu == unlockedMilieu &&
        other.premium == premium;
  }

  @override
  int get hashCode {
    return idUser.hashCode ^ unlockedMilieu.hashCode ^ premium.hashCode;
  }
} 
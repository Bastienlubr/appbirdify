import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final int xp;
  final bool isPremium;
  final String currentBiome;
  final List<String> biomesUnlocked;
  final DateTime createdAt;
  final DateTime lastUpdated;
  
  // Champs pour la gestion du système de vies

  final DateTime? lastLifeUsedAt;
  final bool unlimitedAccess;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    required this.xp,
    required this.isPremium,
    required this.currentBiome,
    required this.biomesUnlocked,
    required this.createdAt,
    required this.lastUpdated,

    this.lastLifeUsedAt,
    required this.unlimitedAccess,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      email: json['email'] ?? '',
      displayName: json['displayName'],
      xp: json['xp'] ?? 0,
      isPremium: json['isPremium'] ?? false,
      currentBiome: json['currentBiome'] ?? 'milieu urbain',
      biomesUnlocked: List<String>.from(json['biomesUnlocked'] ?? ['milieu urbain']),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastUpdated: (json['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      
      // Champs pour la gestion du système de vies
      
      lastLifeUsedAt: (json['lastLifeUsedAt'] as Timestamp?)?.toDate(),
      unlimitedAccess: json['unlimitedAccess'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'displayName': displayName,
      'xp': xp,
      'isPremium': isPremium,
      'currentBiome': currentBiome,
      'biomesUnlocked': biomesUnlocked,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      
      // Champs pour la gestion du système de vies
      
      'lastLifeUsedAt': lastLifeUsedAt != null ? Timestamp.fromDate(lastLifeUsedAt!) : null,
      'unlimitedAccess': unlimitedAccess,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    int? xp,
    bool? isPremium,
    String? currentBiome,
    List<String>? biomesUnlocked,
    DateTime? createdAt,
    DateTime? lastUpdated,

    DateTime? lastLifeUsedAt,
    bool? unlimitedAccess,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      xp: xp ?? this.xp,
      isPremium: isPremium ?? this.isPremium,
      currentBiome: currentBiome ?? this.currentBiome,
      biomesUnlocked: biomesUnlocked ?? this.biomesUnlocked,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      
      lastLifeUsedAt: lastLifeUsedAt ?? this.lastLifeUsedAt,
      unlimitedAccess: unlimitedAccess ?? this.unlimitedAccess,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, xp: $xp, isPremium: $isPremium, currentBiome: $currentBiome, biomesUnlocked: $biomesUnlocked, unlimitedAccess: $unlimitedAccess)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.xp == xp &&
        other.isPremium == isPremium &&
        other.currentBiome == currentBiome &&
        other.biomesUnlocked == biomesUnlocked &&

        other.unlimitedAccess == unlimitedAccess;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        xp.hashCode ^
        isPremium.hashCode ^
        currentBiome.hashCode ^
        biomesUnlocked.hashCode ^

        unlimitedAccess.hashCode;
  }
} 
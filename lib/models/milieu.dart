import 'package:flutter/material.dart';
import 'mission.dart';

class Milieu {
  final String id;
  final String name;
  final String imageAsset;
  final Color color;
  final List<Mission> missions;

  const Milieu({
    required this.id,
    required this.name,
    required this.imageAsset,
    required this.color,
    required this.missions,
  });

  // Méthode fromJson pour créer un objet Milieu à partir d'un Map
  factory Milieu.fromJson(Map<String, dynamic> json) {
    return Milieu(
      id: json['id'] as String,
      name: json['name'] as String,
      imageAsset: json['imageAsset'] as String,
      color: Color(json['color'] as int),
      missions: (json['missions'] as List)
          .map((missionJson) => Mission.fromJson(missionJson))
          .toList(),
    );
  }

  // Méthode toJson pour convertir l'objet Milieu en Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageAsset': imageAsset,
      'color': color.toARGB32(),
      'missions': missions.map((mission) => mission.toJson()).toList(),
    };
  }

  // Méthode toString pour le débogage
  @override
  String toString() {
    return 'Milieu(id: $id, name: $name, imageAsset: $imageAsset, color: $color, missions: $missions)';
  }

  // Méthode equals pour comparer deux objets Milieu
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Milieu &&
        other.id == id &&
        other.name == name &&
        other.imageAsset == imageAsset &&
        other.color == color &&
        other.missions == missions;
  }

  // Méthode hashCode pour la cohérence avec equals
  @override
  int get hashCode {
    return Object.hash(id, name, imageAsset, color, missions);
  }
} 
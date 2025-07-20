import 'package:flutter/material.dart';
import '../models/milieu.dart';
import '../models/mission.dart';

// TODO: Charger dynamiquement les missions depuis les fichiers CSV dans /assets/Missionhome
final List<Milieu> milieux = [
  // Milieu urbain - disponible
  Milieu(
    id: 'u',
    name: 'Milieu urbain',
    imageAsset: 'assets/images/Milieu/milieu_urbain.png',
    color: const Color(0xFF386641), // Vert foncé
    missions: [
      Mission(id: 'mission_U01', milieu: 'urbain', index: 1, status: 'available', questions: [], title: 'MISSION', csvFile: 'U01 - template_mission_quiz.csv'),
      Mission(id: 'mission_U02', milieu: 'urbain', index: 2, status: 'available', questions: [], title: 'MISSION', csvFile: 'U02 - template_mission_quiz.csv'),
      Mission(id: 'mission_U03', milieu: 'urbain', index: 3, status: 'available', questions: [], title: 'MISSION', csvFile: null),
      Mission(id: 'mission_U04', milieu: 'urbain', index: 4, status: 'available', questions: [], title: 'MISSION', csvFile: null),
      Mission(id: 'mission_U05', milieu: 'urbain', index: 5, status: 'available', questions: [], title: 'FINAL', csvFile: null),
    ],
  ),
  
  // Milieu forestier - disponible
  Milieu(
    id: 'f',
    name: 'Milieu forestier',
    imageAsset: 'assets/images/Milieu/milieu_forestier.png',
    color: const Color(0xFF6A994E), // Vert moyen
    missions: [
      Mission(id: 'mission_F01', milieu: 'forestier', index: 1, status: 'available', questions: [], title: 'MISSION', csvFile: 'F01 - template_mission_quiz.csv'),
      Mission(id: 'mission_F02', milieu: 'forestier', index: 2, status: 'available', questions: [], title: 'MISSION', csvFile: 'F02 - template_mission_quiz.csv'),
      Mission(id: 'mission_F03', milieu: 'forestier', index: 3, status: 'available', questions: [], title: 'MISSION', csvFile: null),
      Mission(id: 'mission_F04', milieu: 'forestier', index: 4, status: 'available', questions: [], title: 'MISSION', csvFile: null),
      Mission(id: 'mission_F05', milieu: 'forestier', index: 5, status: 'available', questions: [], title: 'FINAL', csvFile: null),
    ],
  ),
  
  // Milieu agricole - en attente d'image
  Milieu(
    id: 'agricole',
    name: 'MILIEU AGRICOLE',
    imageAsset: '', // Image à venir
    color: const Color(0xFFA7C957), // Vert clair
    missions: [
      // TODO: Charger les missions depuis les CSV
    ],
  ),
  
  // Milieu humide - en attente d'image
  Milieu(
    id: 'humide',
    name: 'MILIEU HUMIDE',
    imageAsset: '', // Image à venir
    color: const Color(0xFF4A90E2), // Bleu
    missions: [
      // TODO: Charger les missions depuis les CSV
    ],
  ),
  
  // Milieu montagneux - en attente d'image
  Milieu(
    id: 'montagneux',
    name: 'MILIEU MONTAGNEUX',
    imageAsset: '', // Image à venir
    color: const Color(0xFF8B4513), // Marron
    missions: [
      // TODO: Charger les missions depuis les CSV
    ],
  ),
  
  // Milieu littoral - en attente d'image
  Milieu(
    id: 'littoral',
    name: 'MILIEU LITTORAL',
    imageAsset: '', // Image à venir
    color: const Color(0xFF87CEEB), // Bleu ciel
    missions: [
      // TODO: Charger les missions depuis les CSV
    ],
  ),
]; 

final Map<String, List<Mission>> missionsParBiome = {
  'Urbain': milieux.firstWhere((m) => m.name.toLowerCase().contains('urbain')).missions,
  'Forestier': milieux.firstWhere((m) => m.name.toLowerCase().contains('forestier')).missions,
  'Agricole': milieux.firstWhere((m) => m.name.toLowerCase().contains('agricole')).missions,
  'Humide': milieux.firstWhere((m) => m.name.toLowerCase().contains('humide')).missions,
  'Montagnard': milieux.firstWhere((m) => m.name.toLowerCase().contains('montagneux')).missions,
  'Littoral': milieux.firstWhere((m) => m.name.toLowerCase().contains('littoral')).missions,
}; 
// ⚠️ À utiliser uniquement sur demande — API Xeno-Canto intégrée mais désactivée pour le moment

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class XenoCantoApi {
  static const String _baseUrl = 'https://xeno-canto.org/api/2';
  
  /// Recherche des enregistrements d'oiseaux via l'API Xeno-Canto
  /// 
  /// [query] : Nom de l'espèce à rechercher (ex: "Cyanistes caeruleus")
  /// [quality] : Qualité des enregistrements (A, B, C, D, E)
  /// [limit] : Nombre maximum de résultats à retourner
  /// 
  /// Retourne une liste d'enregistrements avec les champs :
  /// - file : URL du fichier audio
  /// - lic : Licence de l'enregistrement
  /// - en : Nom anglais de l'espèce
  /// - gen : Genre de l'espèce
  /// - sp : Espèce
  static Future<List<Map<String, dynamic>>> searchRecordings({
    required String query,
    String quality = 'A',
    int limit = 5,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = '$_baseUrl/recordings?query=$encodedQuery+q:$quality';
      
      if (kDebugMode) debugPrint('🔍 Recherche Xeno-Canto: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final recordings = data['recordings'] as List;
        
        return recordings.take(limit).map((recording) {
          return {
            'file': recording['file'] ?? '',
            'lic': recording['lic'] ?? '',
            'en': recording['en'] ?? 'Nom inconnu',
            'gen': recording['gen'] ?? '',
            'sp': recording['sp'] ?? '',
            'id': recording['id'] ?? '',
            'type': recording['type'] ?? '',
            'loc': recording['loc'] ?? '',
            'cnt': recording['cnt'] ?? '',
            'date': recording['date'] ?? '',
          };
        }).toList();
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la recherche Xeno-Canto: $e');
      rethrow;
    }
  }
  
  /// Récupère les détails d'un enregistrement spécifique
  static Future<Map<String, dynamic>?> getRecordingDetails(String recordingId) async {
    try {
      final url = '$_baseUrl/recordings/$recordingId';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Erreur API: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Erreur lors de la récupération des détails: $e');
      return null;
    }
  }
  
  /// Vérifie la disponibilité de l'API Xeno-Canto
  static Future<bool> isApiAvailable() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/recordings?query=test'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
} 
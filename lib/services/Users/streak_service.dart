import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service de gestion de la série (jours d'activité consécutifs)
class StreakService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Enregistre une activité pour aujourd'hui (fin d'un quiz: succès ou échec)
  /// Règles:
  /// - Si l'utilisateur a déjà une activité aujourd'hui → ne rien changer
  /// - Si la dernière activité date d'hier → incrémenter `serieEnCours`
  /// - Sinon (trou) → réinitialiser à 1
  /// - Conserver un historique borné des jours (dernier 60 jours)
  static Future<void> registerActivityToday(String uid) async {
    try {
      final userRef = _firestore.collection('utilisateurs').doc(uid);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(userRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final Map<String, dynamic> serie = (data['serie'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final List<String> jours = ((serie['derniersJoursActifs'] as List<dynamic>?)?.map((e) => e.toString()).toList()) ?? <String>[];
        final int currentStreak = (serie['serieEnCours'] as int?) ?? 0;
        final int bestStreak = (serie['serieMaximum'] as int?) ?? 0;

        final DateTime nowUtc = DateTime.now().toUtc();
        final String todayKey = _formatDayKey(nowUtc);
        final String yesterdayKey = _formatDayKey(nowUtc.subtract(const Duration(days: 1)));

        // Si déjà comptabilisé aujourd'hui → ne rien ajouter, mais sécuriser serieMaximum
        if (jours.contains(todayKey)) {
          // Dédupliquer/ordonner proprement
          final List<String> normalized = _normalizeDays(jours);
          final int fixedBest = currentStreak > bestStreak ? currentStreak : bestStreak;
          txn.update(userRef, {
            'serie.derniersJoursActifs': normalized,
            'serie.serieEnCours': currentStreak,
            'serie.serieMaximum': fixedBest,
          });
          return;
        }

        // Calculer la dernière date d'activité (si existante)
        String? lastDay;
        if (jours.isNotEmpty) {
          // Les clés sont de type yyyy-MM-dd: prendre le max lexicographique
          final List<String> sorted = List<String>.from(jours)..sort();
          lastDay = sorted.last;
        }

        int newStreak;
        if (lastDay == yesterdayKey) {
          newStreak = currentStreak + 1;
        } else {
          // Soit première activité, soit trou de >= 1 jour
          newStreak = 1;
        }

        // Ajouter aujourd'hui, dédupliquer, trier et borner
        final List<String> updatedDays = _normalizeDays(<String>{...jours, todayKey}.toList());
        final int updatedBest = newStreak > bestStreak ? newStreak : bestStreak;
        txn.update(userRef, {
          'serie.derniersJoursActifs': updatedDays,
          'serie.serieEnCours': newStreak,
          'serie.serieMaximum': updatedBest,
        });
      });
      if (kDebugMode) {
        debugPrint('🔥 StreakService: activité du jour enregistrée pour $uid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ StreakService.registerActivityToday erreur: $e');
      }
      // ne pas propager: c'est non-bloquant
    }
  }

  static List<String> _normalizeDays(List<String> raw) {
    final Set<String> unique = raw
        .where((e) => e.trim().isNotEmpty)
        .map((e) => e.trim())
        .toSet();
    final List<String> sorted = unique.toList()..sort();
    // Conserver les 60 plus récents
    final int keep = 60;
    if (sorted.length <= keep) return sorted;
    return sorted.sublist(sorted.length - keep);
  }

  static String _formatDayKey(DateTime dtUtc) {
    // dtUtc est supposé en UTC
    final int y = dtUtc.year;
    final int m = dtUtc.month;
    final int d = dtUtc.day;
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '$y-${two(m)}-${two(d)}';
  }
}



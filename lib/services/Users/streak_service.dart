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
        final data = snap.data() ?? <String, dynamic>{};
        final Map<String, dynamic> serie = (data['serie'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final List<String> jours = ((serie['derniersJoursActifs'] as List<dynamic>?)?.map((e) => e.toString()).toList()) ?? <String>[];
        final int bestStreak = (serie['serieMaximum'] as int?) ?? 0;

        final DateTime nowUtc = DateTime.now().toUtc();
        final String todayKey = _formatDayKey(nowUtc);
        final String yesterdayKey = _formatDayKey(nowUtc.subtract(const Duration(days: 1)));

        // Construit toujours une liste de jours consécutifs TERMINANT aujourd'hui
        // Si aujourd'hui est déjà présent, on recalculera quand même la queue consécutive

        // Calculer la dernière date d'activité (si existante)
        String? lastDay;
        if (jours.isNotEmpty) {
          // Les clés sont de type yyyy-MM-dd: prendre le max lexicographique
          final List<String> sorted = List<String>.from(jours)..sort();
          lastDay = sorted.last;
        }

        List<String> updatedDays;
        int newStreak;
        if (jours.contains(todayKey)) {
          // Déjà comptabilisé aujourd'hui → extraire la queue consécutive finissant aujourd'hui
          updatedDays = _consecutiveTailEndingAt(jours, todayKey);
          newStreak = updatedDays.length;
        } else if (lastDay == yesterdayKey) {
          // Continuité: repartir de la queue finissant hier, puis ajouter aujourd'hui
          final List<String> tail = _consecutiveTailEndingAt(jours, yesterdayKey);
          updatedDays = [...tail, todayKey];
          newStreak = updatedDays.length;
        } else {
          // Rupture: repartir à aujourd'hui uniquement
          updatedDays = [todayKey];
          newStreak = 1;
        }

        // Borne (sécurité) même si on ne conserve que la queue consécutive
        updatedDays = _normalizeDays(updatedDays);
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

  /// Extrait la queue de jours consécutifs se terminant par endKey (inclus).
  /// Si endKey n'est pas présent, renvoie [].
  static List<String> _consecutiveTailEndingAt(List<String> days, String endKey) {
    if (!days.contains(endKey)) return <String>[];
    final List<String> sorted = List<String>.from(days)..sort();
    // Remonter à partir de endKey vers l'arrière tant que les jours sont consécutifs
    final int endIndex = sorted.lastIndexOf(endKey);
    final List<String> tail = <String>[];
    if (endIndex < 0) return tail;
    DateTime prev = _parseDayKey(sorted[endIndex]);
    tail.insert(0, sorted[endIndex]);
    for (int i = endIndex - 1; i >= 0; i--) {
      final DateTime d = _parseDayKey(sorted[i]);
      if (prev.difference(d).inDays == 1) {
        tail.insert(0, sorted[i]);
        prev = d;
      } else {
        break;
      }
    }
    return tail;
  }

  static DateTime _parseDayKey(String key) {
    final parts = key.split('-');
    final int y = int.parse(parts[0]);
    final int m = int.parse(parts[1]);
    final int d = int.parse(parts[2]);
    return DateTime.utc(y, m, d);
  }

  static String _formatDayKey(DateTime dtUtc) {
    // dtUtc est supposé en UTC
    final int y = dtUtc.year;
    final int m = dtUtc.month;
    final int d = dtUtc.day;
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '$y-${two(m)}-${two(d)}';
  }

  /// Normalise la série existante pour ne conserver que la série en cours
  /// (queue de jours consécutifs se terminant au dernier jour d'activité).
  static Future<void> normalizeCurrentStreak(String uid) async {
    try {
      final ref = _firestore.collection('utilisateurs').doc(uid);
      await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? <String, dynamic>{};
        final Map<String, dynamic> serie = (data['serie'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        final List<String> jours = ((serie['derniersJoursActifs'] as List<dynamic>?)?.map((e) => e.toString()).toList()) ?? <String>[];
        final int bestStreak = (serie['serieMaximum'] as int?) ?? 0;
        if (jours.isEmpty) {
          txn.set(ref, {
            'serie': {
              'derniersJoursActifs': <String>[],
              'serieEnCours': 0,
              'serieMaximum': bestStreak,
            }
          }, SetOptions(merge: true));
          return;
        }
        final List<String> sorted = List<String>.from(jours)..sort();
        final String last = sorted.last;
        final List<String> tail = _consecutiveTailEndingAt(sorted, last);
        final int current = tail.length;
        txn.update(ref, {
          'serie.derniersJoursActifs': _normalizeDays(tail),
          'serie.serieEnCours': current,
          'serie.serieMaximum': current > bestStreak ? current : bestStreak,
        });
      });
    } catch (e) {
      if (kDebugMode) debugPrint('❌ normalizeCurrentStreak erreur: $e');
    }
  }
}



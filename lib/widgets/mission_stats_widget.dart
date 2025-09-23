import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/Mission/communs/commun_gestion_mission.dart';

/// Widget pour afficher les statistiques d'une mission
class MissionStatsWidget extends StatefulWidget {
  final String missionId;
  final String missionName;

  const MissionStatsWidget({
    super.key,
    required this.missionId,
    required this.missionName,
  });

  @override
  State<MissionStatsWidget> createState() => _MissionStatsWidgetState();
}

class _MissionStatsWidgetState extends State<MissionStatsWidget> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final stats = await MissionManagementService.getMissionStats(widget.missionId);
      
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du chargement des stats: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'Aucune statistique disponible',
              style: TextStyle(
                fontFamily: 'Quicksand',
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec nom de la mission
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: const Color(0xFF6A994E),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Statistiques - ${widget.missionName}',
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF344356),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grille des statistiques principales
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Étoiles',
                    '${_stats!['etoiles'] ?? 0}/3',
                    Icons.star,
                    const Color(0xFFFEC868),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Tentatives',
                    '${_stats!['tentatives'] ?? 0}',
                    Icons.replay,
                    const Color(0xFF6A994E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Meilleur Score',
                    '${_stats!['meilleurScore'] ?? 0}%',
                    Icons.trending_up,
                    const Color(0xFFBC4749),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Moyenne',
                    '${_stats!['moyenneScores'] ?? 0}%',
                    Icons.analytics,
                    const Color(0xFF386641),
                  ),
                ),
              ],
            ),

            // Statistiques détaillées
            if (_stats!['tentatives'] != null && (_stats!['tentatives'] as int) > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Dernière partie
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dernière partie: ${_stats!['dernierePartieLe'] != null ? _formatDate(_stats!['dernierePartieLe']) : 'N/A'}',
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),

              // Temps moyen
              if (_stats!['tempsMoyen'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.timer,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Temps moyen: ${_stats!['tempsMoyen']}s',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],

              // Taux de réussite
              if (_stats!['tauxReussite'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Taux de réussite: ${_stats!['tauxReussite']}%',
                      style: const TextStyle(
                        fontFamily: 'Quicksand',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Quicksand',
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'N/A';
  }
}

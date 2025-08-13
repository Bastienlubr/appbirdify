import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_sync_service.dart';
import '../services/user_profile_service.dart';
import '../theme/colors.dart';

/// Widget complet pour afficher le profil utilisateur
/// Utilise la synchronisation en temps réel
class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({super.key});

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  bool _isLoading = true;
  bool _isEditing = false;
  
  // Contrôleurs pour l'édition
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Initialise le profil et démarre la synchronisation
  Future<void> _initializeProfile() async {
    try {
      // Démarrer la synchronisation
      await UserSyncService.startSync();
      
      // Ajouter des callbacks pour les mises à jour
      UserSyncService.addProfileCallback(() {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
      
      // Charger les données initiales
      _loadInitialData();
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Erreur lors du chargement du profil: $e');
      }
    }
  }

  /// Charge les données initiales
  void _loadInitialData() {
    final profile = UserSyncService.currentProfile;
    if (profile != null) {
      _nameController.text = profile['profil']?['nomAffichage'] ?? '';
      _emailController.text = profile['profil']?['email'] ?? '';
    }
  }

  /// Affiche un message d'erreur
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Sauvegarde les modifications du profil
  Future<void> _saveProfile() async {
    try {
      final user = UserSyncService.currentProfile;
      if (user == null) return;

      await UserProfileService.createOrUpdateUserProfile(
        uid: user['uid'] ?? '',
        displayName: _nameController.text,
        email: _emailController.text,
      );

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sauvegarde: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return StreamBuilder<Map<String, dynamic>?>(
      stream: UserSyncService.profileStream,
      builder: (context, snapshot) {
        final profile = snapshot.data ?? UserSyncService.currentProfile;
        
        if (profile == null) {
          return const Center(
            child: Text('Aucun profil trouvé'),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(profile),
              const SizedBox(height: 24),
              _buildStatsGrid(profile),
              const SizedBox(height: 24),
              _buildFavoritesSection(),
              const SizedBox(height: 24),
              _buildBadgesSection(),
              const SizedBox(height: 24),
              _buildMissionProgressSection(),
              const SizedBox(height: 24),
              _buildRecentSessionsSection(),
            ],
          ),
        );
      },
    );
  }

  /// En-tête du profil avec avatar et informations de base
  Widget _buildHeader(Map<String, dynamic> profile) {
    final profil = profile['profil'] ?? {};
            // final totaux = profile['totaux'] ?? {}; // Variable non utilisée
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: profil['urlAvatar'] != null
                  ? ClipOval(
                      child: Image.network(
                        profil['urlAvatar'],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
            ),
            
            const SizedBox(width: 20),
            
            // Informations du profil
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isEditing) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'affichage',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(
                      profil['nomAffichage'] ?? 'Utilisateur',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profil['email'] ?? '',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Boutons d'action
                  Row(
                    children: [
                      if (_isEditing) ...[
                        ElevatedButton(
                          onPressed: _saveProfile,
                          child: const Text('Sauvegarder'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = false;
                              _loadInitialData();
                            });
                          },
                          child: const Text('Annuler'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifier'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grille des statistiques principales
  Widget _buildStatsGrid(Map<String, dynamic> profile) {
    final totaux = profile['totaux'] ?? {};
    final vies = profile['vies'] ?? {};
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Niveau',
          '${totaux['niveau'] ?? 1}',
          Icons.star,
          AppColors.primary,
        ),
        _buildStatCard(
          'XP Total',
          '${totaux['xpTotal'] ?? 0}',
          Icons.trending_up,
          AppColors.secondary,
        ),
        _buildStatCard(
          'Score Total',
          '${totaux['scoreTotal'] ?? 0}',
          Icons.score,
          AppColors.accent,
        ),
        _buildStatCard(
          'Vies',
          '${vies['compte'] ?? 5}/${vies['max'] ?? 5}',
          Icons.favorite,
          Colors.red,
        ),
      ],
    );
  }

  /// Carte de statistique individuelle
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Section des oiseaux favoris
  Widget _buildFavoritesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Oiseaux Favoris',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${UserSyncService.currentFavorites.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<String>>(
              stream: UserSyncService.favoritesStream,
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? UserSyncService.currentFavorites;
                
                if (favorites.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Aucun oiseau favori pour le moment',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: favorites.take(6).map((oiseauId) {
                    return Chip(
                      label: Text(oiseauId),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Section des badges
  Widget _buildBadgesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Badges',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${UserSyncService.currentBadges.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: UserSyncService.badgesStream,
              builder: (context, snapshot) {
                final badges = snapshot.data ?? UserSyncService.currentBadges;
                
                if (badges.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Aucun badge débloqué pour le moment',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: badges.take(8).map((badge) {
                    final niveau = badge['niveau'] ?? 'bronze';
                    Color badgeColor;
                    
                    switch (niveau) {
                      case 'diamant':
                        badgeColor = Colors.cyan;
                        break;
                      case 'or':
                        badgeColor = Colors.amber;
                        break;
                      case 'argent':
                        badgeColor = Colors.grey;
                        break;
                      default:
                        badgeColor = Colors.brown;
                    }
                    
                    return Chip(
                      avatar: Icon(
                        Icons.emoji_events,
                        color: badgeColor,
                        size: 16,
                      ),
                      label: Text(badge['badgeId'] ?? ''),
                      backgroundColor: badgeColor.withValues(alpha: 0.1),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Section de la progression des missions
  Widget _buildMissionProgressSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: AppColors.secondary),
                const SizedBox(width: 8),
                Text(
                  'Progression des Missions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${UserSyncService.completedMissionsCount}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: UserSyncService.missionProgressStream,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? UserSyncService.currentMissionProgress;
                
                if (progress.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Aucune mission commencée pour le moment',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: progress.take(5).map((mission) {
                    final idMission = mission['idMission'] ?? '';
                    final etoiles = mission['etoiles'] ?? 0;
                    final score = mission['meilleurScore'] ?? 0;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          idMission,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text('Mission $idMission'),
                      subtitle: Text('Score: $score%'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          return Icon(
                            index < etoiles ? Icons.star : Icons.star_border,
                            color: index < etoiles ? Colors.amber : Colors.grey,
                            size: 20,
                          );
                        }),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Section des sessions récentes
  Widget _buildRecentSessionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  'Sessions Récentes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${UserSyncService.currentSessions.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: UserSyncService.sessionsStream,
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? UserSyncService.currentSessions;
                
                if (sessions.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'Aucune session pour le moment',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
                
                return Column(
                  children: sessions.take(5).map((session) {
                    final missionId = session['idMission'] ?? '';
                    final score = session['score'] ?? 0;
                    final total = session['totalQuestions'] ?? 0;
                    final pourcentage = session['pourcentage'] ?? 0;
                    final date = session['termineLe'] != null
                        ? (session['termineLe'] as Timestamp).toDate()
                        : DateTime.now();
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: pourcentage >= 80
                            ? Colors.green
                            : pourcentage >= 60
                                ? Colors.orange
                                : Colors.red,
                        child: Text(
                          '$pourcentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text('Mission $missionId'),
                      subtitle: Text(
                        'Score: $score/$total • ${_formatDate(date)}',
                      ),
                      trailing: Icon(
                        pourcentage >= 80
                            ? Icons.check_circle
                            : pourcentage >= 60
                                ? Icons.warning
                                : Icons.error,
                        color: pourcentage >= 80
                            ? Colors.green
                            : pourcentage >= 60
                                ? Colors.orange
                                : Colors.red,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Formate une date pour l'affichage
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Il y a ${difference.inMinutes} min';
      }
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

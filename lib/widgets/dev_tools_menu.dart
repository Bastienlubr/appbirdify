import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/dev_tools_service.dart';
import '../theme/colors.dart';
import '../services/Mission/communs/commun_persistance_consultation.dart';
import '../pages/auth/login_screen.dart';
import '../pages/RecompensesUtiles/test_recompenses_access.dart';
import '../pages/RecompensesUtiles/recompenses_utiles_page.dart';
import '../services/Users/recompenses_utiles_service.dart';

class DevToolsMenu extends StatefulWidget {
  final VoidCallback? onLivesRestored;
  final VoidCallback? onStarsReset;
  
  const DevToolsMenu({super.key, this.onLivesRestored, this.onStarsReset});

  @override
  State<DevToolsMenu> createState() => _DevToolsMenuState();
}

class _DevToolsMenuState extends State<DevToolsMenu> {
  Map<String, dynamic>? _userInfo;
  int _unlockedMissions = 0;
  int _totalStars = 0;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    if (!kDebugMode) return;
    
    try {
      _userInfo = await DevToolsService.getCurrentUserInfo();
      _unlockedMissions = await DevToolsService.getUnlockedMissionsCount();
      _totalStars = await DevToolsService.getTotalStars();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Erreur lors du chargement des infos: $e');
      }
    }
  }

  void _showDevToolsPopup() {
    if (!kDebugMode) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return _DevToolsPopup(
          userInfo: _userInfo,
          unlockedMissions: _unlockedMissions,
          totalStars: _totalStars,
          onAction: () {
            Navigator.of(context).pop();
            _loadUserInfo(); // Recharger les infos après action
          },
          onLivesRestored: widget.onLivesRestored,
          onStarsReset: widget.onStarsReset,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    
    return Positioned(
      top: 20,
      left: 20,
      child: GestureDetector(
        onTap: _showDevToolsPopup,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.developer_mode,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _DevToolsPopup extends StatefulWidget {
  final Map<String, dynamic>? userInfo;
  final int unlockedMissions;
  final int totalStars;
  final VoidCallback onAction;
  final VoidCallback? onLivesRestored;
  final VoidCallback? onStarsReset;

  const _DevToolsPopup({
    required this.userInfo,
    required this.unlockedMissions,
    required this.totalStars,
    required this.onAction,
    this.onLivesRestored,
    this.onStarsReset,
  });

  @override
  State<_DevToolsPopup> createState() => _DevToolsPopupState();
}

class _DevToolsPopupState extends State<_DevToolsPopup> {
  bool _isLoading = false;

  Future<void> _handleSignOut() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await DevToolsService.signOut();
      if (!mounted) return;
      // Naviguer vers l'écran de connexion et vider la pile de navigation
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _executeAction(Future<void> Function() action) async {
    if (kDebugMode) {
      debugPrint('🔄 Exécution d\'une action dans DevTools...');
    }
    
    setState(() => _isLoading = true);
    
    try {
      if (kDebugMode) {
        debugPrint('   ⏳ Action en cours...');
      }
      
      await action();
      
      if (kDebugMode) {
        debugPrint('   ✅ Action terminée avec succès');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Action exécutée avec succès'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Recharger les infos après l'action
        if (mounted) {
          widget.onAction();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('   ❌ Erreur lors de l\'exécution: $e');
        debugPrint('   📍 Stack trace: ${StackTrace.current}');
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (kDebugMode) {
          debugPrint('   🔄 État de chargement remis à false');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.developer_mode,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '🛠️ Outils de Développement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Quicksand',
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informations utilisateur
                    _buildInfoSection(),
                    const SizedBox(height: 20),
                    
                    // Actions principales
                    _buildActionSection(),
                    const SizedBox(height: 20),
                    
                    // Actions de déverrouillage
                    _buildUnlockSection(),
                    const SizedBox(height: 20),
                    
                    // Actions de restauration
                    _buildResetSection(),
                    const SizedBox(height: 20),
                    
                    // Test des badges NOUVEAU
                    _buildBadgeTestSection(),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Fermer',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontFamily: 'Quicksand',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _handleSignOut,
                    child: const Text(
                      '🚪 Déconnexion',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 16,
                        fontFamily: 'Quicksand',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 Informations Utilisateur',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Quicksand',
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('👤 Email', widget.userInfo?['profil']?['email'] ?? 'N/A'),
          _buildInfoRow('🎯 Missions déverrouillées', '${widget.unlockedMissions}'),
          _buildInfoRow('⭐ Total étoiles', '${widget.totalStars}'),
          _buildInfoRow(
            '💚 Vies restantes',
            '${widget.userInfo?['vie']?['vieRestante'] ?? 'N/A'}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontFamily: 'Quicksand',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black,
              fontFamily: 'Quicksand',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚡ Actions Rapides',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Quicksand',
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.favorite,
          label: '💚 Restaurer 5 vies',
          onPressed: () => _executeAction(() async {
            await DevToolsService.restoreLives();
            // Appeler le callback pour forcer le rechargement des vies
            if (widget.onLivesRestored != null) {
              if (kDebugMode) debugPrint('🔄 Appel du callback de rechargement des vies...');
              widget.onLivesRestored!();
            }
          }),
        ),
        _buildActionButton(
          icon: Icons.all_inclusive,
          label: '♾️ Activer vies infinies (compte courant)',
          onPressed: () => _executeAction(() async {
            await DevToolsService.setInfiniteLives(true);
            if (widget.onLivesRestored != null) widget.onLivesRestored!();
          }),
        ),
        _buildActionButton(
          icon: Icons.favorite_border,
          label: '💚 Ajouter 1 vie (sans dépasser max)',
          onPressed: () => _executeAction(() async {
            await DevToolsService.addOneLife();
            if (widget.onLivesRestored != null) widget.onLivesRestored!();
          }),
        ),
        _buildActionButton(
          icon: Icons.block,
          label: '⛔ Désactiver vies infinies',
          onPressed: () => _executeAction(() async {
            await DevToolsService.setInfiniteLives(false);
            if (widget.onLivesRestored != null) widget.onLivesRestored!();
          }),
        ),
        _buildActionButton(
          icon: Icons.add_circle,
          label: '➕ Augmenter vieMaximum (+1)',
          onPressed: () => _executeAction(() async {
            final info = await DevToolsService.getCurrentUserInfo();
            final current = (info?['vie']?['vieMaximum'] as int? ?? 5).clamp(1, 50);
            await DevToolsService.setMaxLives((current + 1).clamp(1, 50));
            if (widget.onLivesRestored != null) widget.onLivesRestored!();
          }),
        ),
        _buildActionButton(
          icon: Icons.restore,
          label: '↩️ Réinitialiser vieMaximum à 5',
          onPressed: () => _executeAction(() async {
            await DevToolsService.resetMaxLivesToFive();
            if (widget.onLivesRestored != null) widget.onLivesRestored!();
          }),
        ),
        
        _buildActionButton(
          icon: Icons.star,
          label: '🏆 Tester page Récompenses',
          onPressed: () {
            Navigator.of(context).pop(); // Fermer le popup d'abord
            TestRecompensesAccess.showRecompensesPage(context);
          },
        ),
        _buildActionButton(
          icon: Icons.star,
          label: '⭐ Simuler 1 étoile',
          onPressed: () async {
            // Fermer le popup sans attendre pour conserver un context valide
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
            // Déférer la suite après fermeture du dialog (évite d'utiliser le même BuildContext après await)
            Future<void>(() async {
              final service = RecompensesUtilesService();
              await service.simulerEtoiles(TypeEtoile.uneEtoile);
              if (kDebugMode) debugPrint('🌟 Simulation 1 étoile terminée');
              // Utiliser le navigator capturé pour éviter d'utiliser BuildContext après un await
              navigator.push(
                MaterialPageRoute(builder: (_) => const RecompensesUtilesPage()),
              );
            });
          },
        ),
        _buildActionButton(
          icon: Icons.star,
          label: '⭐⭐ Simuler 2 étoiles',
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
            Future<void>(() async {
              final service = RecompensesUtilesService();
              await service.simulerEtoiles(TypeEtoile.deuxEtoiles);
              if (kDebugMode) debugPrint('🌟 Simulation 2 étoiles terminée');
              navigator.push(
                MaterialPageRoute(builder: (_) => const RecompensesUtilesPage()),
              );
            });
          },
        ),
        _buildActionButton(
          icon: Icons.star,
          label: '⭐⭐⭐ Simuler 3 étoiles',
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
            Future<void>(() async {
              final service = RecompensesUtilesService();
              await service.simulerEtoiles(TypeEtoile.troisEtoiles);
              if (kDebugMode) debugPrint('🌟 Simulation 3 étoiles terminée');
              navigator.push(
                MaterialPageRoute(builder: (_) => const RecompensesUtilesPage()),
              );
            });
          },
        ),
      ],
    );
  }

  Widget _buildUnlockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔓 Déverrouillage des Missions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Quicksand',
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.lock_open,
          label: '🔓 Déverrouiller TOUTES les missions',
          onPressed: () => _executeAction(DevToolsService.unlockAllMissions),
        ),
        _buildActionButton(
          icon: Icons.star,
          label: '⭐ Déverrouiller TOUTES les étoiles (3★ partout)',
          onPressed: () => _executeAction(() async {
            await DevToolsService.unlockAllStars();
            // Appeler le callback pour forcer le rechargement des étoiles
            if (widget.onStarsReset != null) {
              if (kDebugMode) debugPrint('🔄 Appel du callback de rechargement des étoiles...');
              widget.onStarsReset!();
            }
          }),
        ),
      ],
    );
  }

  Widget _buildResetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔄 Restauration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Quicksand',
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.star_border,
          label: '⭐ Remettre toutes les étoiles à 0',
          onPressed: () {
            if (kDebugMode) {
              debugPrint('🎯 Bouton "Remettre étoiles à 0" cliqué !');
            }
            _executeAction(() async {
              await DevToolsService.resetAllStars();
              // Appeler le callback pour forcer le rechargement des missions
              if (widget.onStarsReset != null) {
                if (kDebugMode) debugPrint('🔄 Appel du callback de rechargement des étoiles...');
                widget.onStarsReset!();
              }
            });
          },
          isDestructive: true,
        ),
      ],
    );
  }
  
  Widget _buildBadgeTestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏷️ Test Badges NOUVEAU',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Quicksand',
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.visibility,
          label: '🔍 Afficher missions consultées',
          onPressed: () {
            _executeAction(() async {
              await MissionPersistenceService.debugConsultedMissions();
            });
          },
        ),
        _buildActionButton(
          icon: Icons.refresh,
          label: '🔄 Réinitialiser statut consulté (U02)',
          onPressed: () {
            _executeAction(() async {
              await MissionPersistenceService.clearMissionConsultedStatus('U02');
              if (kDebugMode) debugPrint('🔄 Statut consulté réinitialisé pour U02');
            });
          },
        ),
        _buildActionButton(
          icon: Icons.refresh,
          label: '🔄 Réinitialiser statut consulté (F02)',
          onPressed: () {
            _executeAction(() async {
              await MissionPersistenceService.clearMissionConsultedStatus('F02');
              if (kDebugMode) debugPrint('🔄 Statut consulté réinitialisé pour F02');
            });
          },
        ),
        _buildActionButton(
          icon: Icons.clear_all,
          label: '🗑️ Effacer toutes les missions consultées',
          onPressed: () {
            _executeAction(() async {
              await MissionPersistenceService.clearConsultedMissions();
              if (kDebugMode) debugPrint('🗑️ Toutes les missions consultées ont été effacées');
            });
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () {
          if (kDebugMode) {
            debugPrint('🔘 Bouton cliqué - État loading: $_isLoading');
          }
          onPressed();
        },
        icon: Icon(
          icon,
          color: isDestructive ? Colors.white : AppColors.primary,
          size: 20,
        ),
        label: Text(
          label,
          style: TextStyle(
            color: isDestructive ? Colors.white : Colors.black87,
            fontSize: 14,
            fontFamily: 'Quicksand',
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDestructive ? Colors.red : Colors.grey[100],
          foregroundColor: isDestructive ? Colors.white : AppColors.primary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

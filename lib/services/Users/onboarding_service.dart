import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuestionnaireService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _userCollection = 'utilisateurs';
  static const String _questionnaireSub = 'Questionnaire';
  static const String _primaryDocId = 'initial';

  /// Retourne true si l'utilisateur doit encore compléter le questionnaire
  static Future<bool> needsOnboarding() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // 1) Nouveau stockage: sous-collection `Questionnaire/initial`
    final docSub = await _db
        .collection(_userCollection)
        .doc(user.uid)
        .collection(_questionnaireSub)
        .doc(_primaryDocId)
        .get();
    final dataSub = docSub.data();
    if (dataSub != null) {
      final completed = dataSub['completed'] == true;
      return !completed;
    }

    // 2) Rétrocompat: ancien champ imbriqué `onboarding`
    final doc = await _db.collection(_userCollection).doc(user.uid).get();
    final data = doc.data();
    if (data == null) return true;
    final onboarding = data['onboarding'] as Map<String, dynamic>?;
    final completed = onboarding != null && onboarding['completed'] == true;
    return !completed;
  }

  /// Enregistre les réponses dans `utilisateurs/<uid>/Questionnaire/initial`
  /// et marque également le champ parent `onboarding.completed` pour rétrocompatibilité.
  static Future<void> saveOnboarding({
    required String heardFrom,
    required String level,
    required String weeklyCommitment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final userRef = _db.collection(_userCollection).doc(user.uid);

    // Écriture principale: sous-collection dédiée
    await userRef
        .collection(_questionnaireSub)
        .doc(_primaryDocId)
        .set({
      'heardFrom': heardFrom,
      'level': level,
      'weeklyCommitment': weeklyCommitment,
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Rétrocompatibilité: conserver le flag dans le doc parent
    await userRef.set({
      'onboarding': {
        'heardFrom': heardFrom,
        'level': level,
        'weeklyCommitment': weeklyCommitment,
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }
}



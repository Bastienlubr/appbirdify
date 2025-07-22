import 'package:flutter_test/flutter_test.dart';
import 'package:appbirdify/services/mission_loader.dart';

void main() {
  group('MissionLoader Tests', () {
    test('loadMissionTitles should load titles from CSV', () async {
      // Test avec un fichier CSV existant
      final titles = await MissionLoader.loadMissionTitles('U01 - template_mission_quiz.csv');
      
      expect(titles, isNotNull);
      expect(titles!['titreMission'], isNotEmpty);
      expect(titles['titreMission'], equals('Les résidents du matin'));
      expect(titles['sousTitre'], equals('Ah bon! les oiseaux sont matinal ?!'));
    });

    test('loadAllMissions should return sorted missions', () async {
      final missions = await MissionLoader.loadAllMissions();
      
      expect(missions, isNotEmpty);
      
      // Vérifier que les missions sont triées par milieu puis par index
      for (int i = 0; i < missions.length - 1; i++) {
        final current = missions[i];
        final next = missions[i + 1];
        
        // Si même milieu, vérifier que l'index est croissant
        if (current.milieu == next.milieu) {
          expect(current.index, lessThanOrEqualTo(next.index));
        }
      }
    });

    test('loadMissionsForMilieu should return missions for specific milieu', () async {
      final urbainMissions = await MissionLoader.loadMissionsForMilieu('urbain');
      
      expect(urbainMissions, isNotEmpty);
      expect(urbainMissions.every((m) => m.milieu == 'urbain'), isTrue);
      
      // Vérifier que les missions sont triées par index
      for (int i = 0; i < urbainMissions.length - 1; i++) {
        expect(urbainMissions[i].index, lessThanOrEqualTo(urbainMissions[i + 1].index));
      }
    });

    test('Mission properties should be correctly set', () async {
      final missions = await MissionLoader.loadAllMissions();
      
      for (final mission in missions) {
        expect(mission.id, isNotEmpty);
        expect(mission.milieu, isNotEmpty);
        expect(mission.index, greaterThan(0));
        expect(mission.status, equals('available'));
        expect(mission.csvFile, isNotEmpty);
        expect(mission.titreMission, isNotEmpty);
        expect(mission.lastStarsEarned, equals(0));
      }
    });
  });
} 
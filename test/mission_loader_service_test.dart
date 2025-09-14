import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:appbirdify/services/Mission/communs/commun_chargeur_missions.dart';
import 'package:appbirdify/models/mission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MissionLoaderService Tests - Import CSV', () {
    
    group('loadMissionsFromCsv', () {
      test('devrait charger correctement les missions depuis le CSV', () async {
        // Arrange
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Les résidents du matin,Ah bon ! Les oiseaux sont matinal ?!,urbain,1,TRUE,0,0,assets/Missionhome/questionMission/U01.csv,Missionhome/Images/U01.png
F01,La voix de la canopée,Là-haut c'est un concert permanent,forestier,1,FALSE,0,0,assets/Missionhome/questionMission/F01.csv,Missionhome/Images/F01.png''';

        // Mock du rootBundle
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsFromCsv();

        // Assert
        expect(result, isA<Map<String, List<Mission>>>());
        expect(result.length, 2); // 2 biomes
        expect(result['urbain'], isNotNull);
        expect(result['forestier'], isNotNull);
        
        // Vérifier la mission urbaine
        final missionUrbaine = result['urbain']!.first;
        expect(missionUrbaine.id, 'U01');
        expect(missionUrbaine.title, 'Les résidents du matin');
        expect(missionUrbaine.milieu, 'urbain');
        expect(missionUrbaine.index, 1);
        expect(missionUrbaine.status, 'available'); // TRUE dans le CSV
        expect(missionUrbaine.iconUrl, 'assets/Missionhome/Images/U01.png');

        // Vérifier la mission forestière
        final missionForestiere = result['forestier']!.first;
        expect(missionForestiere.id, 'F01');
        expect(missionForestiere.title, 'La voix de la canopée');
        expect(missionForestiere.milieu, 'forestier');
        expect(missionForestiere.index, 1);
        expect(missionForestiere.status, 'locked'); // FALSE dans le CSV
      });

      test('devrait gérer les erreurs de parsing CSV', () async {
        // Arrange - CSV avec des données manquantes
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,,Ah bon ! Les oiseaux sont matinal ?!,urbain,1,TRUE,0,0,assets/Missionhome/questionMission/U01.csv,Missionhome/Images/U01.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act & Assert
        expect(
          () => MissionLoaderService.loadMissionsFromCsv(),
          throwsA(isA<Exception>()),
        );
      });

      test('devrait gérer les valeurs par défaut pour les champs optionnels', () async {
        // Arrange - CSV avec des valeurs manquantes pour les champs optionnels
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Test Mission,Description test,urbain,,,0,0,assets/Missionhome/questionMission/U01.csv,Missionhome/Images/U01.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsFromCsv();

        // Assert
        final mission = result['urbain']!.first;
        expect(mission.index, 0); // Valeur par défaut
        expect(mission.status, 'locked'); // Valeur par défaut pour deverrouillee
        expect(mission.lastStarsEarned, 0); // Valeur par défaut
      });

      test('devrait corriger automatiquement les chemins d\'images', () async {
        // Arrange - CSV avec des chemins d'images sans 'assets/'
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Test Mission,Description test,urbain,1,TRUE,0,0,test.csv,Images/test.png
U02,Test Mission 2,Description test,urbain,2,TRUE,0,0,test2.csv,assets/Images/test2.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsFromCsv();

        // Assert
        final mission1 = result['urbain']!.first;
        expect(mission1.iconUrl, 'assets/Images/test.png'); // Correction automatique

        final mission2 = result['urbain']!.last;
        expect(mission2.iconUrl, 'assets/Images/test2.png'); // Déjà correct
      });

      test('devrait organiser les missions par biome', () async {
        // Arrange - CSV avec plusieurs biomes
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Test Urbain 1,Description urbain,urbain,1,TRUE,0,0,test1.csv,test1.png
U02,Test Urbain 2,Description urbain,urbain,2,TRUE,0,0,test2.csv,test2.png
F01,Test Forestier 1,Description forestier,forestier,1,TRUE,0,0,test3.csv,test3.png
A01,Test Agricole 1,Description agricole,agricole,1,TRUE,0,0,test4.csv,test4.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsFromCsv();

        // Assert
        expect(result.length, 3); // 3 biomes
        expect(result['urbain']!.length, 2);
        expect(result['forestier']!.length, 1);
        expect(result['agricole']!.length, 1);
        
        // Vérifier que les missions sont dans le bon biome
        expect(result['urbain']!.every((m) => m.milieu == 'urbain'), true);
        expect(result['forestier']!.every((m) => m.milieu == 'forestier'), true);
        expect(result['agricole']!.every((m) => m.milieu == 'agricole'), true);
      });
    });

    group('loadMissionsForBiome', () {
      test('devrait charger les missions d\'un biome spécifique', () async {
        // Arrange
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Test Mission 1,Description test,urbain,1,TRUE,0,0,test1.csv,test1.png
U02,Test Mission 2,Description test,urbain,2,FALSE,0,0,test2.csv,test2.png
F01,Test Mission 3,Description test,forestier,1,TRUE,0,0,test3.csv,test3.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsForBiome('urbain');

        // Assert
        expect(result.length, 2);
        expect(result.first.id, 'U01'); // Trié par niveau
        expect(result.last.id, 'U02');
        expect(result.every((m) => m.milieu == 'urbain'), true);
      });

      test('devrait retourner une liste vide pour un biome inexistant', () async {
        // Arrange
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url
U01,Test Mission 1,Description test,urbain,1,TRUE,0,0,test1.csv,test1.png''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act
        final result = await MissionLoaderService.loadMissionsForBiome('biome_inexistant');

        // Assert
        expect(result, isEmpty);
      });
    });

    group('ProgressionMission', () {
      test('devrait créer une progression par défaut', () {
        // Act
        final progression = ProgressionMission.defaultProgression();

        // Assert
        expect(progression.etoiles, 0);
        expect(progression.meilleurScore, 0);
        expect(progression.tentatives, 0);
        expect(progression.deverrouille, false);
        expect(progression.dernierePartieLe, null);
      });

      test('devrait convertir en Map', () {
        // Arrange
        final progression = ProgressionMission(
          etoiles: 2,
          meilleurScore: 80,
          tentatives: 3,
          deverrouille: true,
          dernierePartieLe: DateTime.now(),
        );

        // Act
        final map = progression.toMap();

        // Assert
        expect(map['etoiles'], 2);
        expect(map['meilleurScore'], 80);
        expect(map['tentatives'], 3);
        expect(map['deverrouille'], true);
        expect(map['dernierePartieLe'], isNotNull);
      });
    });

    group('Gestion des erreurs CSV', () {
      test('devrait gérer un fichier CSV vide', () async {
        // Arrange
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act & Assert
        expect(
          () => MissionLoaderService.loadMissionsFromCsv(),
          throwsA(isA<Exception>()),
        );
      });

      test('devrait gérer un fichier CSV avec seulement l\'en-tête', () async {
        // Arrange
        const csvData = '''id_mission,titre,description,biome,niveau,deverrouillee,etoiles,dernier_score,csv_url,image_url''';

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/services'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'loadString') {
              return csvData;
            }
            return null;
          },
        );

        // Act & Assert
        expect(
          () => MissionLoaderService.loadMissionsFromCsv(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

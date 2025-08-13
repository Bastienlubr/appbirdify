import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccount = JSON.parse(
  readFileSync(resolve(__dirname, '../serviceAccountKey.json'), 'utf8')
);

const app = initializeApp({
  credential: cert(serviceAccount)
});

const db = getFirestore(app);

function parseCSV(filePath) {
  const content = readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  const headers = lines[0].split(',').map(h => h.trim());

  const data = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = lines[i].split(',').map(v => v.trim());
    const row = {};
    headers.forEach((header, index) => {
      row[header] = values[index] || '';
    });
    data.push(row);
  }
  return data;
}

// Charger la banque d'oiseaux V3
function loadBirdDatabase() {
  const birdData = parseCSV(resolve(__dirname, '../assets/data/Bank son oiseauxV3.csv'));
  const birdMap = new Map();
  
  birdData.forEach(bird => {
    if (bird.id_oiseaux && bird.Nom_français) {
      birdMap.set(bird.id_oiseaux, {
        id: bird.id_oiseaux,
        nomFrancais: bird.Nom_français,
        nomScientifique: bird.Nom_scientifique,
        nomAnglais: bird.Nom_anglais,
        photo: bird.photo,
        habitatPrincipal: bird.Habitat_principal,
        habitatSecondaire: bird.Habitat_secondaire,
        lienURL: bird.LienURL
      });
    }
  });
  
  console.log(`📚 ${birdMap.size} oiseaux chargés depuis Bank son oiseauxV3.csv`);
  return birdMap;
}

function createBirdPool(missionId, questionData, birdDatabase) {
  const birdPool = [];
  const notFoundBirds = [];
  const invalidIds = [];

  questionData.forEach((question, index) => {
    const correctAnswer = question['bonne_reponse'];
    const birdId = question['ID'];
    
    if (correctAnswer && birdId) {
      // Vérifier que l'ID existe dans la base de données
      if (birdDatabase.has(birdId)) {
        const birdInfo = birdDatabase.get(birdId);
        birdPool.push({
          id: birdId,
          name: correctAnswer,
          questionIndex: index + 1,
          birdInfo: birdInfo
        });
      } else {
        invalidIds.push({ id: birdId, name: correctAnswer });
        notFoundBirds.push(correctAnswer);
      }
    } else if (correctAnswer && !birdId) {
      notFoundBirds.push(correctAnswer);
    }
  });

  if (notFoundBirds.length > 0) {
    console.log(`  ⚠️ Oiseaux non trouvés dans ${missionId}: ${notFoundBirds.join(', ')}`);
  }
  
  if (invalidIds.length > 0) {
    console.log(`  ❌ IDs invalides dans ${missionId}: ${invalidIds.map(b => `${b.name} (ID: ${b.id})`).join(', ')}`);
  }

  return birdPool;
}

async function importMissionsDirectId() {
  console.log('🚀 Début de l\'import des missions avec liaison directe par ID...');
  
  try {
    // Charger la base de données des oiseaux
    const birdDatabase = loadBirdDatabase();
    
    // Charger la structure des missions
    const missionsStructure = parseCSV(resolve(__dirname, '../assets/Missionhome/missions_structure.csv'));
    console.log(`📋 ${missionsStructure.length} missions trouvées dans la structure`);

    let importedCount = 0;
    let totalBirdsFound = 0;
    let totalBirdsNotFound = 0;
    let totalInvalidIds = 0;

    for (const mission of missionsStructure) {
      const missionId = mission.id_mission;
      const missionTitle = mission.titre;
      const missionDescription = mission.description;
      const biome = mission.biome;

      console.log(`\n🔄 Import de la mission ${missionId}: ${missionTitle}`);

      const questionFilePath = resolve(__dirname, `../assets/Missionhome/questionMission/${missionId}.csv`);
      let questionData = [];

      try {
        questionData = parseCSV(questionFilePath);
        console.log(`  📝 ${questionData.length} questions trouvées`);
      } catch (error) {
        console.log(`  ❌ Erreur lecture questions: ${error.message}`);
        continue;
      }

      const birdPool = createBirdPool(missionId, questionData, birdDatabase);
      totalBirdsFound += birdPool.length;
      
      const notFoundCount = questionData.filter(q => q['bonne_reponse']).length - birdPool.length;
      totalBirdsNotFound += notFoundCount;

      const missionData = {
        id: missionId,
        title: missionTitle,
        description: missionDescription,
        biome: biome,
        niveau: parseInt(missionId.slice(-1)),
        imageUrl: `assets/Missionhome/Images/${missionId}.png`,
        questionFile: `assets/Missionhome/questionMission/${missionId}.csv`,
        birdPool: birdPool,
        // Règles Firestore exigent une mission approuvée pour lecture publique
        statut: 'approuvee',
        totalQuestions: questionData.length,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      try {
        await db.collection('missions').doc(missionId).set(missionData, { merge: true });
        console.log(`  ✅ Mission ${missionId} importée avec ${birdPool.length} oiseaux`);
        importedCount++;
      } catch (error) {
        console.log(`  ❌ Erreur sauvegarde mission ${missionId}: ${error.message}`);
      }
    }

    const successRate = ((totalBirdsFound / (totalBirdsFound + totalBirdsNotFound)) * 100);

    console.log(`\n🎉 Import terminé !`);
    console.log(`📊 Résultats:`);
    console.log(`  - Missions importées: ${importedCount}/${missionsStructure.length}`);
    console.log(`  - Oiseaux trouvés: ${totalBirdsFound}`);
    console.log(`  - Oiseaux non trouvés: ${totalBirdsNotFound}`);
    console.log(`  - Taux de réussite: ${successRate.toFixed(1)}%`);

  } catch (error) {
    console.error('❌ Erreur lors de l\'import:', error);
  }
}

importMissionsDirectId();

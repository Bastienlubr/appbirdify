import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { parse } from 'csv-parse/sync';

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
  const rows = parse(content, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
    bom: true,
    relax_quotes: true,
    relax_column_count: true
  });
  return rows;
}

function loadBirdsV4Map() {
  const birds = parseCSV(resolve(__dirname, '../assets/data/Bank son oiseauxV4.csv'));
  const byId = new Map();
  birds.forEach(b => {
    const id = (b.id_oiseaux || '').toString().trim();
    if (!id) return;
    byId.set(id, {
      id,
      nomFrancais: b['Nom_français']?.trim() || b['Nom_francais']?.trim() || '',
      nomScientifique: b['Nom_scientifique']?.trim() || '',
      nomAnglais: b['Nom_anglais']?.trim() || '',
      urlAudio: b['LienURL']?.trim() || null,
      urlImage: b['photo']?.trim() || null
    });
  });
  return byId;
}

function extractBonnes(questionData) {
  const seen = new Set();
  const ordered = [];
  for (const row of questionData) {
    const id = (row['id_oiseaux'] || row['ID'] || '').toString().trim();
    const bonne = (row['bonne_reponse'] || '').trim();
    if (!id || !bonne) continue;
    if (seen.has(id)) continue;
    seen.add(id);
    ordered.push({ id, name: bonne });
    if (ordered.length === 15) break;
  }
  return ordered;
}

async function importMissionsFinal() {
  console.log('🚀 Début de l\'import final des missions...');
  try {
    const missionsStructure = parseCSV(resolve(__dirname, '../assets/Missionhome/missions_structure.csv'));
    console.log(`📋 ${missionsStructure.length} missions trouvées dans la structure`);

    const birdsById = loadBirdsV4Map();

    let importedCount = 0;
    let totalBonnes = 0;

    for (const mission of missionsStructure) {
      const missionId = mission.id_mission?.trim();
      const missionTitle = mission.titre?.trim() || '';
      const missionDescription = mission.description || '';
      const biome = mission.biome?.trim() || '';

      console.log(`\n🔄 Import de la mission ${missionId}: ${missionTitle}`);

      const questionFilePath = resolve(__dirname, `../assets/Missionhome/questionMission/${missionId}.csv`);
      let questionData = [];
      try {
        questionData = parseCSV(questionFilePath);
        console.log(`  📝 ${questionData.length} lignes analysées`);
      } catch (error) {
        console.log(`  ❌ Erreur lecture questions: ${error.message}`);
        continue;
      }

      // Constituer exactement jusqu'à 15 bonnes réponses uniques
      const bonnesOrdered = extractBonnes(questionData);
      const bonnesIds = bonnesOrdered.map(b => b.id);
      const bonnesDetails = bonnesOrdered.map(b => {
        const d = birdsById.get(b.id);
        return {
          id: b.id,
          nomFrancais: d?.nomFrancais || b.name,
          urlAudio: d?.urlAudio || null,
          urlImage: d?.urlImage || null
        };
      });

      totalBonnes += bonnesIds.length;

      const missionData = {
        id: missionId,
        title: missionTitle,
        description: missionDescription,
        biome: biome,
        niveau: parseInt(missionId.slice(-1)),
        imageUrl: `assets/Missionhome/Images/${missionId}.png`,
        questionFile: `assets/Missionhome/questionMission/${missionId}.csv`,
        questionsParPartie: 10,
        idsOiseaux: bonnesIds,
        pool: {
          bonnes: bonnesIds,
          bonnesDetails: bonnesDetails
        },
        // Règles Firestore exigent une mission approuvée pour lecture publique
        statut: 'approuvee',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      try {
        await db.collection('missions').doc(missionId).set(missionData, { merge: true });
        console.log(`  ✅ Mission ${missionId} importée (bonnes: ${bonnesIds.length})`);
        importedCount++;
      } catch (error) {
        console.log(`  ❌ Erreur sauvegarde mission ${missionId}: ${error.message}`);
      }
    }

    console.log(`\n🎉 Import final terminé !`);
    console.log(`📊 Résultats:`);
    console.log(`  - Missions importées: ${importedCount}/${missionsStructure.length}`);
    console.log(`  - Total bonnes (toutes missions): ${totalBonnes}`);

  } catch (error) {
    console.error('❌ Erreur lors de l\'import:', error);
  }
}

importMissionsFinal();

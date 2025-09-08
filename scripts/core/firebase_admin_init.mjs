import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

let _admin = null;
let _firestore = null;

export function getFirebaseAdmin() {
  if (_admin) return _admin;
  const admin = require('firebase-admin');

  if (!admin.apps || admin.apps.length === 0) {
    const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS
      || path.resolve(process.cwd(), 'serviceAccountKey.json');
    try {
      const credential = admin.credential.applicationDefault?.()
        || admin.credential.cert(require(serviceAccountPath));
      admin.initializeApp({ credential });
    } catch (err) {
      admin.initializeApp();
    }
  }
  _admin = admin;
  _firestore = admin.firestore();
  _firestore.settings({ ignoreUndefinedProperties: true });
  return _admin;
}

export function getFirestore() {
  if (_firestore) return _firestore;
  getFirebaseAdmin();
  return _firestore;
}

export function getTimestamp() {
  const admin = getFirebaseAdmin();
  return admin.firestore.Timestamp;
}



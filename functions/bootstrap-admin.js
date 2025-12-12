const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // <-- your JSON

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  // projectId is inside the JSON, so no need to specify explicitly
});

async function main() {
  // UID of chasemcclellan387@gmail.com
  const uid = 'iXC8HDLZi8cWqOEyw52E6JGx1PQ2';

  await admin.auth().setCustomUserClaims(uid, { role: 'admin' });
  console.log('✅ Set role=admin for', uid);
}

main()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });

// enable-totp.js
import admin from 'firebase-admin';
import fs from 'fs';

admin.initializeApp({
  credential: admin.credential.cert(
    JSON.parse(fs.readFileSync('./serviceAccountKey.json', 'utf8'))
  ),
});

async function main() {
  await admin.auth().projectConfigManager().updateProjectConfig({
    multiFactorConfig: {
      providerConfigs: [
        {
          state: 'ENABLED',
          totpProviderConfig: {
            adjacentIntervals: 5, // default tolerance window
          },
        },
      ],
    },
  });

  console.log('TOTP MFA enabled for project.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

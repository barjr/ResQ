"use strict";

const admin = require("firebase-admin");
const path = require("path");

// Load the service account you downloaded
const serviceAccount = require(path.join(__dirname, "accountKey.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// TODO: paste the UID of the user you want to promote:
const UID = "c58GTImdu6QQgWxiM0oe7G0pr8b2";

(async () => {
  console.log("Promoting", UID, "to admin...");
  await admin.auth().setCustomUserClaims(UID, { role: "admin" });
  // Mirror to Firestore for your admin list UI:
  await db.collection("users").doc(UID).set({ role: "admin" }, { merge: true });
  console.log("Done. Ask the user to sign out and back in (or refresh token).");
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
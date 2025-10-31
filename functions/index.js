/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

//const {setGlobalOptions} = require("firebase-functions");
//const {onRequest} = require("firebase-functions/https");
//const logger = require("firebase-functions/logger");

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
// setGlobalOptions({maxInstances: 10});

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
"use strict";

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Auth trigger: create a Firestore mirror doc with default role "user".
 */
exports.onAuthCreate = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const email = user.email || null;
  const name = user.displayName || null;

  await db.collection("users").doc(uid).set({
    email,
    name,
    role: "user", // mirror only; claims are the source of truth
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});

/**
 * Callable: selfSetRole({ role })
 * Signed-in user may set their own role to 'helper' or 'user' only.
 */
exports.selfSetRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const role = (data && data.role) || null;
  if (!["helper", "user"].includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Role must be helper or user.");
  }
  const uid = context.auth.uid;

  // Set claim (no revoke here!)
  await admin.auth().setCustomUserClaims(uid, { role });

  // Mirror to Firestore for the admin list UI
  await admin.firestore().collection("users").doc(uid).set({ role }, { merge: true });

  return { ok: true, roleSet: role };
});

/**
 * Callable: setRole({ uid, role })
 * Admin-only: set anyone's role (admin/helper/user).
 */
exports.setRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in required.");
  }
  const callerRole = context.auth.token.role;
  if (callerRole !== "admin") {
    throw new functions.https.HttpsError("permission-denied", "Admins only.");
  }

  const { uid, role } = data || {};
  const allowed = ["admin", "helper", "user"];
  if (!uid || !allowed.includes(role)) {
    throw new functions.https.HttpsError("invalid-argument", "Provide uid and a valid role.");
  }

  await admin.auth().setCustomUserClaims(uid, { role });
  await admin.auth().revokeRefreshTokens(uid);

  await db.collection("users").doc(uid).set({ role }, { merge: true });

  return { ok: true, roleSet: role };
});

/**
 * Firestore Trigger: notifyHelpers
 */
exports.notifyHelpers = functions.firestore
  .document("emergency_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const request = snap.data();

    const helpersSnapshot = await db
      .collection("helpers")
      .where("isActive", "==", true)
      .get();

    const tokens = [];
    helpersSnapshot.forEach((doc) => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) {
      console.log("No helpers to notify");
      return null;
    }

    const description = request.description || "Emergency assistance needed";
    const location = request.location || "Location not specified";

    const message = {
      notification: {
        title: "🚨 Emergency Alert",
        body: description.substring(0, 100) + (description.length > 100 ? "..." : ""),
      },
      data: {
        requestId: context.params.requestId,
        location: location,
        type: "emergency",
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        ...message,
      });
      console.log(`Sent ${response.successCount}, failed ${response.failureCount}`);
      return response;
    } catch (err) {
      console.error("Error sending notifications:", err);
      return null;
    }
  });

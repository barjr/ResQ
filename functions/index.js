/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// const {setGlobalOptions} = require("firebase-functions");
// const {onRequest} = require("firebase-functions/https");
// const logger = require("firebase-functions/logger");

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

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Callable: setRole({ uid, role })
 * Only callable by an existing admin.
 */
exports.setRole = functions.https.onCall(async (data, context) => {
  // Must be signed in
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Sign in required.",
    );
  }

  const callerRole = context.auth.token.role;
  if (callerRole !== "admin") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Admins only.",
    );
  }

  const {uid, role} = data;
  const allowed = ["admin", "helper", "user"];

  if (!uid || !allowed.includes(role)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Provide uid and a valid role.",
    );
  }

  await admin.auth().setCustomUserClaims(uid, {role: role});
  await admin.auth().revokeRefreshTokens(uid);

  return {ok: true, roleSet: role};
});

/**
 * Firestore Trigger: notifyHelpers
 * Sends push notifications to all active helpers when a new emergency request is created
 */
exports.notifyHelpers = functions.firestore
    .document("emergency_requests/{requestId}")
    .onCreate(async (snap, context) => {
      const request = snap.data();

      // Get all active helpers with FCM tokens
      const helpersSnapshot = await admin.firestore()
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

      // Create the notification message
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

      // Send to all helper tokens
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          ...message,
        });

        console.log(`Successfully sent ${response.successCount} notifications`);
        console.log(`Failed to send ${response.failureCount} notifications`);

        return response;
      } catch (error) {
        console.error("Error sending notifications:", error);
        return null;
      }
 
});

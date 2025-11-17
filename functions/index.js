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
      const requestId = context.params.requestId;
      const request = snap.data();

      console.log('═══════════════════════════════════════');
      console.log(' NEW EMERGENCY REQUEST RECEIVED');
      console.log('═══════════════════════════════════════');
      console.log('Request ID:', requestId);
      console.log('Reporter:', request.reporterName || 'Unknown');
      console.log('Description:', request.description || 'No description');
      console.log('Location:', request.location || 'Not provided');
      console.log('Timestamp:', new Date().toISOString());
      console.log('Status:', request.status || 'N/A');
      console.log('───────────────────────────────────────');

      try {
        // Get all active helpers with FCM tokens
        const helpersSnapshot = await admin.firestore()
            .collection("helpers")
            .where("isActive", "==", true)
            .get();

        console.log(` Found ${helpersSnapshot.size} active helper(s)`);

        const tokens = [];
        const helperDetails = [];
        
        helpersSnapshot.forEach((doc) => {
          const helperData = doc.data();
          const token = helperData.fcmToken;
          
          helperDetails.push({
            id: doc.id,
            name: helperData.name || 'Unknown',
            hasToken: !!token
          });
          
          if (token) {
            tokens.push(token);
            console.log(`   Helper: ${helperData.name || doc.id} - Token available`);
          } else {
            console.log(`   Helper: ${helperData.name || doc.id} - No FCM token`);
          }
        });

        if (tokens.length === 0) {
          console.log(' WARNING: No helpers with valid FCM tokens available');
          console.log('Helpers found:', helpersSnapshot.size);
          console.log('Helpers with tokens:', 0);
          console.log('═══════════════════════════════════════');
          return null;
        }

        console.log(` Preparing to send notifications to ${tokens.length} helper(s)`);

        // Create the notification message
        const description = request.description || "Emergency assistance needed";
        const location = request.location || "Location not specified";

        const message = {
          notification: {
            title: " Emergency Alert",
            body: description.substring(0, 100) + (description.length > 100 ? "..." : ""),
          },
          data: {
            requestId: requestId,
            location: location,
            description: description.substring(0, 200),
            reporterName: request.reporterName || "Unknown",
            type: "emergency",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        };

        console.log(' Sending notifications...');

        // Send to all helper tokens
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          ...message,
        });

        console.log('───────────────────────────────────────');
        console.log('NOTIFICATION RESULTS:');
        console.log(`  Total sent: ${tokens.length}`);
        console.log(`  Success: ${response.successCount}`);
        console.log(`  Failure: ${response.failureCount}`);

        // Log individual failures with details
        if (response.failureCount > 0) {
          console.log('\n FAILED NOTIFICATIONS:');
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const helper = helperDetails[idx];
              console.log(`  - Helper: ${helper?.name || 'Unknown'} (${helper?.id || 'N/A'})`);
              console.log(`    Error: ${resp.error?.message || 'Unknown error'}`);
              console.log(`    Error Code: ${resp.error?.code || 'N/A'}`);
            }
          });
        }

        // Log successful notifications
        if (response.successCount > 0) {
          console.log('\n✅ SUCCESSFUL NOTIFICATIONS:');
          response.responses.forEach((resp, idx) => {
            if (resp.success) {
              const helper = helperDetails[idx];
              console.log(`  - Helper: ${helper?.name || 'Unknown'} (${helper?.id || 'N/A'})`);
            }
          });
        }

        console.log('═══════════════════════════════════════\n');

        return response;

      } catch (error) {
        console.error('═══════════════════════════════════════');
        console.error('ERROR SENDING NOTIFICATIONS');
        console.error('═══════════════════════════════════════');
        console.error('Request ID:', requestId);
        console.error('Error Message:', error.message);
        console.error('Error Code:', error.code);
        console.error('Error Stack:', error.stack);
        console.error('═══════════════════════════════════════\n'); 
        
        // Don't throw - just log and return null so the function completes
        return null;
      }
    });

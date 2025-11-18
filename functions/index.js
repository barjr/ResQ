"use strict";

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Callable: setRole({ uid, role })
 * Only callable by an existing admin.
 */
exports.setRole = functions.https.onCall(async (data, context) => {
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
 * Callable: selfSetRole({ role })
 * Allows users to set their own role during account creation
 */
exports.selfSetRole = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Sign in required.",
    );
  }

  const {role} = data;
  const allowed = ["helper", "user"];

  if (!allowed.includes(role)) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Role must be 'helper' or 'user'.",
    );
  }

  const uid = context.auth.uid;
  await admin.auth().setCustomUserClaims(uid, {role: role});
  await admin.auth().revokeRefreshTokens(uid);

  return {ok: true, roleSet: role};
});

/**
 * Firestore Trigger: notifyHelpers
 * Sends push notifications to all helpers and admins when a new emergency request is created
 */
exports.notifyHelpers = functions.firestore
    .document("emergency_requests/{requestId}")
    .onCreate(async (snap, context) => {
      const requestId = context.params.requestId;
      const request = snap.data();

      console.log('New emergency request received');
      console.log('Request ID:', requestId);
      console.log('Reporter:', request.reporterName || 'Unknown');
      console.log('Description:', request.description || 'No description');
      console.log('Location:', request.location || 'Not provided');
      console.log('Severity:', request.severity || 'Not specified');

      try {
        // Get all users from Firestore
        const usersSnapshot = await admin.firestore()
            .collection("users")
            .get();

        console.log(`Found ${usersSnapshot.size} total user(s)`);

        const tokens = [];
        const helperDetails = [];
        
        // Check each user's role claim and collect tokens from helpers/admins
        for (const doc of usersSnapshot.docs) {
          const userData = doc.data();
          const userId = doc.id;
          
          try {
            // Get user's custom claims to check role
            const userRecord = await admin.auth().getUser(userId);
            const role = userRecord.customClaims?.role;
            
            // Only send to helpers and admins
            if (role === 'helper' || role === 'admin') {
              const token = userData.fcmToken;
              
              helperDetails.push({
                id: userId,
                name: userData.name || 'Unknown',
                role: role,
                hasToken: !!token
              });
              
              if (token) {
                tokens.push(token);
                console.log(`${role}: ${userData.name || userId} - Token available`);
              } else {
                console.log(`${role}: ${userData.name || userId} - No FCM token`);
              }
            }
          } catch (error) {
            console.log(`Could not get auth record for user ${userId}: ${error.message}`);
          }
        }

        if (tokens.length === 0) {
          console.log('WARNING: No helpers/admins with valid FCM tokens available');
          console.log('Total helpers/admins found:', helperDetails.length);
          console.log('Helpers/admins with tokens:', 0);
          return null;
        }

        console.log(`Preparing to send notifications to ${tokens.length} helper(s)/admin(s)`);

        // Create the notification message
        const description = request.description || "Emergency assistance needed";
        const location = request.location || "Location not specified";
        const severity = request.severity || "unknown";

        const message = {
          notification: {
            title: severity === "critical" ? "CRITICAL Emergency Alert" : "Emergency Alert",
            body: description.substring(0, 100) + (description.length > 100 ? "..." : ""),
          },
          data: {
            requestId: requestId,
            location: location,
            description: description.substring(0, 200),
            reporterName: request.reporterName || "Unknown",
            severity: severity,
            type: "emergency",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "default_channel",
              priority: "max",
              sound: "default",
            },
          },
        };

        console.log('Sending notifications...');

        // Send to all helper/admin tokens
        const response = await admin.messaging().sendEachForMulticast({
          tokens: tokens,
          ...message,
        });

        console.log('Notification Results:');
        console.log(`Total sent: ${tokens.length}`);
        console.log(`Success: ${response.successCount}`);
        console.log(`Failure: ${response.failureCount}`);

        // Log individual results
        if (response.failureCount > 0) {
          console.log('Failed notifications:');
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const helper = helperDetails[idx];
              console.log(`- ${helper?.role}: ${helper?.name || 'Unknown'} (${helper?.id || 'N/A'})`);
              console.log(`  Error: ${resp.error?.message || 'Unknown error'}`);
            }
          });
        }

        if (response.successCount > 0) {
          console.log('Successful notifications:');
          response.responses.forEach((resp, idx) => {
            if (resp.success) {
              const helper = helperDetails[idx];
              console.log(`- ${helper?.role}: ${helper?.name || 'Unknown'}`);
            }
          });
        }

        // Clean up invalid tokens
        if (response.failureCount > 0) {
          const tokensToRemove = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const error = resp.error;
              
              if (error?.code === 'messaging/invalid-registration-token' ||
                  error?.code === 'messaging/registration-token-not-registered') {
                tokensToRemove.push(tokens[idx]);
              }
            }
          });

          if (tokensToRemove.length > 0) {
            console.log(`Removing ${tokensToRemove.length} invalid token(s)`);
            const batch = admin.firestore().batch();
            
            for (const token of tokensToRemove) {
              const userQuery = await admin.firestore()
                  .collection("users")
                  .where("fcmToken", "==", token)
                  .limit(1)
                  .get();
              
              userQuery.forEach((doc) => {
                batch.update(doc.ref, {
                  fcmToken: admin.firestore.FieldValue.delete(),
                });
              });
            }
            
            await batch.commit();
          }
        }

        return response;

      } catch (error) {
        console.error('Error sending notifications');
        console.error('Request ID:', requestId);
        console.error('Error:', error.message);
        console.error('Stack:', error.stack);
        return null;
      }
    });
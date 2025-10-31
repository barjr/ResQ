import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<String?> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');//TODO dont call print in prod code. Use only for testing
    }

    // Get the FCM token for this device
    String? token = await _fcm.getToken();
    print('FCM Token: $token');
    
    return token;
  }

  // Save helper's FCM token to Firestore
  Future<void> saveHelperToken(String helperId, String token) async {
    await FirebaseFirestore.instance
      .collection('helpers')
      .doc(helperId)
      .set({
        'fcmToken': token,
        'isActive': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
  }

  // Handle foreground messages
  void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // You can show a local notification here if you want
      }
    });
  }

  // Handle notification taps
  void handleNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      // Navigate to the emergency request details page
    });
  }
}
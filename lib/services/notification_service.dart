import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Android channel id / name
  static const String _androidChannelId = 'default_channel';
  static const String _androidChannelName = 'Default';

  Future<String?> initialize() async {
    // request permissions on iOS (Android handled separately)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // Initialize flutter_local_notifications
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInitSettings);
    await _localNotif.initialize(
      initSettings,
      // optional: handle notification taps while app in foreground/background
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Local notification tapped: ${response.payload}');
        // Handle navigation if needed
      },
    );

    // Create Android notification channel (required for Android 8+)
    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Default channel for emergency alerts',
          importance: Importance.max,
        ),
      );
    }

    // Get FCM token
    String? token = await _fcm.getToken();
    debugPrint('FCM Token: $token');
    return token;
  }

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

  void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      final notif = message.notification;
      if (notif != null) {
        // show a local notification using the channel we created
        _localNotif.show(
          0,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.max,
              priority: Priority.high,
              // optionally set icon, sound, etc.
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: message.data['requestId'] ?? '',
        );
      }
    });
  }

  void handleNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('A new onMessageOpenedApp event was published!');
      // navigate to the emergency details screen, using message.data['requestId']
    });
  }
}

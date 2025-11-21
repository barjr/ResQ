import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  static const String _androidChannelId = 'default_channel';
  static const String _androidChannelName = 'Default';
  
  Future<String?> initialize() async {
    // Request permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    } else {
      debugPrint('User declined or has not accepted notification permission');
    }

    // Initialize flutter_local_notifications
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInitSettings);
    
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Local notification tapped: ${response.payload}');
      },
    );

    // Create Android notification channel
    final androidPlugin = _localNotif.resolvePlatformSpecificImplementation
        <AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Default channel for emergency alerts',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    // Get FCM token
    String? token = await _fcm.getToken();
    debugPrint('FCM Token: $token');

    // Auto-save token if user is logged in
    if (token != null) {
      await _autoSaveToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _autoSaveToken(newToken);
    });

    return token;
  }

  Future<void> _autoSaveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await saveUserToken(user.uid, token);
      debugPrint('Token auto-saved for user: ${user.uid}');
    } catch (e) {
      debugPrint('Error auto-saving token: $e');
    }
  }

  Future<void> saveUserToken(String userId, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('User token saved successfully');
    } catch (e) {
      debugPrint('Error saving user token: $e');
    }
  }

  Future<void> removeUserToken(String userId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('User token removed successfully');
    } catch (e) {
      debugPrint('Error removing user token: $e');
    }
  }

  void handleForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      final notif = message.notification;
      if (notif != null) {
        _localNotif.show(
          message.hashCode,
          notif.title,
          notif.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelId,
              _androidChannelName,
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
              sound: const RawResourceAndroidNotificationSound('notification'),
              playSound: true,
              enableVibration: true,
            ),
          ),
          payload: message.data['requestId'] ?? '',
        );
      }
    });
  }

  void handleNotificationTaps() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped! Request ID: ${message.data['requestId']}');
      // TODO: Navigate to emergency details screen
    });
  }
}
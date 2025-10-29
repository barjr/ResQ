import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/dashboard.dart';
import 'package:resq/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //Notification information
  final notificationService = NotificationService();
  await notificationService.initialize();
  notificationService.handleForegroundMessages();
  notificationService.handleNotificationTaps();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQ App',
      //use an auth-gate:
      home: const AuthGate(),
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // If logged in -> Dashboard, else -> Login page
        if (snap.data != null) {
          return const DashboardPage();
        } else {
          return const HomePage();
        }
      },
    );
  }
}

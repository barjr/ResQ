import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/dashboard.dart';
import 'package:resq/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final notifService = NotificationService();
  final token = await notifService.initialize();
  notifService.handleForegroundMessages();
  notifService.handleNotificationTaps();

  // Save helper token (optional)
  if (token != null) {
    await notifService.saveHelperToken('helper123', token);
  }

  runApp(MyApp());
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

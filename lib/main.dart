import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/services/notification_service.dart';
import 'package:resq/services/role_router.dart';
import 'package:resq/services/request_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Start syncing active emergency requests from Firestore into the
  // in-memory RequestStore so dashboards update in real-time.
  RequestStore.instance.startFirestoreSync();

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
        final user = snap.data;
        if (user == null) return const HomePage();
        return RoleRouter(user: user); // go route by role
      },
    );
  }
}

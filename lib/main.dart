import 'package:flutter/material.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ResQ App',
      // Routes for navigation
      initialRoute: '/login',
      routes: {
        '/login': (context) => const HomePage(),
        '/dashboard': (context) => const DashboardPage(),
      },
      // Fallback for undefined routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const HomePage());
      },
    );
  }
}

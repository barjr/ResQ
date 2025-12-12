// lib/services/role_router.dart
/*CONTAINS ALL LOGIC TO REROUTE THE USER AFTER LOGIN BASED ON THE USER'S ROLE */
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:resq/pages/dashboard.dart';
import 'package:resq/pages/home.dart';

class RoleRouterRoot extends StatelessWidget {
  const RoleRouterRoot({super.key});

  @override
  Widget build(BuildContext context) {
    // Just reuse your existing RoleRouter, but without a required user param
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final u = snap.data;
        if (u == null) {
          return const HomePage(); // not signed in → show login
        }

        return RoleRouter(user: u);
      },
    );
  }
}

class RoleRouter extends StatelessWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  Future<String?> _readRoleFromFirestore(User u) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .get();
    final data = snap.data();
    if (data == null) return null;
    return data['role'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _readRoleFromFirestore(user),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }

        final role = snap.data; // "admin", "helper", "user", or null
        switch (role) {
          case 'admin':
            return const DashboardPage(isAdmin: true, isHelper: false);
          case 'helper':
            return const DashboardPage(isAdmin: false, isHelper: true);
          case 'user':
          case null:
          default:
            return const DashboardPage(isAdmin: false, isHelper: false);
        }
      },
    );
  }
}
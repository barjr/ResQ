// lib/services/role_router.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:resq/pages/dashboard.dart';
import 'package:resq/pages/home.dart';

class RoleRouter extends StatelessWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  // Track which UIDs we've already forced a refresh for (avoid loops)
  static final Set<String> _didForceRefresh = <String>{};

  Future<String?> _readRoleOnce(User u) async {
    // 1) Read claims as-is (no force)
    final t1 = await u.getIdTokenResult();
    final r1 = t1.claims?['role'];
    if (r1 is String) return r1;

    // 2) If role missing and we haven't forced yet for this UID, force refresh once
    if (!_didForceRefresh.contains(u.uid)) {
      _didForceRefresh.add(u.uid);
      await u.getIdToken(true); // force one time
      final t2 = await u.getIdTokenResult();
      final r2 = t2.claims?['role'];
      if (r2 is String) return r2;
    }

    // 3) Default: no role → treat as user
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Listen only to *auth state* changes; avoid token-change loops
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
          // Signed out — show the public Home/Login page
          return const HomePage();
        }

        return FutureBuilder<String?>(
          future: _readRoleOnce(u),
          builder: (context, fsnap) {
            if (fsnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (fsnap.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${fsnap.error}')),
              );
            }

            final role = fsnap.data; // may be null
            // Route all signed-in users to the Dashboard. Admins receive the
            // full dashboard (isAdmin: true). Helpers and regular users get
            // the same Dashboard UI but with admin features hidden; helpers
            // additionally hide SOS/Get Help/Customer links via isHelper.
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
      },
    );
  }
}

Future<void> routeByRole(BuildContext context, User user) async {
  await user.getIdToken(true);

  String? role;
  const tries = 8;
  for (var i = 0; i < tries; i++) {
    final tok = await user.getIdTokenResult();
    final r = tok.claims?['role'];
    role = r is String ? r : null;
    if (role != null) break;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  Widget dest;
  switch (role) {
    case 'admin':
      dest = const DashboardPage(isAdmin: true, isHelper: false);
      break;
    case 'helper':
      dest = const DashboardPage(isAdmin: false, isHelper: true);
      break;
    case 'user':
      dest = const DashboardPage(isAdmin: false, isHelper: false);
      break;
    case null:
    default:
      dest = const DashboardPage(isAdmin: false, isHelper: false);
  }

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => dest),
    (route) => false,
  );
}

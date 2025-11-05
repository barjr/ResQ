// lib/services/role_router.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:resq/pages/customer_view.dart';
import 'package:resq/pages/dashboard.dart';
import 'package:resq/pages/helper_view.dart';

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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final u = snap.data;
        if (u == null) {
          // Signed out — your app’s Home/Login
          return const CustomerViewPage(); // or HomePage() if you prefer here
        }

        return FutureBuilder<String?>(
          future: _readRoleOnce(u),
          builder: (context, fsnap) {
            if (fsnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (fsnap.hasError) {
              return Scaffold(body: Center(child: Text('Error: ${fsnap.error}')));
            }

            final role = fsnap.data; // may be null
            switch (role) {
              case 'admin':
                return const DashboardPage(isAdmin: true);
              case 'helper':
                return const HelperViewPage();
              case 'user':
              case null:
              default:
                return const CustomerViewPage();
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
      dest = const DashboardPage(isAdmin: true);
      break;
    case 'helper':
      dest = const HelperViewPage();
      break;
    case 'user':
      dest = const CustomerViewPage();
      break;
    case null:
    default:
      dest = const CustomerViewPage();
  }

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => dest),
    (route) => false,
  );
}
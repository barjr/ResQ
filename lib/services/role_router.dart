import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/customer_view.dart';
import 'package:resq/pages/helper_view.dart';
import 'package:resq/pages/admin_view.dart'; // create if you haven’t

class RoleRouter extends StatefulWidget {
  final User user;
  const RoleRouter({super.key, required this.user});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  String? _role;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRole();
    // Also respond to subsequent token changes (e.g., role changed server-side)
    FirebaseAuth.instance.idTokenChanges().listen((u) {
      if (u == null) return;
      _readRole(fromUser: u);
    });
  }

  Future<void> _loadRole() async {
    try {
      // Force refresh once so brand-new roles appear immediately
      await widget.user.getIdToken(true);
      await _readRole(fromUser: widget.user);
    } catch (e) {
      setState(() {
        _error = 'Failed to load role: $e';
        _loading = false;
      });
    }
  }

  Future<void> _readRole({required User fromUser}) async {
    final idToken = await fromUser.getIdTokenResult();
    final role = idToken.claims?['role'] as String?;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    switch (_role) {
      case 'admin':
        return const AdminViewPage();
      case 'helper':
        return const HelperViewPage();
      case 'user':
      case null:
      default:
        // Default to customer/user experience if no role set
        return const CustomerViewPage();
    }
  }
}

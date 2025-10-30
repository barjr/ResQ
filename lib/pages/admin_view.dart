// lib/pages/admin_view.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminViewPage extends StatefulWidget {
  const AdminViewPage({super.key});

  @override
  State<AdminViewPage> createState() => _AdminViewPageState();
}

class _AdminViewPageState extends State<AdminViewPage> {
  final _roles = const ['admin', 'helper', 'user'];
  String _search = '';

  Future<void> _setRoleForUser(String uid, String role) async {
    try {
      // Call your existing admin-only callable
      final callable = FirebaseFunctions.instance.httpsCallable('setRole');
      await callable.call({'uid': uid, 'role': role});

      // Optimistically update Firestore mirror so UI reflects change immediately
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'role': role},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role set to "$role"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set role: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin — Manage Roles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by email or name…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('email')
                  .limit(500) // paginate if needed
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? [];
                final filtered = docs.where((d) {
                  if (q.isEmpty) return true;
                  final email = (d.data()['email'] ?? '').toString().toLowerCase();
                  final name = (d.data()['name'] ?? '').toString().toLowerCase();
                  return email.contains(q) || name.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No users found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final uid = doc.id;
                    final data = doc.data();
                    final email = (data['email'] ?? '') as String;
                    final name = (data['name'] ?? '') as String? ?? '';
                    final role = (data['role'] ?? 'user') as String;

                    return ListTile(
                      title: Text(email.isEmpty ? '(no email)' : email),
                      subtitle: name.isEmpty ? null : Text(name),
                      trailing: DropdownButton<String>(
                        value: _roles.contains(role) ? role : 'user',
                        items: _roles
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(r),
                                ))
                            .toList(),
                        onChanged: (newRole) {
                          if (newRole == null) return;
                          _setRoleForUser(uid, newRole);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

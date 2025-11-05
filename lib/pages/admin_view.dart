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
  // QoL: centralize region in one place
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  final _roles = const ['admin', 'helper', 'user'];
  final _searchCtrl = TextEditingController();

  String _search = '';
  String _roleFilter = 'all'; // all | admin | helper | user
  String? _updatingUid; // disable dropdown for that row while saving

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _setRoleForUser(String uid, String role) async {
    if (!mounted) return;
    setState(() => _updatingUid = uid);
    try {
      // admin-only callable
      final callable = _functions.httpsCallable('setRole');
      await callable.call({'uid': uid, 'role': role});

      // Optimistic mirror update (not security-critical)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'role': role}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Role set to "$role"')),
      );
    } on FirebaseFunctionsException catch (e) {
      final msg = e.code == 'permission-denied'
          ? 'You do not have admin permission.'
          : e.message ?? e.code;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $msg')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to set role: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingUid = null);
    }
  }

  // Helper for filter chips
  Widget _roleChip(String value, String label) {
    final selected = _roleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _roleFilter = value),
    );
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
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by email or name…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          // Role filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              children: [
                _roleChip('all', 'All'),
                _roleChip('admin', 'Admin'),
                _roleChip('helper', 'Helper'),
                _roleChip('user', 'User'),
              ],
            ),
          ),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Force a new snapshot by touching cache; Firestore streams are live anyway
                await Future<void>.delayed(const Duration(milliseconds: 250));
              },
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .orderBy('email')
                    .limit(500)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }

                  final docs = snap.data?.docs ?? [];

                  // Filter + map safely
                  final filtered = docs.where((d) {
                    final data = d.data();
                    final email = (data['email'] ?? '').toString();
                    final name = (data['name'] ?? '').toString();
                    final role = (data['role'] ?? 'user').toString();

                    final matchesQuery = q.isEmpty ||
                        email.toLowerCase().contains(q) ||
                        name.toLowerCase().contains(q);

                    final matchesRole =
                        _roleFilter == 'all' || role == _roleFilter;

                    return matchesQuery && matchesRole;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No users found.'));
                  }

                  return Column(
                    children: [
                      // Count row
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${filtered.length} user(s)',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_,_) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final doc = filtered[i];
                            final uid = doc.id;
                            final data = doc.data();

                            // ✅ Safe string conversions
                            final email = (data['email'] ?? '').toString();
                            final name = (data['name'] ?? '').toString();
                            final role = (data['role'] ?? 'user').toString();

                            final dropdownValue =
                                _roles.contains(role) ? role : 'user';

                            return ListTile(
                              title: Text(email.isEmpty ? '(no email)' : email),
                              subtitle: name.isEmpty ? null : Text(name),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Current role chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(dropdownValue),
                                  ),
                                  const SizedBox(width: 12),
                                  // Role dropdown
                                  AbsorbPointer(
                                    absorbing: _updatingUid == uid,
                                    child: DropdownButton<String>(
                                      value: dropdownValue,
                                      items: _roles
                                          .map((r) => DropdownMenuItem(
                                                value: r,
                                                child: Text(r),
                                              ))
                                          .toList(),
                                      onChanged: (newRole) {
                                        if (newRole == null ||
                                            newRole == dropdownValue) {
                                          return;
                                        }
                                        _setRoleForUser(uid, newRole);
                                      },
                                    ),
                                  ),
                                  if (_updatingUid == uid) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

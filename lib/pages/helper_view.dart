import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/emergency_detail_page.dart';

class HelperViewPage extends StatefulWidget {
  const HelperViewPage({super.key});

  @override
  State<HelperViewPage> createState() => _HelperViewPageState();
}

class _HelperViewPageState extends State<HelperViewPage> {

  Future<void> _acceptRequest(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to accept.')),
      );
      return;
    }

    final data = doc.data() ?? {};
    final reporterName = (data['reporterName'] ?? 'Unknown') as String;
    final severity = (data['severity'] ?? 'critical') as String?;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Accept Request'),
        content: Text(
          'Accept ${_severityLabel(severity)} request from $reporterName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // close dialog

              try {
                // Update Firestore: mark as accepted
                await doc.reference.update({
                  'status': 'accepted',
                  'acceptedBy': user.uid,
                  'acceptedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                // For the detail page, start from current data and override status.
                final updatedData = Map<String, dynamic>.from(data);
                updatedData['status'] = 'accepted';
                updatedData['acceptedBy'] = user.uid;

                // Navigate to the emergency detail page
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmergencyDetailPage(
                      requestId: doc.id,
                      data: updatedData,
                    ),
                  ),
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('You accepted $reporterName')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('List of Active Emergencies', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFC3B3C),
        actions: [
          // Debug: show token claims (only in debug builds)
          if (false)
            IconButton(
              tooltip: 'Show token claims',
              icon: const Icon(Icons.bug_report),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not signed in')),
                    );
                  }
                  return;
                }
                try {
                  final idtr = await user.getIdTokenResult(true);
                  final claims = idtr.claims ?? <String, dynamic>{};
                  if (!mounted) return;
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('ID Token Claims'),
                      content: SingleChildScrollView(
                        child: Text(
                          const JsonEncoder.withIndent('  ').convert(claims),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to get token claims: $e')),
                    );
                  }
                }
              },
            ),
          IconButton(
            tooltip: 'Back to Home',
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Active Emergencies',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Firestore list of emergencies
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('emergency_requests')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(child: Text('Error: ${snap.error}'));
                    }

                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No active emergencies.'),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final d = docs[index];
                        final data = d.data();
                        final reporterName =
                            (data['reporterName'] ?? 'Unknown') as String;
                        final description =
                            (data['description'] ?? '') as String;
                        final location =
                            (data['location'] ?? 'unknown location') as String?;
                        final severity =
                            (data['severity'] ?? 'critical') as String?;
                        final status = (data['status'] ?? 'pending') as String;

                        return ListTile(
                          onTap: () {
                            // Tap card -> detailed emergency page
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EmergencyDetailPage(
                                  requestId: d.id,
                                  data: data,
                                ),
                              ),
                            );
                          },

                          // Severity chip on the left
                          leading: _severityChip(severity),

                          title: Text(reporterName),
                          subtitle: Text(
                            '${location ?? 'unknown location'} — ${_preview(description)}\nStatus: ${status.toUpperCase()}',
                          ),

                          trailing: ElevatedButton(
                            onPressed: () => _acceptRequest(context, d),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFC3B3C),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Severity label/chip helpers -------------------------------

  String _severityLabel(String? s) {
    switch (s) {
      case 'minor':
        return 'MINOR';
      case 'urgent':
        return 'URGENT';
      case 'critical':
      default:
        return 'CRITICAL';
    }
  }

  Widget _severityChip(String? s) {
    final label = _severityLabel(s);
    Color bg = const Color(0xFFE0E0E0);
    Color fg = const Color(0xFF424242);

    if (s == 'minor') {
      bg = const Color(0xFFE8F5E9); // light green
      fg = const Color(0xFF2E7D32);
    } else if (s == 'urgent') {
      bg = const Color(0xFFFFF3E0); // light orange
      fg = const Color(0xFFEF6C00);
    } else if (s == 'critical') {
      bg = const Color(0xFFFFEBEE); // light red
      fg = const Color(0xFFC62828);
    }

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  String _preview(String text, {int words = 6}) {
    final tokens = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '(No description)';
    final head = tokens.take(words).join(' ');
    return tokens.length > words ? '$head…' : head;
  }
}

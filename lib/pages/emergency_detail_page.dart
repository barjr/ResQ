import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmergencyDetailPage extends StatelessWidget {
  final String requestId;
  final Map<String, dynamic> data;

  const EmergencyDetailPage({
    super.key,
    required this.requestId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final reporterName = (data['reporterName'] ?? 'Unknown') as String;
    final reporterUid = data['reporterUid'] as String?;
    final description = (data['description'] ?? '') as String;
    final location = (data['location'] ?? '') as String?;
    final status = (data['status'] ?? 'pending') as String;
    final severity = (data['severity'] ?? 'critical') as String?;
    final ts = data['timestamp'] as Timestamp?;
    final timeText = ts != null
        ? '${ts.toDate()}'
        : 'Pending timestamp';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFC3B3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Emergency summary
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _severityChip(severity),
                        const SizedBox(width: 8),
                        Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (location != null && location.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.place, size: 18),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Reported by: $reporterName',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'At: $timeText',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Linked user profile (if we have reporterUid)
            if (reporterUid != null)
              _UserProfileSection(reporterUid: reporterUid)
            else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No user profile linked to this emergency (anonymous report).',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _severityChip(String? s) {
    String label = 'CRITICAL';
    Color bg = const Color(0xFFFFEBEE);
    Color fg = const Color(0xFFC62828);

    if (s == 'minor') {
      label = 'MINOR';
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (s == 'urgent') {
      label = 'URGENT';
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFEF6C00);
    }

    return Container(
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
}

class _UserProfileSection extends StatelessWidget {
  final String reporterUid;

  const _UserProfileSection({required this.reporterUid});

  @override
  Widget build(BuildContext context) {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(reporterUid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading profile: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No profile found for this user.'),
            ),
          );
        }

        final data = snap.data!.data()!;
        final name = (data['name'] ?? 'Unknown') as String;
        final phone = (data['phone'] ?? '') as String;
        final ec = data['emergencyContact'] as Map<String, dynamic>?;

        final allergies = (data['allergies'] ?? '') as String;
        final conditions = (data['conditions'] ?? '') as String;
        final medications = (data['medications'] ?? '') as String;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient Profile',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: $name'),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Phone: $phone'),
                    ],
                    if (ec != null) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Emergency Contact:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('  ${ec['name'] ?? ''}'),
                      Text('  ${ec['phone'] ?? ''}'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medical Profile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Allergies: ${allergies.isEmpty ? 'None listed' : allergies}'),
                    const SizedBox(height: 4),
                    Text('Conditions: ${conditions.isEmpty ? 'None listed' : conditions}'),
                    const SizedBox(height: 4),
                    Text('Medications: ${medications.isEmpty ? 'None listed' : medications}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stub for medical documents list – we can flesh out later
            _MedicalDocumentsSection(userId: reporterUid),
          ],
        );
      },
    );
  }
}

class _MedicalDocumentsSection extends StatelessWidget {
  final String userId;

  const _MedicalDocumentsSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    final docsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('medicalDocuments');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: docsRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading medical documents: ${snap.error}'),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 1,
          child: ExpansionTile(
            leading: const Icon(Icons.folder_shared),
            title: const Text('Medical Documents'),
            subtitle: Text(
              docs.isEmpty
                  ? 'No documents uploaded'
                  : '${docs.length} document(s) available',
            ),
            children: docs.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No medical documents on file.'),
                    ),
                  ]
                : docs.map((d) {
                    final data = d.data();
                    final fileName = (data['fileName'] ?? 'Unknown') as String;
                    return ListTile(
                      title: Text(fileName),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        // TODO: fetch Storage download URL and open with url_launcher
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Opening documents coming soon (prototype).',
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
          ),
        );
      },
    );
  }
}

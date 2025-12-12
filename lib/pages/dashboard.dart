import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/emergency_detail_page.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/admin_view.dart';
import 'package:resq/pages/sos_report.dart';
import 'package:resq/pages/tiered_report.dart';
import 'package:resq/pages/user_settings_page.dart';
import 'package:resq/pages/offline_medical_guides_page.dart';

// Dashboard: central landing page for signed-in users.
// - Shows an SOS quick action and quick links to Customer/Helper views.
// - When `isAdmin` is true the bottom navigation includes a "Roles" entry
//   which opens the admin role-management view. This lets admins manage
//   user roles while keeping them on the same overall dashboard UX.
//
// Notes for maintainers:
// - Bottom nav ordering is dynamic: Home (0), Roles (1, only for admins),
//   Settings (last). The tap handler (`_onNavTap`) relies on these indexes.
// - Active emergencies are provided by `RequestStore.instance.stream` and
//   rendered in a ListView; cancelling an emergency shows a SnackBar with
//   an UNDO action which re-adds a request to the store.

class DashboardPage extends StatefulWidget {
  final bool isAdmin;
  final bool isHelper;
  const DashboardPage({super.key, this.isAdmin = false, this.isHelper = false});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _showDisclaimer = true;

  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Settings tab: this index corresponds to the Settings entry in the
    // bottom navigation bar. Note the actual index value depends on whether
    // `isAdmin` is set (Roles may insert at index 1).
    if (index == (widget.isAdmin ? 2 : 1)) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const UserSettingsPage()))
          .then((_) {
            setState(() {
              _selectedIndex = 0;
            });
          });
    }
    // Roles tab for admins: when an admin taps the Roles tab (index 1)
    // we push the `AdminViewPage` which contains the role-management UI.
    // We then reset the selected index back to Home when the admin returns.
    if (widget.isAdmin && index == 1) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AdminViewPage()))
          .then((_) => setState(() => _selectedIndex = 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Welcome back, \n',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text:
                    user != null &&
                        user.email != null &&
                        user.email!.isNotEmpty &&
                        user.email!.contains('@')
                    ? user.email!.split('@')[0]
                    : '',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Signed out')));
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
              }
            },
          ),
          IconButton(
  icon: Icon(Icons.bug_report),
  onPressed: () async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdTokenResult(true);
    print("ID TOKEN CLAIMS: ${token?.claims}");
  },
)
        ],
        bottom: _showDisclaimer
            ? _DisclaimerAppBarBottom(
                onClose: () => setState(() => _showDisclaimer = false),
              )
            : null,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).size.height * 0.1,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // --- CUSTOMER TOOLS (SOS + Tiered) ------------------------------------
// Show to regular users and admins; hide from helpers.
if (!widget.isHelper || widget.isAdmin) ...[
  Text(
    "Are you in an emergency?",
    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
  ),
  const SizedBox(height: 16),
  const Text(
    "If so, please press the button below.",
    style: TextStyle(fontSize: 16, color: Colors.grey),
  ),
  const SizedBox(height: 50),

  TextButton(
    style: TextButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.all(15),
    ),
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SosReportPage()),
      );
    },
    child: const Text("SOS", style: TextStyle(fontSize: 50)),
  ),
  const SizedBox(height: 24),

  OutlinedButton.icon(
    icon: const Icon(Icons.medical_services_outlined),
    label: const Text('Get Help (Not SOS)'),
    onPressed: () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TieredReportPage(),
        ),
      );
    },
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    ),
  ),
  const SizedBox(height: 12),
],
// --- END CUSTOMER TOOLS ------------------------------------------------

// Offline guides: EVERYONE can see them (user/helper/admin).
OutlinedButton.icon(
  onPressed: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OfflineMedicalGuidesPage(),
      ),
    );
  },
  style: OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFFFC3B3C),
    side: const BorderSide(color: Color(0xFFFC3B3C)),
    padding: const EdgeInsets.all(20),
  ),
  icon: const Icon(Icons.local_hospital),
  label: const Text(
    'View Offline Medical Guides',
    style: TextStyle(fontSize: 15),
  ),
),
const SizedBox(height: 12),

// --- Active Emergencies (Firestore) ----------------------------------------
// Only visible to admin + helper.
if (widget.isAdmin || widget.isHelper) ...[
  Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        const Align(
          alignment: Alignment.center,
          child: Text(
            'Active Emergencies',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
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
                  child: Text(
                    'No active emergencies.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
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
                  final status =
                      (data['status'] ?? 'pending') as String;

                  return ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmergencyDetailPage(
                            requestId: d.id,
                            data: data,
                          ),
                        ),
                      );
                    },
                    leading: _severityChipFromString(severity),
                    title: Text(reporterName),
                    subtitle: Text(
                      '${location ?? 'unknown location'} — '
                      '${_previewText(description)}\n'
                      'Status: ${status.toUpperCase()}',
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
],
// --- /Active Emergencies -----------------------------------------------------

            ],
          ),
        ),
      ),
      // Bottom navigation
      // Ordering rules:
      // - Home is always present at index 0.
      // - If `isAdmin` is true, Roles is inserted at index 1 and Settings
      //   becomes the last item. The tap handler (`_onNavTap`) depends on
      //   these indexes; update both locations when modifying the bar.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          if (widget.isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Roles',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

    // ---------- Firestore helper actions for Active Emergencies ----------

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
                await doc.reference.update({
                  'status': 'accepted',
                  'acceptedBy': user.uid,
                  'acceptedAt': FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                final updatedData = Map<String, dynamic>.from(data);
                updatedData['status'] = 'accepted';
                updatedData['acceptedBy'] = user.uid;

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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to accept: $e')),
                );
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

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

  Widget _severityChipFromString(String? s) {
    final label = _severityLabel(s);
    Color bg = const Color(0xFFE0E0E0);
    Color fg = const Color(0xFF424242);

    if (s == 'minor') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (s == 'urgent') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFEF6C00);
    } else if (s == 'critical') {
      bg = const Color(0xFFFFEBEE);
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _previewText(String text, {int words = 6}) {
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

// Small disclaimer shown at the bottom of the AppBar. Kept as a separate
// widget to keep the Dashboard build method compact. Implements
// PreferredSizeWidget so it can be naturally supplied to AppBar.bottom.
class _DisclaimerAppBarBottom extends StatelessWidget
    implements PreferredSizeWidget {
  final VoidCallback onClose;
  const _DisclaimerAppBarBottom({required this.onClose});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8E1), // light amber
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'For educational purposes only — if this is a real emergency, call 911.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          // Compact dismiss control — invokes the callback passed from the
          // Dashboard to toggle visibility. Use a callback here instead of
          // accessing parent state directly to keep the widget reusable.
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 18,
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

}

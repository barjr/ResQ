import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/pages/customer_view.dart';
import 'package:resq/pages/helper_view.dart';
import 'package:resq/pages/admin_view.dart';
import 'package:resq/pages/sos_report.dart';
import 'package:resq/services/request_store.dart';
import 'package:resq/models/help_request.dart';
import 'package:resq/pages/tiered_report.dart';

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
  const DashboardPage({super.key, this.isAdmin = false});

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
      (Navigator.of(context)
          .push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Settings'),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                body: const Center(
                  child: Text(
                    'Under construction :(',
                    style: TextStyle(fontSize: 30),
                  ),
                ),
              ),
            ),
          )
          .then((_) {
            setState(() {
              _selectedIndex = 0;
            });
          }));
    }
    // Roles tab for admins: when an admin taps the Roles tab (index 1)
    // we push the `AdminViewPage` which contains the role-management UI.
    // We then reset the selected index back to Home when the admin returns.
    if (widget.isAdmin && index == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AdminViewPage()),
      ).then((_) => setState(() => _selectedIndex = 0));
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signed out')),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out failed: $e')),
                );
              }
            },
          ),
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
              Text(
                "Are you in an emergency?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 30),
              ),
              SizedBox(height: 16),
              Text(
                "If so, please press the button below.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 50),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SosReportPage()),
                  );
                },
                child: const Text("SOS", style: TextStyle(fontSize: 50)),
              ),
              const SizedBox(height: 24),
              // Not-SOS (Tiered Report) button
              OutlinedButton.icon(
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('Get Help (Not SOS)'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TieredReportPage()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CustomerViewPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Customer View'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelperViewPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text('Helper View'),
              ),

              // --- Active Emergencies ------------------------------------------------------
              // The list below is driven by `RequestStore.instance.stream`.
              // Each HelpRequest is rendered as a ListTile. The cancel flow
              // shows a confirmation dialog, removes the request from the
              // store on confirmation, and displays a SnackBar with an
              // UNDO action (which re-adds the request). Keep UI changes
              // guarded with `context.mounted` to avoid operating on a
              // disposed State after async gaps.
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
                    const Divider(height: 1,),
                    const SizedBox(height: 8),

                    // List takes the remaining space and scrolls
                    Expanded(
                      child: StreamBuilder<List<HelpRequest>>(
                        stream: RequestStore.instance.stream,
                        builder: (context, snapshot) {
                          final items = snapshot.data ?? const <HelpRequest>[];

                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                'No active emergencies.',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = items[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,

                                // ---------- Show severity chip ----------
                                leading: _severityChip(r.severity),
                                // ------------------------------------------------

                                title: Text(
                                  _preview(r.description),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    _formatTime(r.createdAt),
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Cancel emergency?'),
                                        content: const Text(
                                          'This will remove the emergency from your active list.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text('No'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Yes, cancel'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      final removed = r;
                                      RequestStore.instance.removeRequest(r.id);

                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Emergency canceled',
                                          ),
                                          action: SnackBarAction(
                                            label: 'UNDO',
                                            onPressed: () {
                                              // ---------- Restore full request ----------
                                              RequestStore.instance.addRequest(
                                                description:
                                                    removed.description,
                                                location: removed.location,
                                                reporterName:
                                                    removed.reporterName,
                                                severity: removed.severity,
                                                source: removed.source,
                                              );
                                              // ------------------------------------------------
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Cancel'),
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

  // ---------- Severity chip helper --------------------------------------
  Widget _severityChip(Severity s) {
    String label = 'UNKNOWN';
    Color bg = const Color(0xFFE0E0E0);
    Color fg = const Color(0xFF424242);

    if (s == Severity.minor) {
      label = 'MINOR';
      bg = const Color(0xFFE8F5E9); // light green
      fg = const Color(0xFF2E7D32);
    } else if (s == Severity.urgent) {
      label = 'URGENT';
      bg = const Color(0xFFFFF3E0); // light orange
      fg = const Color(0xFFEF6C00);
    } else if (s == Severity.critical) {
      label = 'CRITICAL';
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime dt) {
    // h:mm AM/PM without bringing in intl
    String two(int v) => v.toString().padLeft(2, '0');
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${two(dt.minute)} $ampm';
  }

  String _preview(String text, {int words = 8}) {
    final tokens =
        text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return '(No description)';
    final head = tokens.take(words).join(' ');
    return tokens.length > words ? '$head…' : head;
  }
}

// Small disclaimer shown at the bottom of the AppBar. Kept as a separate
// widget to keep the Dashboard build method compact. Implements
// PreferredSizeWidget so it can be naturally supplied to AppBar.bottom.
class _DisclaimerAppBarBottom extends StatelessWidget implements PreferredSizeWidget {
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

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/customer_view.dart';
import 'package:resq/pages/helper_view.dart';
import 'package:resq/pages/sos_report.dart';
import 'package:resq/services/request_store.dart';
import 'package:resq/models/help_request.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

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
    if (index == 1) {
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
              await FirebaseAuth.instance.signOut();
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Active Emergencies',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = items[i];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
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
                                              RequestStore.instance.addRequest(
                                                description:
                                                    removed.description,
                                                location: removed.location,
                                                reporterName: 'Anonymous',
                                              );
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    // h:mm AM/PM without bringing in intl
    String two(int v) => v.toString().padLeft(2, '0');
    final hour12 = (dt.hour % 12 == 0) ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${two(dt.minute)} $ampm';
  }

  String _preview(String text, {int words = 8}) {
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

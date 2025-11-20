import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:resq/pages/medical_documents_page.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  bool _consentSms = false;
  bool _consentMedicalAccess = false;
  bool _consentLocation = false; // new

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data != null) {
        _nameCtrl.text = (data['name'] ?? '').toString();
        _phoneCtrl.text = (data['phone'] ?? '').toString();

        final ec = data['emergencyContact'] as Map<String, dynamic>?;
        _ecNameCtrl.text = (ec?['name'] ?? '').toString();
        _ecPhoneCtrl.text = (ec?['phone'] ?? '').toString();

        _allergiesCtrl.text = (data['allergies'] ?? '').toString();
        _conditionsCtrl.text = (data['conditions'] ?? '').toString();
        _medicationsCtrl.text = (data['medications'] ?? '').toString();

        _consentSms = (data['consentSms'] ?? false) as bool;
        _consentMedicalAccess =
            (data['consentMedicalAccess'] ?? false) as bool;
        _consentLocation = (data['consentLocation'] ?? false) as bool;
      }
    } catch (e) {
      debugPrint('Failed to load profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'emergencyContact': {
          'name': _ecNameCtrl.text.trim(),
          'phone': _ecPhoneCtrl.text.trim(),
        },
        'allergies': _allergiesCtrl.text.trim(),
        'conditions': _conditionsCtrl.text.trim(),
        'medications': _medicationsCtrl.text.trim(),
        'consentSms': _consentSms,
        'consentMedicalAccess': _consentMedicalAccess,
        'consentLocation': _consentLocation,
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFFC3B3C),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Profile section
                    Text(
                      'Profile',
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
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: _req,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: Icon(Icons.phone),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Emergency contact
                    Text(
                      'Emergency Contact',
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
                          children: [
                            TextFormField(
                              controller: _ecNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Contact Name',
                                prefixIcon: Icon(Icons.contact_phone),
                              ),
                              validator: _req,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _ecPhoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Phone',
                                prefixIcon: Icon(Icons.phone_in_talk),
                              ),
                              validator: _req,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Permissions
                    Text(
                      'Permissions',
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
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Share my location in emergencies'),
                            subtitle: const Text(
                              'When enabled, ResQ may use your device location '
                              'to help responders find you (a future feature).',
                            ),
                            value: _consentLocation,
                            onChanged: (v) {
                              setState(() => _consentLocation = v);
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text('Allow SMS alerts as backup'),
                            value: _consentSms,
                            onChanged: (v) {
                              setState(() => _consentSms = v);
                            },
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            title: const Text(
                              'Allow responders to view my medical profile',
                            ),
                            subtitle: const Text(
                              'Includes allergies, conditions, and medications.',
                            ),
                            value: _consentMedicalAccess,
                            onChanged: (v) {
                              setState(() => _consentMedicalAccess = v);
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Medical profile
                    Text(
                      'Medical Profile',
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
                          children: [
                            TextFormField(
                              controller: _allergiesCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Allergies (comma-separated)',
                                prefixIcon: Icon(Icons.warning_amber),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _conditionsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Conditions (comma-separated)',
                                prefixIcon: Icon(Icons.medical_information),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _medicationsCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Medications (comma-separated)',
                                prefixIcon: Icon(Icons.local_pharmacy),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Medical documents (moved from Dashboard)
                    Text(
                      'Medical Documents',
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
                      child: ListTile(
                        leading: const Icon(Icons.folder_shared),
                        title: const Text('Manage My Medical Documents'),
                        subtitle: const Text(
                          'Upload hospital PDFs, doctor notes, and other files.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MedicalDocumentsPage(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Save button
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

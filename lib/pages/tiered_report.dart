import 'package:flutter/material.dart';
import 'package:resq/services/request_store.dart';
import 'package:resq/models/help_request.dart' show Severity, Source;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/sos_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:resq/services/location_service.dart';

enum _LocalSeverity { minor, urgent, critical }

class TieredReportPage extends StatefulWidget {
  const TieredReportPage({super.key});

  @override
  State<TieredReportPage> createState() => _TieredReportPageState();
}

class _TieredReportPageState extends State<TieredReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  _LocalSeverity? _selected;

  double? _lat;
  double? _lng;

  @override
  void dispose() {
    _descCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  String _currentReporterName() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'Anonymous';

    final email = u.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }

    final dn = u.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;

    // last-resort stable identifier
    final uid = u.uid;
    return uid.length > 6 ? uid.substring(0, 6) : uid;
  }

  void _onSelect(_LocalSeverity sev) {
    setState(() => _selected = sev);
  }

  Future<void> _submit() async {
    if (_selected == null || _selected == _LocalSeverity.critical) return;
    if (!_formKey.currentState!.validate()) return;

    final severity = _selected == _LocalSeverity.minor
        ? Severity.minor
        : Severity.urgent;

    final reporter = _currentReporterName();
    final currentUser = FirebaseAuth.instance.currentUser;
    final reporterUid = currentUser?.uid;

    try {
      await FirebaseFirestore.instance.collection('emergency_requests').add({
        'reporterUid': reporterUid,
        'reporterName': reporter,
        'description': _descCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'severity': severity.name,
        'source': 'report',
        'lat': _lat,
        'lng': _lng,
      });

      RequestStore.instance.addRequest(
        reporterName: reporter,
        description: _descCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        severity: severity,
        source: Source.report,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted as ${severity.name.toUpperCase()}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to submit tiered report: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Get Help (Not SOS)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('What kind of emergency are you having?', style: t.titleMedium),
          const SizedBox(height: 12),

          SegmentedButton<_LocalSeverity>(
            multiSelectionEnabled: false,
            emptySelectionAllowed: true, // start with nothing selected
            segments: const [
              ButtonSegment(
                value: _LocalSeverity.minor,
                label: Text('Minor'),
                icon: Icon(Icons.healing_outlined),
              ),
              ButtonSegment(
                value: _LocalSeverity.urgent,
                label: Text('Urgent'),
                icon: Icon(Icons.medical_services_outlined),
              ),
              ButtonSegment(
                value: _LocalSeverity.critical,
                label: Text('Critical'),
                icon: Icon(Icons.warning_amber_outlined),
              ),
            ],
            selected: _selected == null ? <_LocalSeverity>{} : {_selected!},
            onSelectionChanged: (newSel) {
              if (newSel.isEmpty) {
                setState(() => _selected = null);
                return;
              }
              _onSelect(newSel.first);
            },
          ),
          const SizedBox(height: 8),
          if (_selected == _LocalSeverity.minor)
            Text('Small cut, bruise, mild headache', style: t.bodySmall),
          if (_selected == _LocalSeverity.urgent)
            Text('Dizziness, dehydration signs, sprain', style: t.bodySmall),
          if (_selected == _LocalSeverity.critical)
            Text(
              'Severe bleeding, unconscious, breathing trouble',
              style: t.bodySmall,
            ),

          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          if (_selected == _LocalSeverity.minor ||
              _selected == _LocalSeverity.urgent)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Tell us what’s wrong. This is not a panic alert.',
                    style: t.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 5,
                    minLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Describe the problem (required)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Please enter a brief description.'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Location (optional)',
                            hintText: 'e.g., Near main stage / 2nd-floor hall',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Use my current location',
                        icon: const Icon(Icons.my_location),
                        onPressed: () async {
                          final pos =
                              await LocationService.getCurrentPosition();
                          if (!mounted) return;
                          if (pos == null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Unable to get location. Check permissions.',
                                    ),
                                  ),
                                );
                              }
                            });
                            return;
                          }
                          setState(() {
                            _lat = pos.latitude;
                            _lng = pos.longitude;
                            _locationCtrl.text =
                                'Lat: ${pos.latitude.toStringAsFixed(5)}, '
                                'Lng: ${pos.longitude.toStringAsFixed(5)}';
                          });
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      _selected == _LocalSeverity.minor
                          ? 'Submit as Minor'
                          : 'Submit as Urgent',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          if (_selected == _LocalSeverity.critical)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Critical issues are handled by the SOS report.',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Open SOS Report'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SosReportPage()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
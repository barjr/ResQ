// lib/pages/create_account.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resq/pages/mfa_enrollment.dart';
import 'package:resq/pages/home.dart';


// Error message helper (copied from home.dart)
String _friendlyError(dynamic e) {
  if (e is Exception && e.toString().contains('email-already-in-use')) {
    return 'Email already in use.';
  }
  if (e is Exception && e.toString().contains('invalid-email')) {
    return 'Invalid email address.';
  }
  if (e is Exception && e.toString().contains('weak-password')) {
    return 'Password is too weak.';
  }
  if (e is Exception && e.toString().contains('operation-not-allowed')) {
    return 'Email/password sign-in is disabled.';
  }
  if (e is Exception && e.toString().contains('user-disabled')) {
    return 'This user has been disabled.';
  }
  return e is Exception
      ? e.toString().replaceFirst('Exception: ', '')
      : 'Unknown error.';
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _medicalIdCtrl = TextEditingController();

  // Bystander
  bool _isBystander = false;
  final _certIssuerCtrl = TextEditingController();
  final _credentialIdCtrl = TextEditingController();
  DateTime? _certExpiresOn;
  String? _uploadedCertPlaceholder;

  // Medical Profile
  bool _addMedicalProfile = false;
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();

  // Consents
  bool _consentSms = false;
  bool _consentMedicalAccess = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _medicalIdCtrl.dispose();
    _certIssuerCtrl.dispose();
    _credentialIdCtrl.dispose();
    _allergiesCtrl.dispose();
    _conditionsCtrl.dispose();
    _medicationsCtrl.dispose();
    super.dispose();
  }

  // Validators

  String _chosenRole = 'user';

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _email(String? v) {
    if ((v == null || v.isEmpty)) return 'Required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'Enter a valid email (e.g. user@example.com)';
  }

  String? _phone(String? v) {
    if ((v == null || v.isEmpty)) return 'Required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10
        ? null
        : 'Enter a 10-digit phone (e.g. 555-123-4567)';
  }

  String? _password(String? v) {
    if ((v == null || v.isEmpty)) return 'Required';
    return v.length >= 8 ? null : 'At least 8 characters';
  }

  String? _confirm(String? v) {
    if ((v == null || v.isEmpty)) return 'Required';
    return v == _passwordCtrl.text ? null : 'Passwords do not match';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: DateTime(now.year - 25),
    );
    if (picked != null) _dobCtrl.text = _fmtDate(picked);
  }

  Future<void> _pickCertExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      initialDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _certExpiresOn = picked);
  }

  String _fmtDate(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _submit() async {
  final valid = _formKey.currentState?.validate() ?? false;
  if (!valid) return;

  if (_isBystander) {
    if (_certIssuerCtrl.text.trim().isEmpty ||
        _certExpiresOn == null ||
        (_uploadedCertPlaceholder == null || _uploadedCertPlaceholder!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all bystander fields.')),
      );
      return;
    }
  }
  if (_addMedicalProfile && !_consentMedicalAccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please allow medical profile access or uncheck.')),
    );
    return;
  }

  try {
    // 1) Create user
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    final user = cred.user!;
    await user.updateDisplayName(_nameCtrl.text.trim());

    // 2) Create/merge Firestore user doc (mirror)
    final uid = user.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': _emailCtrl.text.trim(),
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'dob': _dobCtrl.text.trim(),
      'emergencyContact': {
        'name': _ecNameCtrl.text.trim(),
        'phone': _ecPhoneCtrl.text.trim(),
      },
      'medicalId': _medicalIdCtrl.text.trim().isEmpty ? null : _medicalIdCtrl.text.trim(),
      'isBystander': _isBystander,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    //WAIT FOR FIREBASE
    final callable = FirebaseFunctions.instance.httpsCallable('selfSetRole');
    await callable.call({'role': _chosenRole}); // 'helper' or 'user'
    await user.getIdToken(true); // refresh so RoleRouter sees it now


    // 3) If helper chosen, set claim via selfSetRole (user can opt-in)
    if (_chosenRole == 'helper') {
      final callable = FirebaseFunctions.instance.httpsCallable('selfSetRole');
      await callable.call({'role': 'helper'});
    } else {
      // Ensure claim is "user" (optional; usually defaults null and router treats as user)
      final callable = FirebaseFunctions.instance.httpsCallable('selfSetRole');
      await callable.call({'role': 'user'});
    }

    // 4) Refresh token so RoleRouter immediately routes by claim
    await user.getIdToken(true);

    // 5) (Optional) Start MFA enrollment later when backend flips the switch
    await MfaEnrollment.maybeStartAfterSignup(
      context,
      phoneRaw: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created!')),
    );
    Navigator.pop(context); // back to Home; AuthGate/RoleRouter will take over
  } catch (e) {
    final msg = _friendlyError(e);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Account creation failed: $msg')),
    );
  }
}

  // InputDecoration helper with short, example-style hints
  InputDecoration _dec(String label, {bool required = false, String? hint}) {
    return InputDecoration(
      labelText: required ? '$label *' : label,
      hintText: hint,
      // Keep hints readable but compact
      hintStyle: const TextStyle(color: Colors.black54),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFFFC3B3C),
        title: const Text(
          'Create your ResQ account',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text(
                      'Fields marked with * are required.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  // AUTH
                  _sectionTitle('Authentication'),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('Email', required: true, hint: 'e.g. name@example.com'),
                    validator: _email,
                  ),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: _dec('Password', required: true, hint: '8+ characters'),
                    validator: _password,
                  ),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration: _dec('Confirm Password', required: true, hint: 'Retype password'),
                    validator: _confirm,
                  ),
                  // Role choice
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('Choose your role (you can change later)', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('User'),
                          value: 'user',
                          groupValue: _chosenRole,
                          onChanged: (v) => setState(() => _chosenRole = v ?? 'user'),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Helper'),
                          value: 'helper',
                          groupValue: _chosenRole,
                          onChanged: (v) => setState(() => _chosenRole = v ?? 'user'),
                        ),
                      ),
                    ],
                  ),

                  // PROFILE
                  _sectionTitle('Basic Profile'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _dec('Full Name', required: true, hint: 'e.g. Alex Johnson'),
                    validator: _req,
                  ),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\(\)\s]')),
                    ],
                    decoration: _dec('Phone Number', required: true, hint: 'e.g. 555-123-4567'),
                    validator: _phone,
                  ),
                  GestureDetector(
                    onTap: _pickDob,
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller: _dobCtrl,
                        decoration: _dec('Date of Birth', required: true, hint: 'MM/DD/YYYY'),
                        validator: _req,
                      ),
                    ),
                  ),
                  TextFormField(
                    controller: _ecNameCtrl,
                    decoration: _dec('Emergency Contact Name', required: true, hint: 'e.g. Jamie Lee'),
                    validator: _req,
                  ),
                  TextFormField(
                    controller: _ecPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\-\(\)\s]')),
                    ],
                    decoration: _dec('Emergency Contact Phone', required: true, hint: 'e.g. 555-987-6543'),
                    validator: _phone,
                  ),

                  // MEDICAL ID
                  _sectionTitle('Medical ID (optional)'),
                  TextFormField(
                    controller: _medicalIdCtrl,
                    maxLength: 15,
                    decoration: _dec('Medical ID', hint: 'Existing hospital/bracelet ID (leave blank if none)'),
                  ),

                  // BYSTANDER
                  _sectionTitle('Bystander Certification (optional)'),
                  SwitchListTile(
                    title: const Text('I am CPR/First Aid certified'),
                    value: _isBystander,
                    onChanged: (v) => setState(() => _isBystander = v),
                  ),
                  if (_isBystander) ...[
                    TextFormField(
                      controller: _certIssuerCtrl,
                      decoration: _dec('Certification Issuer', required: true, hint: 'e.g. American Red Cross'),
                      validator: (v) => _isBystander ? _req(v) : null,
                    ),
                    TextFormField(
                      controller: _credentialIdCtrl,
                      decoration: _dec('Credential ID (optional)', hint: 'If provided on your card'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _certExpiresOn == null
                            ? 'Expiration Date *'
                            : 'Expiration Date * — ${_fmtDate(_certExpiresOn!)}',
                      ),
                      trailing: OutlinedButton(
                        onPressed: _pickCertExpiry,
                        child: const Text('Pick date'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _uploadedCertPlaceholder == null
                            ? 'Upload Document *'
                            : 'Uploaded: $_uploadedCertPlaceholder',
                      ),
                      trailing: OutlinedButton(
                        onPressed: () => setState(() => _uploadedCertPlaceholder = 'certification.pdf'),
                        child: const Text('Choose file'),
                      ),
                    ),
                  ],

                  // MEDICAL PROFILE
                  _sectionTitle('Medical Profile (optional)'),
                  SwitchListTile(
                    title: const Text('Add a medical profile for responders'),
                    value: _addMedicalProfile,
                    onChanged: (v) => setState(() => _addMedicalProfile = v),
                  ),
                  if (_addMedicalProfile) ...[
                    TextFormField(
                      controller: _allergiesCtrl,
                      decoration: _dec('Allergies (comma-separated)', hint: 'e.g. Peanuts, Latex'),
                    ),
                    TextFormField(
                      controller: _conditionsCtrl,
                      decoration: _dec('Conditions (comma-separated)', hint: 'e.g. Asthma, Diabetes'),
                    ),
                    TextFormField(
                      controller: _medicationsCtrl,
                      decoration: _dec('Medications (comma-separated)', hint: 'e.g. Insulin, Epipen'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _consentMedicalAccess,
                      onChanged: (v) => setState(() => _consentMedicalAccess = v ?? false),
                      title: const Text('Allow responders to view my medical profile during emergencies'),
                    ),
                  ],

                  // CONSENTS
                  _sectionTitle('Consent & Privacy'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _consentSms,
                    onChanged: (v) => setState(() => _consentSms = v ?? false),
                    title: const Text('Allow SMS alerts as backup'),
                  ),

                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Create Account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('I’ll finish setup later'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

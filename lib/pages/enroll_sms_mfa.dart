// lib/pages/enroll_sms_mfa_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/services/role_router.dart';

class EnrollSmsMfaPage extends StatefulWidget {
  final String? phonePrefill;
  const EnrollSmsMfaPage({super.key, this.phonePrefill});

  @override
  State<EnrollSmsMfaPage> createState() => _EnrollSmsMfaPageState();
}

class _EnrollSmsMfaPageState extends State<EnrollSmsMfaPage> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _verificationId;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.phonePrefill != null && widget.phonePrefill!.isNotEmpty) {
      _phoneCtrl.text = widget.phonePrefill!;
    }
  }

  Future<void> _sendCode() async {
    final user = FirebaseAuth.instance.currentUser!;
    if (!user.emailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verify email first')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final session = await user.multiFactor.getSession();

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneCtrl.text.trim(),     // Make sure it’s E.164 if needed
        multiFactorSession: session,
        verificationCompleted: (_) {},           // We handle manual code entry
        verificationFailed: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: ${e.message}')),
          );
        },
        codeSent: (verificationId, _) {
          setState(() => _verificationId = verificationId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code sent')),
          );
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _enroll() async {
    final user = FirebaseAuth.instance.currentUser!;
    if (_verificationId == null) return;
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeCtrl.text.trim(),
      );
      final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
      await user.multiFactor.enroll(
        assertion,
        displayName: 'Primary phone',
      );

      await user.getIdToken(true); // refresh claims just in case

      if (!mounted) return;
      // Done → route by role
      await routeByRole(context, FirebaseAuth.instance.currentUser!);
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enroll failed: ${e.code} ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVerification = _verificationId != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up SMS 2-Step')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Mobile number (+1XXXXXXXXXX)',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _sendCode,
              child: Text(_sending ? 'Sending…' : 'Send code'),
            ),
            const Divider(height: 32),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'SMS code',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: hasVerification ? _enroll : null,
              child: const Text('Enroll phone'),
            ),
          ],
        ),
      ),
    );
  }
}

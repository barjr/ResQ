import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MfaEnrollPage extends StatefulWidget {
  const MfaEnrollPage({super.key});
  @override
  State<MfaEnrollPage> createState() => _MfaEnrollPageState();
}

class _MfaEnrollPageState extends State<MfaEnrollPage> {
  final _phoneCtrl = TextEditingController();   // (555) 123-4567, we’ll normalize
  final _smsCodeCtrl = TextEditingController();
  final _totpCodeCtrl = TextEditingController();

  String? _status;
  String? _verificationId; // for SMS flow
  // For TOTP flow:
  String? _totpUri;        // otpauth:// for QR
  String? _totpSecret;     // base32 secret (display fallback)
  dynamic _totpSecretObj;  // firebase_auth TotpSecret (kept in memory)

  bool _enrolling = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsCodeCtrl.dispose();
    _totpCodeCtrl.dispose();
    super.dispose();
  }

  String _toE164(String raw) {
    // naive US normalization for demo; replace with libphonenumber if needed
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.startsWith('1') && digits.length == 11) return '+$digits';
    if (digits.startsWith('+')) return raw;
    return '+$digits';
  }

  Future<void> _enrollSms() async {
    setState(() { _status = null; _enrolling = true; });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() { _status = 'Not signed in.'; _enrolling = false; }); return; }

    try {
      final session = await user.multiFactor.getSession();

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _toE164(_phoneCtrl.text.trim()),
        multiFactorSession: session,
        verificationCompleted: (cred) async {
          // Instant verification or auto-retrieval
          final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
          await user.multiFactor.enroll(assertion, displayName: 'Primary phone');
          setState(() { _status = 'SMS factor enrolled ✓'; _enrolling = false; });
        },
        verificationFailed: (e) {
          setState(() { _status = 'SMS verify failed: ${e.message}'; _enrolling = false; });
        },
        codeSent: (vid, _) async {
          setState(() { _verificationId = vid; _status = 'Code sent. Check SMS.'; _enrolling = false; });
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
        forceResendingToken: null,
      );
    } catch (e) {
      setState(() { _status = 'Enroll error: $e'; _enrolling = false; });
    }
  }

  Future<void> _confirmSmsCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _verificationId == null) return;
    setState(() { _enrolling = true; _status = null; });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeCtrl.text.trim(),
      );
      final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
      await user.multiFactor.enroll(assertion, displayName: 'Primary phone');
      setState(() { _status = 'SMS factor enrolled ✓'; _enrolling = false; });
    } catch (e) {
      setState(() { _status = 'Code error: $e'; _enrolling = false; });
    }
  }

Future<void> _enrollTotp() async {
  setState(() { _status = null; _enrolling = true; _totpUri = null; _totpSecret = null; });
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) { setState(() { _status = 'Not signed in.'; _enrolling = false; }); return; }

  try {
    final session = await user.multiFactor.getSession();

    // 1) Generate the TOTP secret object
    final secret = await TotpMultiFactorGenerator.generateSecret(session);
    _totpSecretObj = secret;

    // 2) Build the otpauth:// QR URL (await + named args)
    final email = user.email ?? 'account';
    final uri = await secret.generateQrCodeUrl(
      accountName: email,
      issuer: 'ResQ',
    );

    // 3) Optionally deep-link to authenticator app (best-effort)
    await secret.openInOtpApp(uri);

    setState(() {
      _totpUri   = uri;               // String
      _totpSecret = secret.secretKey; // <- correct property name
      _status = 'Scan the QR in your authenticator, then enter the 6-digit code.';
      _enrolling = false;
    });
  } catch (e) {
    setState(() { _status = 'TOTP setup failed: $e'; _enrolling = false; });
  }
}

Future<void> _confirmTotp() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || _totpSecretObj == null) return;
  setState(() { _enrolling = true; _status = null; });

  try {
    final code = _totpCodeCtrl.text.trim();
    final assertion = await TotpMultiFactorGenerator.getAssertionForEnrollment(
      _totpSecretObj, code,
    );
    await user.multiFactor.enroll(assertion, displayName: 'Authenticator app');
    setState(() { _status = 'TOTP factor enrolled ✓'; _enrolling = false; });
  } catch (e) {
    setState(() { _status = 'TOTP code error: $e'; _enrolling = false; });
  }
}


  @override
  Widget build(BuildContext context) {
    final busy = _enrolling;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up 2-Step Verification'),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: Colors.white)),
          )
        ],
        backgroundColor: const Color(0xFFFC3B3C),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Choose a second factor'),
          const SizedBox(height: 12),

          // ---------- SMS ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Text message (SMS)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '(555) 123-4567',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : _enrollSms,
                    child: const Text('Send code'),
                  ),
                  if (_verificationId != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smsCodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SMS code',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: busy ? null : _confirmSmsCode,
                      child: const Text('Confirm & enroll'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---------- TOTP ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Authenticator App (TOTP)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : _enrollTotp,
                    child: const Text('Generate secret & open authenticator'),
                  ),
                  if (_totpUri != null) ...[
                    const SizedBox(height: 8),
                    // Minimal fallback: show secret text if QR open didn’t work.
                    SelectableText('Secret: ${_totpSecret ?? ''}'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _totpCodeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '6-digit code from app',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: busy ? null : _confirmTotp,
                      child: const Text('Confirm & enroll'),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: TextStyle(color: Colors.grey[800])),
          ],
        ],
      ),
    );
  }
}

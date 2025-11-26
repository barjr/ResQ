import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:resq/pages/home.dart';
import 'package:resq/services/role_router.dart';
import 'package:resq/constants/mfa_whitelist.dart';

class MfaEnrollPage extends StatefulWidget {
  const MfaEnrollPage({super.key});

  @override
  State<MfaEnrollPage> createState() => _MfaEnrollPageState();
}

class _MfaEnrollPageState extends State<MfaEnrollPage> {
  final _phoneCtrl = TextEditingController(); // (555) 123-4567, we’ll normalize
  final _smsCodeCtrl = TextEditingController();
  final _totpCodeCtrl = TextEditingController();

  String? _status;
  String? _verificationId; // for SMS flow

  // For TOTP flow:
  String? _totpUri; // otpauth:// for QR
  String? _totpSecret; // base32 secret (display fallback)
  dynamic _totpSecretObj; // firebase_auth TotpSecret (kept in memory)

  bool _enrolling = false;

  // Requirement tracker
  bool _emailVerified = false;
  bool _smsEnrolled = false;
  bool _totpEnrolled = false;

  @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _refreshStatus();
    await _checkWhitelistBypass();
  });
}


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

  Future<void> _checkWhitelistBypass() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  final email = user.email?.toLowerCase().trim();

  if (email != null && mfaBypassEmails.contains(email)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('MFA bypass enabled for $email'),
      ),
    );

    await routeByRole(context, user);
  }
}



  Future<void> _refreshStatus() async {
    final auth = FirebaseAuth.instance;
    var user = auth.currentUser;
    if (user == null) return;

    await user.reload();
    user = auth.currentUser;
    if (user == null || !mounted) return;

    final factors = await user.multiFactor.getEnrolledFactors();
    bool sms = false;
    bool totp = false;

    for (final f in factors) {
      // These type checks come from firebase_auth’s MultiFactorInfo subclasses
      if (f is PhoneMultiFactorInfo) {
        sms = true;
      }
      if (f is TotpMultiFactorInfo) {
        totp = true;
      }
    }

    setState(() {
      _emailVerified = user!.emailVerified;
      _smsEnrolled = sms;
      _totpEnrolled = totp;
    });
  }

  Future<void> _enrollSms() async {
    setState(() {
      _status = null;
      _enrolling = true;
    });

    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _status = 'Not signed in.';
        _enrolling = false;
      });
      return;
    }

    // 🔄 Always reload before checking emailVerified
    await user.reload();
    user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _status = 'User signed out.';
        _enrolling = false;
      });
      return;
    }

    // Update tracker
    _emailVerified = user.emailVerified;

    if (!user.emailVerified) {
      try {
        await user.sendEmailVerification();
        final email = user.email ?? 'your email address';

        setState(() {
          _status = 'We sent a verification email to $email.\n'
              'After verifying, come back here and tap "Send code" again.';
          _enrolling = false;
        });
      } on FirebaseAuthException catch (e) {
        if (e.code == 'too-many-requests') {
          setState(() {
            _status = 'Too many verification requests. Please wait a few minutes '
                'and then try again.';
            _enrolling = false;
          });
        } else {
          setState(() {
            _status = 'Error sending verification email: ${e.message}';
            _enrolling = false;
          });
        }
      }
      return;
    }

    try {
      final session = await user.multiFactor.getSession();

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _toE164(_phoneCtrl.text.trim()),
        multiFactorSession: session,
        verificationCompleted: (cred) async {
          final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
          await user!.multiFactor.enroll(
            assertion,
            displayName: 'Primary phone',
          );
          await _refreshStatus();
          setState(() {
            _status = 'SMS factor enrolled ✓';
            _enrolling = false;
          });
        },
        verificationFailed: (e) {
          setState(() {
            _status = 'SMS verify failed: ${e.message}';
            _enrolling = false;
          });
        },
        codeSent: (vid, _) async {
          setState(() {
            _verificationId = vid;
            _status = 'Code sent. Check SMS.';
            _enrolling = false;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
        forceResendingToken: null,
      );
    } catch (e) {
      setState(() {
        _status = 'Enroll error: $e';
        _enrolling = false;
      });
    }
  }

  Future<void> _confirmSmsCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _verificationId == null) return;
    setState(() {
      _enrolling = true;
      _status = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _smsCodeCtrl.text.trim(),
      );
      final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
      await user.multiFactor.enroll(
        assertion,
        displayName: 'Primary phone',
      );
      await _refreshStatus();
      setState(() {
        _status = 'SMS factor enrolled ✓';
        _enrolling = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Code error: $e';
        _enrolling = false;
      });
    }
  }

  Future<void> _enrollTotp() async {
    setState(() {
      _status = null;
      _enrolling = true;
      _totpUri = null;
      _totpSecret = null;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _status = 'Not signed in.';
        _enrolling = false;
      });
      return;
    }

    try {
      final session = await user.multiFactor.getSession();

      // 1) Generate the TOTP secret object
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      _totpSecretObj = secret;

      // 2) Build the otpauth:// QR URL
      final email = user.email ?? 'account';
      final uri = await secret.generateQrCodeUrl(
        accountName: email,
        issuer: 'ResQ',
      );

      // 3) Optionally deep-link to authenticator app (best-effort)
      await secret.openInOtpApp(uri);

      setState(() {
        _totpUri = uri; // String
        _totpSecret = secret.secretKey; // base32
        _status =
            'Scan the QR in your authenticator, then enter the 6-digit code.';
        _enrolling = false;
      });
    } catch (e) {
      setState(() {
        _status = 'TOTP setup failed: $e';
        _enrolling = false;
      });
    }
  }

  Future<void> _confirmTotp() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _totpSecretObj == null) return;
    setState(() {
      _enrolling = true;
      _status = null;
    });

    try {
      final code = _totpCodeCtrl.text.trim();
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
        _totpSecretObj,
        code,
      );
      await user.multiFactor.enroll(
        assertion,
        displayName: 'Authenticator app',
      );
      await _refreshStatus();
      setState(() {
        _status = 'TOTP factor enrolled ✓';
        _enrolling = false;
      });
    } catch (e) {
      setState(() {
        _status = 'TOTP code error: $e';
        _enrolling = false;
      });
    }
  }

  void _goBackToLogin() {
    if (_enrolling) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

Future<void> _handleContinue() async {
  // Don’t proceed if requirements aren’t done or we’re in the middle of a call
  if (!(_emailVerified && _smsEnrolled) || _enrolling) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // If somehow signed out, just go back to login
    _goBackToLogin();
    return;
  }

  // Send user straight to the correct dashboard based on their role
  await routeByRole(context, user);
}


  Widget _buildRequirementRow({
    required String label,
    required bool completed,
    required bool requiredStep,
  }) {
    final icon = completed ? Icons.check_circle : Icons.close;
    final iconColor = completed ? Colors.green : Colors.red;
    final statusText = completed
        ? 'Success!'
        : (requiredStep ? 'Required' : 'Optional');

    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label – $statusText',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: completed ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _enrolling;
    final canContinue = _emailVerified && _smsEnrolled;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: busy ? null : _goBackToLogin,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Set up 2-Step Verification'),
        backgroundColor: const Color(0xFFFC3B3C),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --------- REQUIREMENT TRACKER ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account security checklist',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementRow(
                    label: 'Email verification',
                    completed: _emailVerified,
                    requiredStep: true,
                  ),
                  const SizedBox(height: 4),
                  _buildRequirementRow(
                    label: 'SMS 2-Step',
                    completed: _smsEnrolled,
                    requiredStep: true,
                  ),
                  const SizedBox(height: 4),
                  _buildRequirementRow(
                    label: 'Authenticator app (TOTP)',
                    completed: _totpEnrolled,
                    requiredStep: false,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Email verification and SMS 2-Step are required to finish creating your ResQ account. '
                    'TOTP is optional but recommended for extra security.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Choose a second factor'),
          const SizedBox(height: 12),

          // ---------- SMS ----------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Text message (SMS)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                  const Text(
                    'Authenticator App (TOTP)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: busy ? null : _enrollTotp,
                    child: const Text('Generate secret & open authenticator'),
                  ),
                  if (_totpUri != null) ...[
                    const SizedBox(height: 8),
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
            Text(
              _status!,
              style: TextStyle(color: Colors.grey[800]),
            ),
          ],

          const SizedBox(height: 24),

          // ---------- CONTINUE BUTTON ----------
          if (canContinue)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : _handleContinue,
                child: const Text('Continue'),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/services/role_router.dart';

class SmsMfaSignInPage extends StatefulWidget {
  final FirebaseAuthMultiFactorException exception;

  const SmsMfaSignInPage({super.key, required this.exception});

  @override
  State<SmsMfaSignInPage> createState() => _SmsMfaSignInPageState();
}

class _SmsMfaSignInPageState extends State<SmsMfaSignInPage> {
  late final MultiFactorResolver _resolver;
  PhoneMultiFactorInfo? _phoneHint;

  final _codeCtrl = TextEditingController();
  String? _verificationId;
  bool _sending = false;
  bool _verifying = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _resolver = widget.exception.resolver;

    // Assume only one phone factor for now.
    _phoneHint = _resolver.hints.firstWhere(
      (h) => h is PhoneMultiFactorInfo,
      orElse: () => throw StateError('No phone factor found'),
    ) as PhoneMultiFactorInfo;

    _sendCode();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _status = null;
    });

    try {
      final session = _resolver.session;
      final hint = _phoneHint;

      await FirebaseAuth.instance.verifyPhoneNumber(
        multiFactorSession: session,
        multiFactorInfo: hint, // <-- IMPORTANT: no phoneNumber here
        verificationCompleted: (PhoneAuthCredential cred) async {
          // Android auto-verification
          await _completeSignIn(cred);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _status = 'Verification failed: ${e.message}';
          });
        },
        codeSent: (String verificationId, int? _) {
          setState(() {
            _verificationId = verificationId;
            _status = 'Code sent to ${hint?.phoneNumber ?? "your phone"}.';
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _status = 'Error sending code: $e';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _completeSignIn(PhoneAuthCredential cred) async {
    setState(() {
      _verifying = true;
      _status = null;
    });

    try {
      await _resolver.resolveSignIn(
        PhoneMultiFactorGenerator.getAssertion(cred),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _status = 'Sign-in completed, but no user found.';
        });
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login successful (MFA).')),
      );
      await routeByRole(context, user);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _status = 'MFA sign-in failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = 'Unexpected error: $e';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _onConfirmPressed() async {
    if (_verificationId == null) {
      setState(() {
        _status = 'Request a code first.';
      });
      return;
    }

    final smsCode = _codeCtrl.text.trim();
    if (smsCode.length < 4) {
      setState(() {
        _status = 'Enter the SMS code.';
      });
      return;
    }

    final cred = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );
    await _completeSignIn(cred);
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = _phoneHint?.phoneNumber ?? 'your phone';

    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text(
            "RESQ",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFFFC3B3C),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 80,
                  color: Color(0xFFFC3B3C),
                ),
                const SizedBox(height: 24),
                Text(
                  'Two-step verification',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a code to $maskedPhone. Enter it below to finish signing in.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'SMS code',
                    prefixIcon: Icon(Icons.sms),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !_verifying,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _verifying ? null : _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC3B3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _verifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _sending ? null : _sendCode,
                  child: Text(_sending ? 'Resending…' : 'Resend code'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:resq/services/role_router.dart';

class SmsMfaSignInPage extends StatefulWidget {
  final MultiFactorResolver resolver;

  const SmsMfaSignInPage({super.key, required this.resolver});

  @override
  State<SmsMfaSignInPage> createState() => _SmsMfaSignInPageState();
}

class _SmsMfaSignInPageState extends State<SmsMfaSignInPage> {
  final _codeCtrl = TextEditingController();
  String? _verificationId;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startSmsFlow();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  PhoneMultiFactorInfo get _phoneFactor {
    // For now assume exactly one phone factor
    return widget.resolver.hints.firstWhere(
      (f) => f is PhoneMultiFactorInfo,
    ) as PhoneMultiFactorInfo;
  }

Future<void> _startSmsFlow() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phoneFactor.phoneNumber!,
        multiFactorSession: widget.resolver.session,
        multiFactorInfo: _phoneFactor,
        verificationCompleted: (PhoneAuthCredential cred) async {
          // auto-verification path
          await _completeSignIn(cred);
        },
        verificationFailed: (e) {
          setState(() => _error = e.message ?? 'SMS verification failed');
        },
        codeSent: (verificationId, _) {
          setState(() => _verificationId = verificationId);
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitCode() async {
    if (_verificationId == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeCtrl.text.trim(),
      );

      await _completeSignIn(cred);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Verification failed');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

Future<void> _completeSignIn(PhoneAuthCredential cred) async {
    final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
    final userCred = await widget.resolver.resolveSignIn(assertion);
    final user = userCred.user;

    if (!mounted) return;

    if (user == null) {
      setState(() => _error = 'Sign-in resolved but no user returned.');
      return;
    }

    await routeByRole(context, user);
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = _phoneFactor.phoneNumber ?? 'your phone';

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
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 100,
                  color: Color(0xFFFC3B3C),
                ),
                const SizedBox(height: 24),
                Text(
                  'Two-Step Verification',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a code to:\n$maskedPhone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'SMS Code',
                    prefixIcon: Icon(Icons.sms),
                  ),
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_verifying || _sending) ? null : _submitCode,
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
                  onPressed: _sending ? null : _startSmsFlow,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// lib/pages/verify_email_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'enroll_sms_mfa.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  final String? phonePrefill;
  const VerifyEmailPage({super.key, required this.email, this.phonePrefill});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Poll every 3s for emailVerified
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      await u.reload();
      if (u.emailVerified) {
        _poll?.cancel();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EnrollSmsMfaPage(phonePrefill: widget.phonePrefill),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('We sent a verification link to ${widget.email}. '
                 'Open the link, then return to this screen.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await u?.sendEmailVerification();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification email re-sent')),
                );
              },
              child: const Text('Resend email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await u?.reload();
                if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
                  if (!mounted) return;
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          EnrollSmsMfaPage(phonePrefill: widget.phonePrefill),
                    ),
                  );
                } else {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Not verified yet')),
                  );
                }
              },
              child: const Text("I've verified"),
            ),
          ],
        ),
      ),
    );
  }
}

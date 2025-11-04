import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/mfa_enroll_page.dart';

class MfaEnrollment {
  static bool get enabled => true; // flip ON when ready

  static Future<void> maybeStartAfterSignup(
    BuildContext context, {
    required String phoneRaw,
  }) async {
    if (!enabled) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // If already has a factor, don’t nag:
    final enrolled = await user.multiFactor.getEnrolledFactors();
    if (enrolled.isNotEmpty) return;

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MfaEnrollPage()),
    );
  }
}

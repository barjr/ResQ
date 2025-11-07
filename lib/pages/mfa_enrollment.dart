import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resq/pages/mfa_enroll_page.dart';

/// Flip this on when you want MFA to be required for new users.
/// (You can keep it true in dev if you enabled MFA in Console.)
const bool kRequireMfaForNewUsers = true;

class MfaEnrollment {
  /// Returns true if the user already has at least one enrolled factor.
  static Future<bool> hasAnyFactor(User user) async {
    final factors = await user.multiFactor.getEnrolledFactors();
    return factors.isNotEmpty;
  }

  /// If MFA is required and user has no factors, pushes the enrollment page.
  /// Returns true if the user now has a factor (i.e., can proceed).
  static Future<bool> requireAndEnrollIfNeeded(
    BuildContext context, {
    required User user,
    String? phoneHintRaw,
  }) async {
    if (!kRequireMfaForNewUsers) return true;

    // If user already has a factor, we’re good
    if (await hasAnyFactor(user)) return true;

    if (!context.mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MfaEnrollPage()),
    );

    // User may have enrolled or canceled; check again
    return await hasAnyFactor(user);
  }

  static Future<void> maybeStartAfterSignup(BuildContext context, {required String phoneRaw}) async {
    // TODO Implement this <later>
  }
}

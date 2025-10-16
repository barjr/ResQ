// lib/services/mfa_enrollment.dart

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // backend can uncomment when ready

class MfaEnrollment {
  /// Backend flips this to true later.
  static bool get enabled => false; // stays false for now

  /// Safe to call even if user isn't signed in yet — it just returns.
  static Future<void> maybeStartAfterSignup(
    BuildContext context, {
    required String phoneRaw,
  }) async {
    if (!enabled) return;

    // TODO(backend): normalize phoneRaw -> E.164 and start Firebase SMS MFA enrollment
    // final user = FirebaseAuth.instance.currentUser;
    // if (user == null) return;
    // final session = await user.multiFactor.getSession();
    // await FirebaseAuth.instance.verifyPhoneNumber(
    //   phoneNumber: normalizedPhone,
    //   multiFactorSession: session,
    //   verificationCompleted: (_) {},
    //   verificationFailed: (e) { /* surface error */ },
    //   codeSent: (vid, _) async {
    //     // collect code from UI, then:
    //     // final cred = PhoneAuthProvider.credential(verificationId: vid, smsCode: code);
    //     // final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
    //     // await user.multiFactor.enroll(assertion, displayName: 'Primary phone');
    //   },
    //   codeAutoRetrievalTimeout: (_) {},
    // );
  }
}

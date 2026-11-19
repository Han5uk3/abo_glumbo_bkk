import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum OtpPurpose {
  login('login'),
  changePhone('change_phone');

  const OtpPurpose(this.wireName);
  final String wireName;
}

/// Calls the backend that sends OTPs through Taqnyat and verifies them.
///
/// Failures surface as [FirebaseAuthException] using the codes the login and
/// OTP screens already translate.
class OtpApi {
  OtpApi._();

  static const String _verificationPrefix = 'otp1:';
  static const String _region = 'europe-west1';
  static const Duration _timeout = Duration(seconds: 25);

  /// Reused when a verify call is retried, so the backend can answer again if
  /// the first response was lost on the network.
  static final Map<String, String> _requestIds = {};

  /// Whether this id came from [requestOtp] rather than Firebase. It pins an
  /// in-progress login to one provider if the remote switch flips meanwhile.
  static bool isTaqnyatVerification(String? verificationId) =>
      verificationId?.startsWith(_verificationPrefix) ?? false;

  /// Sends a code by SMS and returns the id needed to verify it.
  static Future<String> requestOtp({
    required String phone,
    required OtpPurpose purpose,
    required String locale,
    String? expectedUid,
  }) async {
    final data = await _call('requestOtp', {
      'phone': phone,
      'purpose': purpose.wireName,
      'locale': locale,
      'expectedUid': ?expectedUid,
    }, retryStaleSession: purpose == OtpPurpose.login);
    _requestIds.clear();
    return data['verificationId'] as String;
  }

  /// Exchanges a code for a Firebase custom token.
  static Future<String> verifyLogin({
    required String verificationId,
    required String code,
  }) async {
    final data = await _call('verifyOtp', {
      'verificationId': verificationId,
      'code': code,
      'requestId': _requestIdFor(verificationId),
    }, retryStaleSession: true);
    return data['token'] as String;
  }

  /// Moves the signed-in account to the verified number and returns it.
  static Future<String> verifyPhoneChange({
    required String verificationId,
    required String code,
    required String expectedUid,
  }) async {
    final data = await _call('verifyOtp', {
      'verificationId': verificationId,
      'code': code,
      'requestId': _requestIdFor(verificationId),
      'expectedUid': expectedUid,
    }, retryStaleSession: false);
    return data['phone'] as String;
  }

  static String _requestIdFor(String verificationId) {
    return _requestIds.putIfAbsent(verificationId, () {
      final random = Random.secure();
      return List.generate(
        24,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();
    });
  }

  static Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload, {
    required bool retryStaleSession,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _region,
      ).httpsCallable(name, options: HttpsCallableOptions(timeout: _timeout));
      final result = await callable.call<dynamic>(payload);
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      // A leftover session with a revoked token is rejected before the backend
      // runs. Logging in does not need that session, so drop it and try again.
      if (e.code == 'unauthenticated' && retryStaleSession) {
        await FirebaseAuth.instance.signOut();
        return _call(name, payload, retryStaleSession: false);
      }
      debugPrint('❌ [OTP API] $name failed: ${e.code}');
      throw _toAuthException(e);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      debugPrint('❌ [OTP API] $name failed: $e');
      throw FirebaseAuthException(code: 'network-request-failed');
    }
  }

  static FirebaseAuthException _toAuthException(FirebaseFunctionsException e) {
    final details = e.details;
    final backendCode = details is Map ? details['code'] : null;
    if (backendCode is String) {
      return FirebaseAuthException(code: backendCode);
    }
    switch (e.code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
        return FirebaseAuthException(code: 'network-request-failed');
      case 'resource-exhausted':
        return FirebaseAuthException(code: 'too-many-requests');
      default:
        return FirebaseAuthException(code: 'internal-error');
    }
  }
}

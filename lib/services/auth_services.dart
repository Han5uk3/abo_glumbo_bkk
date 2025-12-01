import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:abo_glumbo_bbk/helpers/collections.dart';
import 'package:abo_glumbo_bbk/helpers/hive_helper.dart';
import 'package:abo_glumbo_bbk/pages/SignUp/signup_page.dart';
import 'package:abo_glumbo_bbk/pages/home/main_home.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

class AuthServices {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? phoneNumber;

  String _sanitizePhoneNumber(String input) {
    if (input.startsWith("+966")) {
      String countryCode = "+966";
      String numberPart = input.substring(4);
      String sanitizedNumberPart = _sanitizeNumberPart(numberPart);
      String result = countryCode + sanitizedNumberPart;
      return result;
    }
    String sanitizedNumberPart = _sanitizeNumberPart(input);
    return sanitizedNumberPart;
  }

  String _sanitizeNumberPart(String input) {
    String result = input.replaceAll(RegExp(r'\s'), '');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const asciiDigits = '0123456789';
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], asciiDigits[i]);
    }
    return result;
  }

  String _sanitizeOTP(String input) {
    // Remove spaces and convert Arabic digits to ASCII for OTP
    String result = input.replaceAll(RegExp(r'\s'), '');
    const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
    const asciiDigits = '0123456789';
    for (int i = 0; i < arabicDigits.length; i++) {
      result = result.replaceAll(arabicDigits[i], asciiDigits[i]);
    }
    return result;
  }

  String _formatToE164(String phoneNumber) {
    String sanitized = phoneNumber;
    if (sanitized.startsWith('+966')) {
      return sanitized;
    }
    while (sanitized.startsWith('0')) {
      sanitized = sanitized.substring(1);
    }
    String e164Number = '+966$sanitized';
    return e164Number;
  }

  String? _verificationId;

  Future<void> sendOTP(
    BuildContext context, {
    required String phoneNumber,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    int? forceResendingToken,
  }) async {
    debugPrint('🟢 [CUSTOMER AUTH] sendOTP method called');
    debugPrint('📱 [CUSTOMER AUTH] Phone number: $phoneNumber');

    String sanitizedPhoneNumber = _formatToE164(
      _sanitizePhoneNumber(phoneNumber),
    );
    debugPrint('🔢 [CUSTOMER AUTH] Sanitized number: $sanitizedPhoneNumber');
    debugPrint(
      '📱 [CUSTOMER AUTH] Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );

    AuthServices.phoneNumber = sanitizedPhoneNumber;
    _verificationId = null;

    // Create a Completer to wait for the Firebase callbacks
    final completer = Completer<void>();

    try {
      // iOS specific configuration for reCAPTCHA
      if (Platform.isIOS) {
        debugPrint(
          '🍎 [CUSTOMER AUTH] iOS detected - configuring Firebase Auth settings',
        );
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: false,
          userAccessGroup: null,
        );
        debugPrint('🍎 [CUSTOMER AUTH] iOS Firebase Auth settings configured');
      }

      debugPrint('📞 [CUSTOMER AUTH] Calling Firebase verifyPhoneNumber...');
      await _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 120), // Maximum supported by Firebase
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            '✅ [CUSTOMER AUTH] verificationCompleted callback triggered',
          );
          debugPrint('🔐 [CUSTOMER AUTH] Auto-signing in with credential...');
          // Auto-retrieval or instant verification
          try {
            AuthServices.phoneNumber = sanitizedPhoneNumber;
            await _auth.signInWithCredential(credential);
            debugPrint('✅ [CUSTOMER AUTH] Auto sign-in successful');
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            debugPrint("❌ [CUSTOMER AUTH] Auto verification failed: $e");
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [CUSTOMER AUTH] verificationFailed callback triggered');
          debugPrint('❌ [CUSTOMER AUTH] Error code: ${e.code}');
          debugPrint('❌ [CUSTOMER AUTH] Error message: ${e.message}');

          // Handle reCAPTCHA specific errors more gracefully
          if (e.code == 'recaptcha-sdk-not-linked') {
            debugPrint(
              "⚠️ [CUSTOMER AUTH] reCAPTCHA SDK not linked - continuing without reCAPTCHA validation",
            );
            // For testing purposes, you might want to continue without reCAPTCHA
            // In production, ensure reCAPTCHA Enterprise is properly configured
            return;
          }

          debugPrint('❌ [CUSTOMER AUTH] Calling onError callback');
          onError(e);

          if (!completer.isCompleted) {
            debugPrint('❌ [CUSTOMER AUTH] Completing with error');
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('✅ [CUSTOMER AUTH] codeSent callback triggered');
          debugPrint('🆔 [CUSTOMER AUTH] Verification ID: $verificationId');
          debugPrint('🔑 [CUSTOMER AUTH] ResendToken: $resendToken');

          debugPrint('📞 [CUSTOMER AUTH] Calling onCodeSent callback');
          onCodeSent(verificationId, resendToken: resendToken);
          debugPrint('✅ [CUSTOMER AUTH] onCodeSent callback completed');

          if (!completer.isCompleted) {
            debugPrint('✅ [CUSTOMER AUTH] Completing successfully');
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            '⏰ [CUSTOMER AUTH] codeAutoRetrievalTimeout callback triggered',
          );
          debugPrint(
            '🆔 [CUSTOMER AUTH] Timeout verification ID: $verificationId',
          );
          // Don't complete here - this is just a timeout for auto-retrieval, not the whole process
        },
      );
      debugPrint(
        '✅ [CUSTOMER AUTH] verifyPhoneNumber call completed (setup done, waiting for callbacks)',
      );

      // Wait for the completer to be completed by one of the callbacks
      debugPrint(
        '⏳ [CUSTOMER AUTH] Waiting for Firebase callbacks to complete...',
      );
      await completer.future;
      debugPrint('✅ [CUSTOMER AUTH] Firebase callbacks completed');
    } catch (e) {
      debugPrint('💥 [CUSTOMER AUTH] Exception caught in sendOTP: $e');
      debugPrint('💥 [CUSTOMER AUTH] Exception type: ${e.runtimeType}');

      if (e is FirebaseAuthException) {
        log("Firebase Auth error: ${e.code} - ${e.message}");
        debugPrint("Firebase Auth error: ${e.code} - ${e.message}");

        // Special handling for reCAPTCHA errors
        if (e.code == 'recaptcha-sdk-not-linked') {
          log("reCAPTCHA SDK not linked - this might be a configuration issue");
          debugPrint(
            "reCAPTCHA SDK not linked - this might be a configuration issue",
          );
          // You can choose to continue or show a specific error message
        }

        debugPrint(
          '❌ [CUSTOMER AUTH] Calling onError callback from catch block',
        );
        onError(e);
      } else {
        debugPrint(
          '❌ [CUSTOMER AUTH] Unknown error - wrapping in FirebaseAuthException',
        );
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }
    debugPrint('🏁 [CUSTOMER AUTH] sendOTP method complete');
  }

  Future<void> resendOTP({
    required String phoneNumber,
    required int? resendToken,
    required Function(String verificationId, {int? resendToken}) onCodeSent,
    required Function(FirebaseAuthException e) onError,
    Function(String verificationId)? onAutoRetrievalTimeout,
  }) async {
    debugPrint('🔵 [CUSTOMER AUTH] resendOTP method called');
    debugPrint('📱 [CUSTOMER AUTH] Phone number: $phoneNumber');
    debugPrint('🔑 [CUSTOMER AUTH] Resend token: $resendToken');

    String sanitizedPhoneNumber = _formatToE164(
      _sanitizePhoneNumber(phoneNumber),
    );
    debugPrint(
      '🔢 [CUSTOMER AUTH] Sanitized phone number: $sanitizedPhoneNumber',
    );

    // Create a Completer to wait for the Firebase callbacks
    final completer = Completer<void>();

    try {
      // iOS specific configuration for reCAPTCHA
      if (Platform.isIOS) {
        debugPrint(
          '🍎 [CUSTOMER AUTH] iOS detected - configuring Firebase Auth settings',
        );
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: false,
          userAccessGroup: null,
        );
        debugPrint('🍎 [CUSTOMER AUTH] iOS Firebase Auth settings configured');
      }

      debugPrint('📞 [CUSTOMER AUTH] Calling Firebase verifyPhoneNumber...');
      await _auth.verifyPhoneNumber(
        phoneNumber: sanitizedPhoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 120), // Maximum supported by Firebase
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint(
            '✅ [CUSTOMER AUTH] verificationCompleted callback triggered',
          );
          debugPrint('🔐 [CUSTOMER AUTH] Auto-signing in with credential...');
          try {
            debugPrint("Auto-verification completed during resend OTP");
            await _auth.signInWithCredential(credential);
            debugPrint('✅ [CUSTOMER AUTH] Auto sign-in successful');
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            debugPrint(
              "❌ [CUSTOMER AUTH] Auto verification failed during resend: $e",
            );
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [CUSTOMER AUTH] verificationFailed callback triggered');
          debugPrint('❌ [CUSTOMER AUTH] Error code: ${e.code}');
          debugPrint('❌ [CUSTOMER AUTH] Error message: ${e.message}');

          debugPrint('❌ [CUSTOMER AUTH] Calling onError callback');
          onError(e);

          if (!completer.isCompleted) {
            debugPrint('❌ [CUSTOMER AUTH] Completing with error');
            completer.completeError(e);
          }
        },
        codeSent: (String verificationId, int? token) {
          debugPrint('✅ [CUSTOMER AUTH] codeSent callback triggered');
          debugPrint('🆔 [CUSTOMER AUTH] Verification ID: $verificationId');
          debugPrint('🔑 [CUSTOMER AUTH] New resend token: $token');

          _verificationId = verificationId;
          debugPrint('📞 [CUSTOMER AUTH] Calling onCodeSent callback');
          onCodeSent(verificationId, resendToken: token);
          debugPrint('✅ [CUSTOMER AUTH] onCodeSent callback completed');

          if (!completer.isCompleted) {
            debugPrint('✅ [CUSTOMER AUTH] Completing successfully');
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
            '⏰ [CUSTOMER AUTH] codeAutoRetrievalTimeout callback triggered',
          );
          debugPrint(
            '🆔 [CUSTOMER AUTH] Timeout verification ID: $verificationId',
          );

          _verificationId = verificationId;
          if (onAutoRetrievalTimeout != null) {
            debugPrint(
              '📞 [CUSTOMER AUTH] Calling onAutoRetrievalTimeout callback',
            );
            onAutoRetrievalTimeout(verificationId);
          }
          // Don't complete here - this is just a timeout for auto-retrieval, not the whole process
        },
      );
      debugPrint(
        '✅ [CUSTOMER AUTH] verifyPhoneNumber call completed (setup done, waiting for callbacks)',
      );

      // Wait for the completer to be completed by one of the callbacks
      debugPrint(
        '⏳ [CUSTOMER AUTH] Waiting for Firebase callbacks to complete...',
      );
      await completer.future;
      debugPrint('✅ [CUSTOMER AUTH] Firebase callbacks completed');
    } catch (e) {
      debugPrint('💥 [CUSTOMER AUTH] Exception caught in resendOTP: $e');
      debugPrint('💥 [CUSTOMER AUTH] Exception type: ${e.runtimeType}');

      if (e is FirebaseAuthException) {
        debugPrint(
          '❌ [CUSTOMER AUTH] Calling onError callback from catch block',
        );
        onError(e);
      } else {
        debugPrint(
          '❌ [CUSTOMER AUTH] Unknown error - wrapping in FirebaseAuthException',
        );
        onError(FirebaseAuthException(code: 'unknown', message: e.toString()));
      }

      if (!completer.isCompleted) {
        completer.completeError(e);
      }
      rethrow;
    }
    debugPrint('🏁 [CUSTOMER AUTH] resendOTP method complete');
  }

  Future<UserCredential> verifyOTP(
    BuildContext context,
    String otp, {
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      String sanitizedOTP = _sanitizeOTP(otp);

      // Additional validation for iOS
      if (sanitizedOTP.isEmpty || sanitizedOTP.length != 6) {
        throw FirebaseAuthException(
          code: 'invalid-verification-code',
          message: 'Invalid OTP format. Please enter a 6-digit code.',
        );
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: sanitizedOTP,
      );
      final tempUserCredential = await _auth.signInWithCredential(credential);
      final userPhoneNumber = tempUserCredential.user?.phoneNumber ?? '';

      AuthServices.phoneNumber = userPhoneNumber;

      return tempUserCredential;
    } catch (e) {
      debugPrint("Error verifying OTP: $e");
      if (e is FirebaseAuthException) {
        // Enhanced error handling for iOS-specific issues
        switch (e.code) {
          case 'invalid-verification-code':
            debugPrint("iOS: Invalid verification code provided");
            break;
          case 'session-expired':
            debugPrint("iOS: OTP session expired");
            break;
          case 'too-many-requests':
            debugPrint("iOS: Too many requests - temporarily blocked");
            break;
          case 'network-request-failed':
            debugPrint("iOS: Network request failed");
            break;
          default:
            debugPrint("iOS: Unknown error - ${e.code}: ${e.message}");
        }
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'verification-failed',
          message: 'Failed to verify OTP: $e',
        );
      }
    }
  }

  Future<void> checkUser({
    required UserCredential userCredential,
    required BuildContext context,
  }) async {
    try {
      final uid = userCredential.user?.uid;
      if (uid == null) {
        debugPrint("Error: User UID is null");
        return;
      }
      final userDoc = await AppFirestore.customersCollectionRef.doc(uid).get();
      if (userDoc.exists) {
        LocalStoreHelper.putUID(uid);
        LocalStoreHelper.putGuestUser(false);
        LocalStoreHelper.putlogoutStatus(false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => Home()),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => SignupPage(uid: uid)),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint("Error in checkUser: $e");
      if (e is FirebaseAuthException) {
        rethrow;
      } else {
        throw FirebaseAuthException(
          code: 'check-user-failed',
          message: 'Failed to check user: $e',
        );
      }
    }
  }
}

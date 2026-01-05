import 'dart:async';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:flutter/material.dart';

class SmsAutofillService {
  static final SmsAutofillService _instance = SmsAutofillService._internal();
  StreamSubscription<String>? _smsSubscription;

  factory SmsAutofillService() {
    return _instance;
  }

  SmsAutofillService._internal();

  /// Get the app signature for SMS autofill
  Future<String?> getAppSignature() async {
    try {
      final signature = await SmsAutoFill().getAppSignature;
      debugPrint('📱 [SMS AUTOFILL] App Signature: $signature');
      return signature;
    } catch (e) {
      debugPrint('❌ [SMS AUTOFILL] Failed to get app signature: $e');
      return null;
    }
  }

  /// Listen for incoming SMS and extract OTP
  Future<String?> listenForSms({
    required Duration timeout,
    String? codePattern,
  }) async {
    try {
      debugPrint('👂 [SMS AUTOFILL] Listening for SMS...');

      // Start listening for SMS codes
      await SmsAutoFill().listenForCode();

      // Create a completer to handle the timeout
      final completer = Completer<String?>();

      _smsSubscription?.cancel();
      _smsSubscription = SmsAutoFill().code.listen(
        (code) {
          if (!completer.isCompleted) {
            final otp = _extractOtpFromMessage(code, codePattern);
            if (otp != null) {
              debugPrint('✅ [SMS AUTOFILL] OTP extracted: $otp');
              completer.complete(otp);
            }
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            debugPrint('❌ [SMS AUTOFILL] Error in SMS stream: $error');
            completer.complete(null);
          }
        },
      );

      // Wait for result or timeout
      final result = await completer.future
          .timeout(timeout, onTimeout: () {
            debugPrint('⚠️ [SMS AUTOFILL] SMS listening timeout');
            return null;
          });

      return result;
    } catch (e) {
      debugPrint('❌ [SMS AUTOFILL] Error listening for SMS: $e');
      return null;
    }
  }

  /// Extract OTP from SMS message using pattern matching
  String? _extractOtpFromMessage(String message, String? pattern) {
    try {
      if (pattern != null && pattern.isNotEmpty) {
        final regExp = RegExp(pattern);
        final match = regExp.firstMatch(message);
        if (match != null) {
          return match.group(0);
        }
      }

      // Default pattern: look for 4-6 consecutive digits
      final regExp = RegExp(r'\b\d{4,6}\b');
      final match = regExp.firstMatch(message);
      if (match != null) {
        return match.group(0);
      }

      debugPrint('⚠️ [SMS AUTOFILL] Could not extract OTP from message: $message');
      return null;
    } catch (e) {
      debugPrint('❌ [SMS AUTOFILL] Error extracting OTP: $e');
      return null;
    }
  }

  /// Request user permission for SMS reading
  Future<bool> requestSmsPermission() async {
    try {
      debugPrint('🔐 [SMS AUTOFILL] Requesting SMS permission...');

      // Get app signature to trigger permission requests
      await SmsAutoFill().getAppSignature;

      debugPrint('✅ [SMS AUTOFILL] SMS permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ [SMS AUTOFILL] SMS permission denied: $e');
      return false;
    }
  }

  /// Cancel listening for SMS
  Future<void> cancelListening() async {
    try {
      debugPrint('🛑 [SMS AUTOFILL] Canceling SMS listening...');
      _smsSubscription?.cancel();
      await SmsAutoFill().unregisterListener();
      debugPrint('✅ [SMS AUTOFILL] SMS listening canceled');
    } catch (e) {
      debugPrint('❌ [SMS AUTOFILL] Error canceling SMS listening: $e');
    }
  }

  /// Verify if SMS autofill is available on the device
  Future<bool> isSmsAutofillAvailable() async {
    try {
      // Try to get app signature - if it works, SMS autofill is likely available
      final signature = await getAppSignature();
      return signature != null && signature.isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ [SMS AUTOFILL] SMS autofill not available: $e');
      return false;
    }
  }

  /// Cleanup
  void dispose() {
    _smsSubscription?.cancel();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:smart_auth/smart_auth.dart';
import 'package:flutter/material.dart';

/// Reads the OTP from the incoming SMS with Android's SMS User Consent API:
/// Google shows a prompt asking the user to let the app read that one
/// message. No SMS permission and no app hash in the message are needed.
///
/// iOS has no API to read SMS. There the OTP field's `oneTimeCode` autofill
/// hint makes the keyboard offer the code from Messages, so this is a no-op.
class SmsAutofillService {
  static final SmsAutofillService _instance = SmsAutofillService._internal();
  Completer<String?>? _pending;

  factory SmsAutofillService() {
    return _instance;
  }

  SmsAutofillService._internal();

  /// Waits for the next SMS and returns its 6-digit code, or null if the user
  /// declines, [timeout] passes, or listening is cancelled or restarted.
  /// Android keeps a consent request open for at most 5 minutes.
  Future<String?> listenForSms({required Duration timeout}) async {
    if (!Platform.isAndroid) return null;

    // Only one consent request can be open; a new one replaces the old one
    // natively without completing it, so complete it here instead.
    await cancelListening();
    final completer = Completer<String?>();
    _pending = completer;

    debugPrint('👂 [SMS AUTOFILL] Waiting for SMS (user consent)...');
    SmartAuth.instance.getSmsWithUserConsentApi(matcher: r'\b\d{6}\b').then((
      result,
    ) {
      if (result.isCanceled) {
        debugPrint('🚫 [SMS AUTOFILL] User declined to share the SMS');
      } else if (result.hasError) {
        debugPrint('❌ [SMS AUTOFILL] ${result.error}');
      } else {
        debugPrint('✅ [SMS AUTOFILL] OTP extracted: ${result.data?.code}');
      }
      if (!completer.isCompleted) completer.complete(result.data?.code);
    });

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        debugPrint('⚠️ [SMS AUTOFILL] SMS listening timeout');
        if (identical(_pending, completer)) cancelListening();
        return null;
      },
    );
  }

  /// Stops waiting for the SMS; a pending [listenForSms] returns null.
  Future<void> cancelListening() async {
    if (!Platform.isAndroid) return;
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    await SmartAuth.instance.removeUserConsentApiListener();
  }
}

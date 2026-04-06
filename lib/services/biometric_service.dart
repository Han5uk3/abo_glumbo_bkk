import 'package:abo_glumbo_bbk/helpers/hive_helper.dart' show LocalStoreHelper;
import 'package:abo_glumbo_bbk/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate(BuildContext context) async {
    try {
      return await _auth.authenticate(
        localizedReason:
            AppLocalizations.of(context)?.enableBiometricAuthentication ?? '',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    final uid = LocalStoreHelper.getUID() ?? LocalStoreHelper.getLastValidUID() ?? '';
    await LocalStoreHelper.setBiometricAuthEnabled(enabled, uid);
  }

  static Future<bool> isBiometricEnabled() async {
    final uid = LocalStoreHelper.getUID() ?? LocalStoreHelper.getLastValidUID() ?? '';
    return LocalStoreHelper.getBiometricAuthEnabled(uid);
  }
}

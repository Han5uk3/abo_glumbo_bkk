import 'package:abo_glumbo_bbk/main.dart';
import 'package:flutter/foundation.dart';

class LocalStoreHelper {
  static Future<void> putUID(String uid) {
    return MyApp.box.put('uid', uid);
  }

  static String? getUID() {
    return MyApp.box.get('uid');
  }

  // clear uid
  static Future<void> clearUID() {
    return MyApp.box.delete('uid');
  }

  static Future<void> putGuestUser(bool isGuest) {
    return MyApp.box.put('is_guest', isGuest);
  }

  static bool getGuestUser() {
    return MyApp.box.get('is_guest', defaultValue: false) ?? false;
  }

  static Future<void> clearGuestUser() {
    return MyApp.box.delete('is_guest');
  }

  static Future<void> putlogoutStatus(bool isLoggedOut) async {
    await MyApp.box.put('is_logged_out', isLoggedOut);
  }

  static bool getLogoutStatus() {
    return MyApp.box.get('is_logged_out', defaultValue: false) ?? false;
  }

  static Future<void> clearLogoutStatus() async {
    await MyApp.box.delete('is_logged_out');
  }

  // Remember me feature
  static Future<void> putRememberMe(bool rememberMe) async {
    return MyApp.box.put('remember_me', rememberMe);
  }

  static bool getRememberMe() {
    return MyApp.box.get('remember_me', defaultValue: false) ?? false;
  }

  static Future<void> clearRememberMe() async {
    return MyApp.box.delete('remember_me');
  }

  static Future<void> putPhoneNumber(String phoneNumber) async {
    await MyApp.box.put('phone_number', phoneNumber);
    await MyApp.box.flush();
  }

  static String? getPhoneNumber() {
    return MyApp.box.get('phone_number');
  }

  static Future<void> clearPhoneNumber() async {
    await MyApp.box.delete('phone_number');
  }

  static Future<String> putUserlanguage(String lang) async {
    debugPrint('💾 Saving user language to Hive: $lang');
    await MyApp.box.put('user_language', lang);
    await MyApp.box.flush();
    debugPrint('✅ Language saved and flushed successfully');
    return lang;
  }

  static String getUserlanguage() {
    try {
      final language = MyApp.box.get('user_language', defaultValue: 'en');
      debugPrint('📖 Reading user language from Hive: $language');
      if (language == null) {
        debugPrint('⚠️ Language was null, defaulting to en');
        return 'en';
      }
      if (language != 'en' && language != 'ar') {
        debugPrint('⚠️ Invalid language ($language), defaulting to en');
        return 'en';
      }
      return language;
    } catch (e) {
      debugPrint('❌ Error reading language from Hive: $e, defaulting to en');
      return 'en';
    }
  }

  static Future<void> resetLanguageToEnglish() async {
    await MyApp.box.put('user_language', 'en');
    await MyApp.box.flush();
  }

  static Future<bool> setBiometricAuthEnabled(
    bool isEnabled,
    String uid,
  ) async {
    await MyApp.box.put('biometric_auth_enabled_$uid', isEnabled);
    return true;
  }

  static bool getBiometricAuthEnabled(String uid) {
    return MyApp.box.get('biometric_auth_enabled_$uid', defaultValue: false) ??
        false;
  }

  static Future<void> saveBackgroundTime() async {
    final now = DateTime.now();
    await MyApp.box.put('backgroundTime', now.toIso8601String());
  }

  static DateTime? getBackgroundTime() {
    final timeString = MyApp.box.get('backgroundTime');
    if (timeString != null) {
      return DateTime.tryParse(timeString);
    }
    return null;
  }
}

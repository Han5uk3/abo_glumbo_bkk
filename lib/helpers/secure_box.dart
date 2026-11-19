import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// The app's local key-value store (session, cached profile, preferences),
/// encrypted at rest with AES-256.
///
/// The key lives in the platform keystore (Android Keystore, iOS Keychain
/// for this device only), never next to the data, so the box file is useless
/// when copied off the device. Installs that still have the old plaintext box
/// get its contents copied in once, after which the plaintext file is deleted.
class SecureBox {
  SecureBox._();

  static const String boxName = 'secure_store';
  static const String _legacyBoxName = 'myBox';
  static const String _keyName = 'hive_secure_store_key';

  static const FlutterSecureStorage _keyStore = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    // Readable by background work after the first unlock since boot, never
    // synced to iCloud, never restored onto another device.
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Opens the box; after this, `Hive.box(SecureBox.boxName)` returns it.
  static Future<Box> open() async {
    Box box;
    try {
      final cipher = HiveAesCipher(await _loadOrCreateKey());
      try {
        box = await Hive.openBox(boxName, encryptionCipher: cipher);
      } catch (_) {
        // Unreadable with this key: a corrupt file, or a box whose key is
        // gone. Starting empty costs the user a re-login, not the app.
        await Hive.deleteBoxFromDisk(boxName);
        box = await Hive.openBox(boxName, encryptionCipher: cipher);
      }
    } catch (_) {
      // The keystore itself failed. Keep the app usable without ever writing
      // session data to disk unencrypted: this launch runs on a memory-only
      // box and the user signs in again next time.
      box = await Hive.openBox(boxName, bytes: Uint8List(0));
      return box;
    }
    await _migrateLegacyBox(box);
    return box;
  }

  static Future<List<int>> _loadOrCreateKey() async {
    final stored = await _keyStore.read(key: _keyName);
    if (stored != null) {
      try {
        final key = base64Url.decode(stored);
        if (key.length == 32) return key;
      } catch (_) {
        // Malformed; replaced below.
      }
    }
    final key = Hive.generateSecureKey();
    await _keyStore.write(key: _keyName, value: base64UrlEncode(key));
    return key;
  }

  static Future<void> _migrateLegacyBox(Box target) async {
    try {
      if (!await Hive.boxExists(_legacyBoxName)) return;
      final legacy = await Hive.openBox(_legacyBoxName);
      if (target.isEmpty && legacy.isNotEmpty) {
        await target.putAll(Map<dynamic, dynamic>.from(legacy.toMap()));
        await target.flush();
      }
      await legacy.close();
    } catch (_) {
      // Unreadable legacy data is dropped rather than kept in plaintext.
    }
    try {
      await Hive.deleteBoxFromDisk(_legacyBoxName);
    } catch (_) {
      // Retried on the next launch.
    }
  }
}

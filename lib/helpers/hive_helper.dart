import 'package:abo_glumbo_bbk/main.dart';

class LocalStoreHelper {
  static Future<void> putUID(String uid) {
    return MyApp.box.put('uid', uid);
  }

  static String? getUID() {
    return MyApp.box.get('uid');
  }

  static Future<String> putUserlanguage(String lang) async {
    await MyApp.box.put('user_language', lang);
    await MyApp.box.flush();
    return lang;
  }

  static String getUserlanguage() {
    return MyApp.box.get('user_language', defaultValue: 'en');
  }
}

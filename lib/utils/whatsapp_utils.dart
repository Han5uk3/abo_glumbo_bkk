import 'package:url_launcher/url_launcher_string.dart';

class WhatsAppUtils {
  static Future<void> launchWhatsApp(String phone) async {
    // Remove all non-numeric characters from the phone number
    // wa.me expects the number with country code, no + or spaces
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final url = "https://wa.me/$cleanPhone";
    try {
      final success = await launchUrlString(url, mode: LaunchMode.externalApplication);
      if (!success) {
        await launchUrlString(url);
      }
    } catch (e) {
      try {
        await launchUrlString(url);
      } catch (err) {
        // Fail silently or log
      }
    }
  }
}

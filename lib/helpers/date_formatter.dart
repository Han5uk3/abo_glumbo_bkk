import 'package:intl/intl.dart';

/// Formats a DateTime to "dd-MM-yyyy hh:mm AM/PM" format
/// Supports both Arabic and English locales
///
/// Example outputs:
/// - English: "22-11-2025 11:30 PM"
/// - Arabic: "٢٢-١١-٢٠٢٥ ١١:٣٠ م"
String formatBookingDateTime(DateTime dateTime, String locale) {
  // Format: day-month-year
  final dateFormat = DateFormat('dd-MM-yyyy', locale);

  // Format: hour:minute AM/PM (12-hour format)
  final timeFormat = DateFormat('hh:mm a', locale);

  return '${dateFormat.format(dateTime)} ${timeFormat.format(dateTime)}';
}

import 'package:intl/intl.dart';
import 'package:abo_glumbo_bbk/services/time_service.dart';

/// Every formatter in this file renders in **Saudi time**, not device time.
///
/// Firestore timestamps are absolute instants, and `Timestamp.toDate()` returns
/// them in the device's zone. Abo Glumbo runs entirely in Saudi Arabia, so a
/// booking made at 10:00 in Riyadh has to read "10:00" to everyone who looks at
/// it — the technician, the admin, and the customer — regardless of where their
/// phone thinks it is. Rendering device-local meant a booking looked like it was
/// at 07:30 to an admin in India and 07:00 to one in the UK.
///
/// Callers pass the instant straight from `Timestamp.toDate()`; the conversion
/// to the Saudi wall clock happens here so no call site has to remember it.
/// See [KsaTime].

/// Formats a DateTime to "dd-MM-yyyy hh:mm AM/PM" format in KSA time.
/// Supports both Arabic and English locales
///
/// Example outputs:
/// - English: "22-11-2025 11:30 PM"
/// - Arabic: "٢٢-١١-٢٠٢٥ ١١:٣٠ م"
String formatBookingDateTime(DateTime dateTime, String locale) {
  final ksa = KsaTime.fromInstant(dateTime);

  // Format: day-month-year
  final dateFormat = DateFormat('dd-MM-yyyy', locale);

  // Format: hour:minute AM/PM (12-hour format)
  final timeFormat = DateFormat('hh:mm a', locale);

  return '${dateFormat.format(ksa)} ${timeFormat.format(ksa)}';
}

String formatDateTimeDay(DateTime date, String locale) {
  return DateFormat(
    'EEE, MMM d, y - h:mm a',
    locale,
  ).format(KsaTime.fromInstant(date));
}

String formatDateTime(DateTime date, String locale) {
  return DateFormat(
    'dd MMM yyyy, hh:mm a',
    locale,
  ).format(KsaTime.fromInstant(date));
}

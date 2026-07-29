import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';

class TimeService {
  static Duration _offset = Duration.zero;

  /// Initializes the time service by fetching the true network time.
  static Future<void> init() async {
    try {
      final myTime = DateTime.now();
      final ntpTime = await NTP.now();
      _offset = ntpTime.difference(myTime);
      debugPrint('TimeService initialized. Clock skew offset: ${_offset.inMilliseconds}ms');
    } catch (e) {
      debugPrint('TimeService failed to initialize, falling back to local clock: $e');
      _offset = Duration.zero;
    }
  }

  /// Returns the current synchronized time.
  static DateTime get now => DateTime.now().add(_offset);
}

/// Single source of truth for the business timezone.
///
/// Abo Glumbo operates only in Saudi Arabia, which is permanently UTC+3 and has
/// never observed daylight saving time, so a fixed offset is exact — no timezone
/// database and no per-date lookup is needed.
///
/// Two kinds of `DateTime` flow through the booking code and it matters which is
/// which:
///
///  * **KSA wall clock** — what the customer and technician actually see and pick:
///    "Thursday the 14th at 10:00". Produced by [now], by the date picker and by
///    the time-slot grid. These are naive values; their `hour`/`weekday` fields are
///    KSA fields and they must only ever be compared against other wall-clock
///    values (which is why [now] deliberately returns a local-flagged `DateTime`
///    rather than a UTC-flagged one — it composes correctly with `DateTime(y, m, d,
///    slot.hour, slot.minute)` built from picker output).
///
///  * **Instant** — the absolute point in time written to Firestore. Convert with
///    [toInstant] on the way in and [fromInstant] on the way out.
///
/// On a device already set to Riyadh time every helper here is a no-op, so
/// behaviour for the overwhelming majority of users is unchanged; the helpers only
/// bite when a device clock is set to another zone, which is exactly the case that
/// used to silently shift bookings and on/off-hour pricing.
class KsaTime {
  const KsaTime._();

  /// Saudi Arabia standard time. Fixed year-round; KSA does not observe DST.
  static const Duration offsetFromUtc = Duration(hours: 3);

  /// The current KSA wall-clock time, based on the NTP-corrected clock.
  ///
  /// Returned as a local-flagged `DateTime` carrying KSA field values so it can be
  /// compared and combined with wall-clock values built from user pickers.
  static DateTime get now => fromInstant(TimeService.now);

  /// Today's date in KSA, with the time component zeroed.
  static DateTime get today {
    final n = now;
    return DateTime(n.year, n.month, n.day);
  }

  /// Converts a KSA wall-clock value into the absolute instant it refers to.
  /// Use this for every value that is about to be written to Firestore.
  static DateTime toInstant(DateTime ksaWallClock) => DateTime.utc(
    ksaWallClock.year,
    ksaWallClock.month,
    ksaWallClock.day,
    ksaWallClock.hour,
    ksaWallClock.minute,
    ksaWallClock.second,
    ksaWallClock.millisecond,
  ).subtract(offsetFromUtc);

  /// Converts an absolute instant (e.g. `Timestamp.toDate()`) into the KSA wall
  /// clock, for display and for comparison against other wall-clock values.
  static DateTime fromInstant(DateTime instant) {
    final ksa = instant.toUtc().add(offsetFromUtc);
    return DateTime(
      ksa.year,
      ksa.month,
      ksa.day,
      ksa.hour,
      ksa.minute,
      ksa.second,
      ksa.millisecond,
    );
  }
}

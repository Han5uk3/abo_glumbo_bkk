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

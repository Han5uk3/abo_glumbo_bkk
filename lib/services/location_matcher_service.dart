import 'dart:math';

/// Service location zone info captured when the customer address is validated.
/// This is stored in the booking document so the technician/admin can see
/// which named service area the booking was placed for.
class MatchedServiceZone {
  /// English name of the zone (e.g. "Riyadh North")
  final String nameEn;

  /// Arabic name of the zone (e.g. "شمال الرياض")
  final String nameAr;

  /// Urdu name of the zone
  final String nameUr;

  /// Priority of the zone (lower = higher priority)
  final int priority;

  const MatchedServiceZone({
    required this.nameEn,
    required this.nameAr,
    required this.nameUr,
    required this.priority,
  });

  factory MatchedServiceZone.fromJson(Map<String, dynamic> json) {
    return MatchedServiceZone(
      nameEn: json['nameEn'] as String? ?? json['en_name'] as String? ?? '',
      nameAr: json['nameAr'] as String? ?? json['ar_name'] as String? ?? '',
      nameUr: json['nameUr'] as String? ?? json['ur_name'] as String? ?? json['nameAr'] as String? ?? json['nameEn'] as String? ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'nameEn': nameEn,
    'nameAr': nameAr,
    'nameUr': nameUr,
    'priority': priority,
  };

  String get displayName => nameEn;

  String localizedName(String? locale) =>
      locale == 'ar' ? nameAr : locale == 'ur' ? nameUr : nameEn;
}

/// Service for matching customer addresses with technician service areas.
///
/// Uses polygon-based point-in-polygon (PIP) testing which matches the
/// admin app's polygon drawing tool (map_picker_page.dart).
class LocationMatcherService {
  /// Check whether a point [lat, lon] lies inside a polygon defined as a list
  /// of {lat, lng} maps. Uses the ray-casting algorithm.
  static bool isPointInPolygon({
    required double lat,
    required double lon,
    required List<Map<String, dynamic>> polygon,
  }) {
    if (polygon.length < 3) return false;

    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = (polygon[i]['lat'] as num).toDouble();
      final double yi = (polygon[i]['lng'] as num).toDouble();
      final double xj = (polygon[j]['lat'] as num).toDouble();
      final double yj = (polygon[j]['lng'] as num).toDouble();

      final bool intersect =
          ((yi > lon) != (yj > lon)) &&
          (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }

    return inside;
  }

  /// Check if a customer address [lat, lon] falls inside any of the polygon
  /// service-area zones stored in the Firestore `locations` collection document
  /// for a service.
  ///
  /// [serviceLocations] is the `locations` array from Firestore, where each
  /// element looks like:
  /// ```json
  /// {
  ///   "polygon": [{"lat": 24.0, "lng": 46.0}, ...],
  ///   "en_name": "Riyadh",
  ///   "ar_name": "الرياض",
  ///   "priority": 1
  /// }
  /// ```
  static bool isAddressInServiceZones({
    required double customerLat,
    required double customerLon,
    required List<dynamic> serviceLocations,
  }) {
    return getMatchedServiceZone(
          customerLat: customerLat,
          customerLon: customerLon,
          serviceLocations: serviceLocations,
        ) !=
        null;
  }

  /// Find the highest-priority (lowest `priority` value) zone that contains
  /// the given [customerLat] / [customerLon] point across all [serviceLocations].
  ///
  /// Returns `null` if the point doesn't fall inside any zone.
  ///
  /// The matched zone includes `en_name`, `ar_name`, and `priority` which are
  /// stored on the booking document as `serviceLocation`.
  static MatchedServiceZone? getMatchedServiceZone({
    required double customerLat,
    required double customerLon,
    required List<dynamic> serviceLocations,
  }) {
    MatchedServiceZone? best;

    for (final zone in serviceLocations) {
      final polygonData = zone['polygon'] as List<dynamic>?;
      if (polygonData == null || polygonData.isEmpty) continue;

      final polygon = polygonData
          .map((p) => p as Map<String, dynamic>)
          .toList();

      if (isPointInPolygon(
        lat: customerLat,
        lon: customerLon,
        polygon: polygon,
      )) {
        final priority = (zone['priority'] as num?)?.toInt() ?? 999;
        final candidate = MatchedServiceZone(
          nameEn: zone['en_name'] as String? ?? '',
          nameAr: zone['ar_name'] as String? ?? '',
          nameUr: zone['ur_name'] as String? ?? zone['ar_name'] as String? ?? zone['en_name'] as String? ?? '',
          priority: priority,
        );

        // Keep the zone with the lowest priority number (= highest priority)
        if (best == null || candidate.priority < best.priority) {
          best = candidate;
        }
      }
    }

    return best;
  }

  /// Calculate distance between two coordinates using Haversine formula.
  /// Returns distance in **meters**.
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // metres

    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  static double _deg2rad(double degrees) => degrees * pi / 180;
}

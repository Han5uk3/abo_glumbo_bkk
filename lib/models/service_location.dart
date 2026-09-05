import 'package:google_maps_flutter/google_maps_flutter.dart';

class ServiceLocationModel {
  final String id;
  final String name;
  final String nameAr;
  final String nameUr;
  final List<LatLng> polygon;
  final int priority;

  ServiceLocationModel({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.nameUr,
    this.polygon = const [],
    this.priority = 0,
  });

  factory ServiceLocationModel.fromJson(Map<String, dynamic> json) {
    return ServiceLocationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      nameUr: json['name_ur'] as String? ?? json['name_ar'] as String? ?? '',
      polygon: (json['polygon'] as List<dynamic>?)
              ?.map((point) {
                final lat = (point['lat'] as num?)?.toDouble() ?? 0.0;
                final lng = (point['lng'] as num?)?.toDouble() ?? 0.0;
                return LatLng(lat, lng);
              })
              .toList() ??
          [],
      priority: json['priority'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_ar': nameAr,
      'name_ur': nameUr,
      'polygon': polygon
          .map((point) => {
                'lat': point.latitude,
                'lng': point.longitude,
              })
          .toList(),
      'priority': priority,
    };
  }
}

import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:abo_glumbo_bbk/models/hierarchical_location.dart';

/// Service for matching customer addresses with technician service areas
/// Uses a radius-based approach with geocoding (primary) and JSON coordinates (fallback)
class LocationMatcherService {
  // Service radius in meters (2.5 km based on Saudi district sizes)
  static const double SERVICE_RADIUS_METERS = 2500.0;

  // Cache for hierarchical location data
  static List<HierarchicalLocationModel>? _hierarchicalData;

  /// Load hierarchical location data from JSON
  static Future<void> _loadHierarchicalData() async {
    if (_hierarchicalData != null) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/saudi_hierarchical.json',
      );
      final jsonData = jsonDecode(jsonString) as List;
      _hierarchicalData = jsonData
          .map((item) => HierarchicalLocationModel.fromJson(item))
          .toList();
    } catch (e) {
      print('Error loading hierarchical data: $e');
      _hierarchicalData = [];
    }
  }

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371000; // Earth's radius in meters

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Get coordinates for a district using geocoding (primary) or JSON (fallback)
  static Future<Map<String, double>?> getDistrictCoordinates({
    required String districtEn,
    required String cityEn,
    required String regionEn,
  }) async {
    // Try geocoding first
    try {
      final query = '$districtEn, $cityEn, $regionEn, Saudi Arabia';
      final locations = await locationFromAddress(query);

      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }
    } catch (e) {
      print('Geocoding failed for $districtEn: $e');
    }

    // Fallback to JSON coordinates
    await _loadHierarchicalData();

    if (_hierarchicalData == null) return null;

    for (final region in _hierarchicalData!) {
      if (region.region_en == regionEn) {
        for (final city in region.cities) {
          if (city.city_en == cityEn) {
            for (final district in city.districts) {
              if (district.district_en == districtEn) {
                return {
                  'latitude': district.latitude,
                  'longitude': district.longitude,
                };
              }
            }
          }
        }
      }
    }

    return null;
  }

  /// Check if a customer address is within service area of a technician
  ///
  /// [customerLat] Customer address latitude
  /// [customerLon] Customer address longitude
  /// [technicianServiceAreas] List of SelectedCity objects representing technician's service areas
  ///
  /// Returns true if the address is within service radius of any district in service areas
  static Future<bool> isAddressInServiceArea({
    required double customerLat,
    required double customerLon,
    required List<SelectedCity> technicianServiceAreas,
  }) async {
    if (technicianServiceAreas.isEmpty) return false;

    await _loadHierarchicalData();
    if (_hierarchicalData == null) return false;

    // Check each service area
    for (final serviceArea in technicianServiceAreas) {
      // Find the region and city in hierarchical data
      for (final region in _hierarchicalData!) {
        if (region.region_id == serviceArea.regionId) {
          for (final city in region.cities) {
            if (city.city_id == serviceArea.cityId) {
              // Check all districts in this city
              for (final district in city.districts) {
                // Get district coordinates (geocoding + fallback)
                final coords = await getDistrictCoordinates(
                  districtEn: district.district_en,
                  cityEn: city.city_en,
                  regionEn: region.region_en,
                );

                if (coords != null) {
                  final distance = calculateDistance(
                    customerLat,
                    customerLon,
                    coords['latitude']!,
                    coords['longitude']!,
                  );

                  // If within service radius, address is serviceable
                  if (distance <= SERVICE_RADIUS_METERS) {
                    return true;
                  }
                }
              }
            }
          }
        }
      }
    }

    return false;
  }

  /// Get all technicians who can service a specific address
  ///
  /// [customerLat] Customer address latitude
  /// [customerLon] Customer address longitude
  /// [allTechnicians] List of all technician user models
  ///
  /// Returns list of technician UIDs who can service this address
  static Future<List<String>> getTechniciansForAddress({
    required double customerLat,
    required double customerLon,
    required List<dynamic> allTechnicians, // UserModel list
  }) async {
    final List<String> serviceableTechnicianIds = [];

    for (final technician in allTechnicians) {
      // Assuming technician has serviceAreas field
      final serviceAreas = technician.serviceAreas as List<SelectedCity>?;

      if (serviceAreas != null && serviceAreas.isNotEmpty) {
        final canService = await isAddressInServiceArea(
          customerLat: customerLat,
          customerLon: customerLon,
          technicianServiceAreas: serviceAreas,
        );

        if (canService && technician.uid != null) {
          serviceableTechnicianIds.add(technician.uid!);
        }
      }
    }

    return serviceableTechnicianIds;
  }

  /// Get readable location name from coordinates using reverse geocoding
  static Future<String?> getLocationNameFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = <String>[];

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          parts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }

        return parts.join(', ');
      }
    } catch (e) {
      print('Reverse geocoding failed: $e');
    }

    return null;
  }
}

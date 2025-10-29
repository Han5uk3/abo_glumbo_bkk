import 'package:abo_glumbo_bbk/services/app_services.dart';
import 'package:abo_glumbo_bbk/services/fetch_location_geolocator.dart';
import 'package:flutter/material.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  String? userLocation;
  String? userLocality;
  bool isLocationActive = false;
  double? longitude;
  double? latitude;

  Future<void> fetchLocation() async {
    try {
      FetchLocationGeolocator geolocator = FetchLocationGeolocator();
      userLocation = await geolocator.refetchLocation();
      userLocality = await geolocator.fetchLocality();
      isLocationActive = userLocation != null && userLocation!.isNotEmpty;

      if (isLocationActive) {
        longitude = await geolocator.fetchLongitude();
        latitude = await geolocator.fetchLatitude();

        // Only update if we have valid coordinates
        if (longitude != null && latitude != null) {
          AppServices.updateCustomerLonAndLat(longitude!, latitude!);
        }
      }
    } catch (e) {
      // Handle location fetch errors gracefully
      isLocationActive = false;
      userLocation = null;
      userLocality = null;
      longitude = null;
      latitude = null;
      debugPrint('❌ LocationService error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUserCoordinates() async {
    await fetchLocation();
    if (longitude != null && latitude != null) {
      return {
        "lon": longitude!,
        "lat": latitude!,
        "userLocation": userLocation ?? "",
      };
    } else {
      throw Exception('User coordinates are not available');
    }
  }
}

import 'dart:convert';

import 'package:abo_glumbo_bbk/configs/env_config.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<List<LatLng>> getPolylinePointsFromGoogle(
  LatLng start,
  LatLng end,
) async {
  final apiKey = EnvConfig.googleMapsApiKey;
  final response = await http.get(
    Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&departure_time=now&mode=driving&key=$apiKey',
    ),
  );

  final json = jsonDecode(response.body);
  if (json['routes'] == null || json['routes'].isEmpty) {
    return [];
  }

  final List<LatLng> highResPoints = [];
  final steps = json['routes'][0]['legs'][0]['steps'] as List;

  for (var step in steps) {
    final encodedPoints = step['polyline']['points'];
    final decodedPoints = PolylinePoints.decodePolyline(encodedPoints);
    highResPoints.addAll(
      decodedPoints.map((p) => LatLng(p.latitude, p.longitude)),
    );
  }

  return highResPoints;
}

Future<Map<String, dynamic>> getEtaAndDistance({
  required double originLat,
  required double originLng,
  required double destinationLat,
  required double destinationLng,
  required String apiKey,
}) async {
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json'
    '?origin=$originLat,$originLng'
    '&destination=$destinationLat,$destinationLng'
    '&departure_time=now'
    '&mode=driving'
    '&traffic_model=best_guess'
    '&key=$apiKey',
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['routes'].isNotEmpty) {
      final leg = data['routes'][0]['legs'][0];

      // Stitch all steps together for maximum accuracy polyline
      final List<Map<String, double>> highResSteps = [];
      final steps = leg['steps'] as List;

      // We pass the steps' polylines or just return the stitched data
      // For simplicity in this app, we can either return a list of LatLng
      // or the first overview if 100% accuracy isn't visual enough.
      // But user wants 100% accuracy, so let's provide the points or all polylines.

      return {
        'distance': leg['distance']['text'],
        'duration': leg['duration_in_traffic'] != null
            ? leg['duration_in_traffic']['text']
            : leg['duration']['text'],
        'steps': steps, // Passing steps to decode later or handle here
        'overview_polyline': data['routes'][0]['overview_polyline']['points'],
      };
    } else {
      throw Exception("No route found.");
    }
  } else {
    throw Exception("Failed to fetch directions.");
  }
}

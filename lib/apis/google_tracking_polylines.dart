import 'dart:convert';
import 'dart:developer';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<List<LatLng>> getPolylinePointsFromGoogle(
  LatLng start,
  LatLng end,
) async {
  final response = await http.get(
    Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=AIzaSyBl4RQBYM_v-u2Oik_ENyxcGxnvyZGxL2o',
    ),
  );
  log(response.body);
  final json = jsonDecode(response.body);

  if (json['routes'] == null || json['routes'].isEmpty) {
    return []; // return empty list to avoid crash
  }

  final encodedPolyline = json['routes'][0]['overview_polyline']['points'];
  final points = PolylinePoints.decodePolyline(encodedPolyline);

  return points.map((e) => LatLng(e.latitude, e.longitude)).toList();
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
    '&mode=driving'
    '&key=$apiKey',
  );

  final response = await http.get(url);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    if (data['routes'].isNotEmpty) {
      final leg = data['routes'][0]['legs'][0];
      return {
        'distance': leg['distance']['text'],
        'duration': leg['duration']['text'],
        'polyline': data['routes'][0]['overview_polyline']['points'],
      };
    } else {
      throw Exception("No route found.");
    }
  } else {
    throw Exception("Failed to fetch directions.");
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<List<String>> getPlaceSuggestions(String input) async {
  const apiKey = 'AIzaSyBQglwauOyBM2wKjobljQUdlkD4ECnSPp4';
  final url =
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&components=country:sa';
  final response = await http.get(Uri.parse(url));
  final data = jsonDecode(response.body);
  if (data['status'] == 'OK') {
    return List<String>.from(
        data['predictions'].map((place) => place['description']));
  } else {
    return [];
  }
}

// ignore_for_file: non_constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  String? name;
  String? name_ar;
  String? id;
  double? lat;
  double? lon;

  LocationModel({this.name, this.name_ar, this.id, this.lat, this.lon});

  LocationModel.fromQuerySnapshot(QueryDocumentSnapshot snapshot) {
    Map data = snapshot.data() as Map<String, dynamic>;
    name = data['name'];
    name_ar = data['name_ar'] ?? data['name'];
    id = snapshot.id;
    lat = data['lat'];
    lon = data['lon'];
  }

  LocationModel.fromJson(Map<String, dynamic> json) {
    name = json['name'];
    name_ar = json['name_ar'] ?? json['name'];
    id = json['id'];
    lat = json['lat'];
    lon = json['lon'];
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = {
      'name': name,
      'name_ar': name_ar,
      'id': id,
      'lat': lat,
      'lon': lon
    };

    return data;
  }

  LocationModel copyWith(
      {String? name, String? name_ar, String? id, double? lat, double? lon}) {
    return LocationModel(
      name: name ?? this.name,
      name_ar: name_ar ?? this.name_ar,
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}

import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';

class AddressModel {
  final String id;
  final String buildingNumber;
  final String fullName;
  final String phoneNumber;
  final String? streetName;
  final double? lon;
  final double? lat;
  bool? isSelected;
  final bool? isCurrentLocation; // Flag for auto-updated current location

  AddressModel({
    required this.id,
    required this.fullName,
    required this.buildingNumber,
    this.streetName,
    required this.phoneNumber,
    this.lon,
    this.lat,
    this.isSelected = false,
    this.isCurrentLocation = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      buildingNumber: json['buildingNumber']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      streetName: json['streetName'] as String?,
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      isSelected: json['isSelected'] as bool? ?? false,
      isCurrentLocation: json['isCurrentLocation'] as bool? ?? false,
    );
  }
  AddressModel copyWith({
    String? id,
    String? fullName,
    String? buildingNumber,
    String? phoneNumber,
    String? streetName,
    double? lon,
    double? lat,
    bool? isSelected,
    bool? isCurrentLocation,
  }) {
    return AddressModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      streetName: streetName ?? this.streetName,
      lon: lon ?? this.lon,
      lat: lat ?? this.lat,
      isSelected: isSelected ?? this.isSelected,
      isCurrentLocation: isCurrentLocation ?? this.isCurrentLocation,
    );
  }

  Map<String, dynamic> toJson() {
    // Format phone number with country code when storing to Firebase
    final formattedPhoneNumber = CountryCodeDetector.convertToFirebaseFormat(
      phoneNumber,
    );

    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': formattedPhoneNumber,
      'buildingNumber': buildingNumber,
      'streetName': streetName,
      'lon': lon,
      'lat': lat,
      'isSelected': isSelected,
      'isCurrentLocation': isCurrentLocation,
    };
  }
}

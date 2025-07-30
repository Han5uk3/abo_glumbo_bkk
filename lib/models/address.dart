class AddressModel {
  final String id;
  final String buildingNumber;
  final String fullName;
  final String phoneNumber;
  final String? streetName;
  final double? lon;
  final double? lat;
  bool? isSelected;

  AddressModel({
    required this.id,
    required this.fullName,
    required this.buildingNumber,
    this.streetName,
    required this.phoneNumber,
    this.lon,
    this.lat,
    this.isSelected = false,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      buildingNumber: json['buildingNumber'] as String,
      phoneNumber: json['phoneNumber'] as String,
      streetName: json['streetName'] as String?,
      lon: (json['lon'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      isSelected: json['isSelected'] as bool? ?? false,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'buildingNumber': buildingNumber,
      'streetName': streetName,
      'lon': lon,
      'lat': lat,
      'isSelected': isSelected,
    };
  }
}

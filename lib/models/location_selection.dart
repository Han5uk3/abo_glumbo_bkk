// lib/models/location_selection.dart
class Region {
  final String regionId;
  final String regionEn;
  final String regionAr;
  final List<City> cities;

  Region({
    required this.regionId,
    required this.regionEn,
    required this.regionAr,
    required this.cities,
  });

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      regionId: json['region_id'],
      regionEn: json['region_en'],
      regionAr: json['region_ar'],
      cities: (json['cities'] as List).map((c) => City.fromJson(c)).toList(),
    );
  }

  String getName(bool isArabic) => isArabic ? regionAr : regionEn;
}

class City {
  final String cityId;
  final String cityEn;
  final String cityAr;
  final List<District> districts;

  City({
    required this.cityId,
    required this.cityEn,
    required this.cityAr,
    required this.districts,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      cityId: json['city_id'],
      cityEn: json['city_en'],
      cityAr: json['city_ar'],
      districts: (json['districts'] as List)
          .map((d) => District.fromJson(d))
          .toList(),
    );
  }

  String getName(bool isArabic) => isArabic ? cityAr : cityEn;
}

class District {
  final String districtId;
  final String districtEn;
  final String districtAr;
  final double latitude;
  final double longitude;

  District({
    required this.districtId,
    required this.districtEn,
    required this.districtAr,
    required this.latitude,
    required this.longitude,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      districtId: json['district_id'],
      districtEn: json['district_en'],
      districtAr: json['district_ar'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  String getName(bool isArabic) => isArabic ? districtAr : districtEn;
}

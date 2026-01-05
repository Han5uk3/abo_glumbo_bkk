// ignore_for_file: non_constant_identifier_names

class HierarchicalLocationModel {
  final String region_id;
  final String region_ar;
  final String region_en;
  final List<City> cities;

  HierarchicalLocationModel({
    required this.region_id,
    required this.region_ar,
    required this.region_en,
    required this.cities,
  });

  factory HierarchicalLocationModel.fromJson(Map<String, dynamic> json) {
    return HierarchicalLocationModel(
      region_id: json['region_id'],
      region_ar: json['region_ar'],
      region_en: json['region_en'],
      cities: (json['cities'] as List)
          .map((city) => City.fromJson(city))
          .toList(),
    );
  }
}

class City {
  final String city_id;
  final String city_ar;
  final String city_en;
  final List<District> districts;

  City({
    required this.city_id,
    required this.city_ar,
    required this.city_en,
    required this.districts,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      city_id: json['city_id'],
      city_ar: json['city_ar'],
      city_en: json['city_en'],
      districts: (json['districts'] as List? ?? [])
          .map((district) => District.fromJson(district))
          .toList(),
    );
  }
}

class District {
  final String district_id;
  final String district_ar;
  final String district_en;

  District({
    required this.district_id,
    required this.district_ar,
    required this.district_en,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      district_id: json['district_id'],
      district_ar: json['district_ar'],
      district_en: json['district_en'],
    );
  }
}

/// Represents a selected district with its province and city information
class SelectedDistrict {
  final String regionId;
  final String regionEn;
  final String regionAr;
  final String cityId;
  final String cityEn;
  final String cityAr;
  final String districtId;
  final String districtEn;
  final String districtAr;

  SelectedDistrict({
    required this.regionId,
    required this.regionEn,
    required this.regionAr,
    required this.cityId,
    required this.cityEn,
    required this.cityAr,
    required this.districtId,
    required this.districtEn,
    required this.districtAr,
  });

  factory SelectedDistrict.fromJson(Map<String, dynamic> json) {
    return SelectedDistrict(
      regionId: json['regionId'],
      regionEn: json['regionEn'],
      regionAr: json['regionAr'],
      cityId: json['cityId'],
      cityEn: json['cityEn'],
      cityAr: json['cityAr'],
      districtId: json['districtId'],
      districtEn: json['districtEn'],
      districtAr: json['districtAr'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regionId': regionId,
      'regionEn': regionEn,
      'regionAr': regionAr,
      'cityId': cityId,
      'cityEn': cityEn,
      'cityAr': cityAr,
      'districtId': districtId,
      'districtEn': districtEn,
      'districtAr': districtAr,
    };
  }

  @override
  String toString() => '$regionEn > $cityEn > $districtEn';

  String displayNameAr() => '$regionAr > $cityAr > $districtAr';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedDistrict &&
          runtimeType == other.runtimeType &&
          districtId == other.districtId &&
          regionId == other.regionId;

  @override
  int get hashCode => districtId.hashCode ^ regionId.hashCode;
}

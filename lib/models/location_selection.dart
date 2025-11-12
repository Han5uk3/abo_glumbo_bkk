// lib/models/location_selection.dart
class Province {
  final String provinceId;
  final String provinceEn;
  final String provinceAr;
  final List<Governorate> governorates;

  Province({
    required this.provinceId,
    required this.provinceEn,
    required this.provinceAr,
    required this.governorates,
  });

  factory Province.fromJson(Map<String, dynamic> json) {
    return Province(
      provinceId: json['province_id'],
      provinceEn: json['province_en'],
      provinceAr: json['province_ar'],
      governorates: (json['governorates'] as List)
          .map((g) => Governorate.fromJson(g))
          .toList(),
    );
  }

  String getName(bool isArabic) => isArabic ? provinceAr : provinceEn;
}

class Governorate {
  final String govId;
  final String govEn;
  final String govAr;
  final List<Neighborhood>
  neighborhoods; // ✅ Changed from cities to neighborhoods

  Governorate({
    required this.govId,
    required this.govEn,
    required this.govAr,
    required this.neighborhoods,
  });

  factory Governorate.fromJson(Map<String, dynamic> json) {
    return Governorate(
      govId: json['gov_id'],
      govEn: json['gov_en'],
      govAr: json['gov_ar'],
      neighborhoods:
          (json['neighborhoods'] as List) // ✅ Changed from cities
              .map((n) => Neighborhood.fromJson(n))
              .toList(),
    );
  }

  String getName(bool isArabic) => isArabic ? govAr : govEn;
}

class Neighborhood {
  final String neighId;
  final String neighEn;
  final String neighAr;

  Neighborhood({
    required this.neighId,
    required this.neighEn,
    required this.neighAr,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      neighId: json['neigh_id'],
      neighEn: json['neigh_en'],
      neighAr: json['neigh_ar'],
    );
  }

  String getName(bool isArabic) => isArabic ? neighAr : neighEn;
}

import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class UserModel {
  String? uid;
  String role;
  String? name;
  String? email;
  String? phone;
  String? country;
  String? lanCode;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  LocationModel? location;
  LiveLocation? liveLocation;
  bool? isAdmin;
  bool? isVerified;
  String? districtName;
  List<String>? jobRoles;
  String? docUrl;
  String? profileUrl;
  String? fcmToken;
  double? rating;
  String? availableBalance;
  String? paidAmounts;
  List<String>? certifications;
  List<PayoutAccountModel>? payoutAccounts = <PayoutAccountModel>[];
  double? paidoutTips;
  bool? isOnline;
  String? highestTier;
  double? totalMonthlyBonus;
  Timestamp? lastBonusDate;
  String? tier;
  GeoPoint? lastKnownLocation;
  String? geohash;

  UserModel({
    required this.role,
    this.uid,
    this.name,
    this.certifications,
    this.email,
    this.phone,
    this.lanCode,
    this.country,
    this.createdAt,
    this.updatedAt,
    this.location,
    this.liveLocation,
    this.isAdmin,
    this.isVerified,
    this.districtName,
    this.jobRoles,
    this.docUrl,
    this.profileUrl,
    this.fcmToken,
    this.rating,
    this.isOnline,
    this.payoutAccounts,
    this.availableBalance,
    this.paidAmounts,
    this.highestTier,
    this.totalMonthlyBonus,
    this.lastBonusDate,
    this.paidoutTips,
    this.tier,
    this.lastKnownLocation,
    this.geohash,
  });

  UserModel copyWith({
    String? uid,
    String? role,
    String? name,
    String? email,
    String? phone,
    String? country,
    String? lanCode,
    LocationModel? location,
    LiveLocation? liveLocation,
    List<String>? favourites,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? isAdmin,
    bool? isVerified,
    String? districtName,
    List<String>? jobRoles,
    String? docUrl,
    String? profileUrl,
    String? fcmToken,
    double? rating,
    List<PayoutAccountModel>? payoutAccounts,
    String? availableBalance,
    String? paidAmounts,
    String? highestTier,
    double? totalMonthlyBonus,
    List<String>? certifications,
    Timestamp? lastBonusDate,
    double? paidoutTips,
    bool? isOnline,
    String? tier,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      districtName: districtName ?? this.districtName,
      location: location ?? this.location,
      liveLocation: liveLocation ?? this.liveLocation,
      lanCode: lanCode ?? this.lanCode,
      country: country ?? this.country,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdmin: isAdmin ?? this.isAdmin,
      isVerified: isVerified ?? this.isVerified,
      jobRoles: jobRoles ?? this.jobRoles,
      docUrl: docUrl ?? this.docUrl,
      profileUrl: profileUrl ?? this.profileUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      rating: rating ?? this.rating,
      availableBalance: availableBalance ?? this.availableBalance,
      paidAmounts: paidAmounts ?? this.paidAmounts,
      payoutAccounts: payoutAccounts ?? this.payoutAccounts,
      highestTier: highestTier ?? this.highestTier,
      totalMonthlyBonus: totalMonthlyBonus ?? this.totalMonthlyBonus,
      lastBonusDate: lastBonusDate ?? this.lastBonusDate,
      paidoutTips: paidoutTips ?? this.paidoutTips,
      certifications: certifications ?? this.certifications,
      isOnline: isOnline ?? this.isOnline,
      tier: tier ?? this.tier,
      lastKnownLocation: lastKnownLocation ?? this.lastKnownLocation,
      geohash: geohash ?? this.geohash,
    );
  }

  factory UserModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    return UserModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      role: json['role'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      lanCode: json['lanCode'],
      country: json['country'],
      location: _parseLocation(json),
      liveLocation: json['liveLocation'] != null
          ? LiveLocation.fromJson(json['liveLocation'])
          : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isAdmin: json['isAdmin'] ?? false,
      isVerified: json['isVerified'] ?? false,
      districtName: json['districtName'],

      jobRoles: json['jobRoles'] != null
          ? List<String>.from(json['jobRoles'])
          : <String>[],
      docUrl: json['docUrl'],
      profileUrl: json['profileUrl'],
      fcmToken: json['fcmToken'],
      rating: json['rating'] != null
          ? (json['rating'] as num).toDouble()
          : null,
      payoutAccounts: json['payoutAccounts'] != null
          ? List<PayoutAccountModel>.from(
              json['payoutAccounts'].map((x) => PayoutAccountModel.fromJson(x)),
            )
          : [],
      availableBalance: json['availableBalance']?.toString(),
      paidAmounts: json['paidAmounts']?.toString(),
      highestTier: json['highestTier'],
      totalMonthlyBonus: json['totalMonthlyBonus'] != null
          ? (json['totalMonthlyBonus'] as num).toDouble()
          : null,
      lastBonusDate: json['lastBonusDate'],
      paidoutTips: json['paidoutTips'] != null
          ? (json['paidoutTips'] as num).toDouble()
          : null,
      certifications: json['certifications'] != null
          ? List<String>.from(json['certifications'])
          : <String>[],
      isOnline: json['isOnline'],
      tier: json['tier'],
      lastKnownLocation: json['last_known_location'],
      geohash: json['geohash'],
    );
  }

  Map<String, dynamic> toJson() {
    // Format phone number with country code when storing to Firebase
    final formattedPhone = phone != null
        ? CountryCodeDetector.convertToFirebaseFormat(
            phone!,
            countryCode: country,
          )
        : null;

    return {
      'uid': uid,
      'role': role,
      'name': name,
      'email': email,
      'phone': formattedPhone,
      'lanCode': lanCode,
      'country': country,
      'location': location?.toJson(),
      'createdAt': createdAt,

      'updatedAt': updatedAt,
      'isAdmin': isAdmin ?? false,
      'isVerified': isVerified ?? false,
      'districtName': districtName,
      'jobRoles': jobRoles,
      'docUrl': docUrl,
      'profileUrl': profileUrl,
      'fcmToken': fcmToken,
      'rating': rating,
      'payoutAccounts': payoutAccounts != null
          ? List<dynamic>.from(payoutAccounts!.map((x) => x.toJson()))
          : [],
      'availableBalance': availableBalance,
      'paidAmounts': paidAmounts,
      'highestTier': highestTier,
      'totalMonthlyBonus': totalMonthlyBonus,
      'lastBonusDate': lastBonusDate,
      'isOnline': isOnline,
      'certifications': certifications,
      'paidoutTips': paidoutTips,
      'tier': tier,
      'last_known_location': lastKnownLocation,
      'geohash': geohash,
    };
  }

  Map<String, dynamic> toFirestore() {
    // Format phone number with country code when storing to Firebase
    final formattedPhone = phone != null
        ? CountryCodeDetector.convertToFirebaseFormat(
            phone!,
            countryCode: country,
          )
        : null;

    return {
      'name': name,
      'role': role,
      'email': email,
      'phone': formattedPhone,
      'lanCode': lanCode,
      'country': country,
      'location': location?.toJson(),
      'liveLocation': liveLocation?.toJson(),

      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isAdmin': isAdmin ?? false,
      'isVerified': isVerified ?? false,
      'districtName': districtName,
      'jobRoles': jobRoles,
      'docUrl': docUrl,
      'profileUrl': profileUrl,
      'fcmToken': fcmToken,
      'rating': rating,
      'payoutAccounts': payoutAccounts ?? [],
      'availableBalance': availableBalance,
      'paidAmounts': paidAmounts,
      'highestTier': highestTier,
      'totalMonthlyBonus': totalMonthlyBonus,
      'lastBonusDate': lastBonusDate,
      'certifications': certifications,
      'isOnline': isOnline,
      'paidoutTips': paidoutTips,
      'tier': tier,
    };
  }

  Map<String, dynamic> toEditJson({required UserModel previous}) {
    Map<String, dynamic> json = {'updatedAt': FieldValue.serverTimestamp()};

    if (name != previous.name && name != null) {
      json['name'] = name;
    }
    if (role != previous.role && role != null) {
      json['role'] = role;
    }
    if (email != previous.email && email != null) {
      json['email'] = email;
    }
    if (phone != previous.phone && phone != null) {
      json['phone'] = phone;
    }
    if (lanCode != previous.lanCode && lanCode != null) {
      json['lanCode'] = lanCode;
    }
    if (country != previous.country && country != null) {
      json['country'] = country;
    }
    if (createdAt != previous.createdAt && createdAt != null) {
      json['createdAt'] = createdAt;
    }
    if (updatedAt != previous.updatedAt && updatedAt != null) {
      json['updatedAt'] = updatedAt;
    }
    if (isAdmin != previous.isAdmin && isAdmin != null) {
      json['isAdmin'] = isAdmin;
    }
    if (isVerified != previous.isVerified && isVerified != null) {
      json['isVerified'] = isVerified;
    }
    if (districtName != previous.districtName && districtName != null) {
      json['districtName'] = districtName;
    }
    if (jobRoles != previous.jobRoles && jobRoles != null) {
      json['jobRoles'] = jobRoles;
    }
    if (docUrl != previous.docUrl && docUrl != null) {
      json['docUrl'] = docUrl;
    }
    if (profileUrl != previous.profileUrl && profileUrl != null) {
      json['profileUrl'] = profileUrl;
    }
    if (fcmToken != previous.fcmToken && fcmToken != null) {
      json['fcmToken'] = fcmToken;
    }
    if (rating != previous.rating && rating != null) {
      json['rating'] = rating;
    }
    if (payoutAccounts != previous.payoutAccounts && payoutAccounts != null) {
      json['payoutAccounts'] = payoutAccounts;
    }
    if (availableBalance != previous.availableBalance &&
        availableBalance != null) {
      json['availableBalance'] = availableBalance;
    }
    if (paidAmounts != previous.paidAmounts && paidAmounts != null) {
      json['paidAmounts'] = paidAmounts;
    }
    if (highestTier != previous.highestTier && highestTier != null) {
      json['highestTier'] = highestTier;
    }
    if (totalMonthlyBonus != previous.totalMonthlyBonus &&
        totalMonthlyBonus != null) {
      json['totalMonthlyBonus'] = totalMonthlyBonus;
    }
    if (lastBonusDate != previous.lastBonusDate && lastBonusDate != null) {
      json['lastBonusDate'] = lastBonusDate;
    }

    if (certifications != previous.certifications && certifications != null) {
      json['certifications'] = certifications;
    }
    if (paidoutTips != previous.paidoutTips && paidoutTips != null) {
      json['paidoutTips'] = paidoutTips;
    }

    if (isOnline != previous.isOnline && isOnline != null) {
      json['isOnline'] = isOnline;
    }

    return json;
  }
}

// Keep your existing LiveLocation and PayoutAccountModel classes unchanged
class LiveLocation {
  double? latitude;
  double? longitude;
  LiveLocation({this.latitude, this.longitude});
  LiveLocation.fromJson(Map<String, dynamic> json) {
    latitude = json['latitude'];
    longitude = json['longitude'];
  }
  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  @override
  String toString() {
    return 'LiveLocation(latitude: $latitude, longitude: $longitude)';
  }
}

class PayoutAccountModel {
  String? id;
  String? accountHolderName;
  String? accountNumber;
  String? bankName;
  String? ifscCode;
  bool isPrimary;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  PayoutAccountModel({
    this.id,
    this.accountHolderName,
    this.accountNumber,
    this.bankName,
    this.ifscCode,
    this.isPrimary = false,
    this.createdAt,
    this.updatedAt,
  });

  PayoutAccountModel copyWith({
    String? id,
    String? accountHolderName,
    String? accountNumber,
    String? bankName,
    String? ifscCode,
    String? accountType,
    bool? isPrimary,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return PayoutAccountModel(
      id: id ?? this.id,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      ifscCode: ifscCode ?? this.ifscCode,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PayoutAccountModel.fromJson(Map<String, dynamic> json) {
    return PayoutAccountModel(
      id: json['id'],
      accountHolderName: json['accountHolderName'],
      accountNumber: json['accountNumber'],
      bankName: json['bankName'],
      ifscCode: json['ifscCode'],
      isPrimary: json['isPrimary'] ?? false,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'ifscCode': ifscCode,
      'isPrimary': isPrimary,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory PayoutAccountModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return PayoutAccountModel(
      id: snapshot.id,
      accountHolderName: data?['accountHolderName'],
      accountNumber: data?['accountNumber'],
      bankName: data?['bankName'],
      ifscCode: data?['ifscCode'],
      isPrimary: data?['isPrimary'] ?? false,
      createdAt: data?['createdAt'],
      updatedAt: data?['updatedAt'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'bankName': bankName,
      'ifscCode': ifscCode,
      'isPrimary': isPrimary,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory PayoutAccountModel.fromMap(Map<String, dynamic> map) {
    return PayoutAccountModel(
      id: map['id'],
      accountHolderName: map['accountHolderName'],
      accountNumber: map['accountNumber'],
      bankName: map['bankName'],
      ifscCode: map['ifscCode'],
      isPrimary: map['isPrimary'] ?? false,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

/// Attempt to build a [LocationModel] from any legacy or current JSON shape.
/// Priority: new 'location' key → migrate from 'detailedLocation' key.
LocationModel? _parseLocation(Map<String, dynamic> json) {
  // New unified format
  if (json['location'] is Map<String, dynamic>) {
    final raw = json['location'] as Map<String, dynamic>;
    if (raw.containsKey('lat') || raw.containsKey('fullAddress')) {
      return LocationModel.fromJson(raw);
    }
  }

  // Legacy: migrate from detailedLocation
  if (json['detailedLocation'] is Map<String, dynamic>) {
    final dl = json['detailedLocation'] as Map<String, dynamic>;
    final neighborhoodEn = dl['neighborhoodEn'] as String?;
    final cityEn = dl['cityEn'] as String?;
    final regionEn = dl['regionEn'] as String?;
    final lat = (dl['lat'] as num?)?.toDouble();
    final lon = (dl['lon'] as num?)?.toDouble();

    final parts = <String>[
      if (neighborhoodEn != null && neighborhoodEn.trim().isNotEmpty)
        neighborhoodEn.trim(),
      if (cityEn != null && cityEn.trim().isNotEmpty) cityEn.trim(),
      if (regionEn != null && regionEn.trim().isNotEmpty) regionEn.trim(),
    ];

    return LocationModel(
      lat: lat,
      lon: lon,
      city: cityEn,
      province: regionEn,
      street: neighborhoodEn,
      fullAddress: parts.isNotEmpty ? parts.join(', ') : null,
    );
  }

  return null;
}

// lib/models/detailed_location.dart
class DetailedLocationModel {
  // Province
  final String? regionId;
  final String? regionEn;
  final String? regionAr;

  // Governorate
  final String? cityId;
  final String? cityEn;
  final String? cityAr;

  // Neighborhood
  final String? neighborhoodId;
  final String? neighborhoodEn;
  final String? neighborhoodAr;

  final double? lon;
  final double? lat;

  DetailedLocationModel({
    this.regionId,
    this.regionEn,
    this.regionAr,
    this.cityId,
    this.cityEn,
    this.cityAr,
    this.neighborhoodId,
    this.neighborhoodEn,
    this.neighborhoodAr,
    this.lon,
    this.lat,
  });

  factory DetailedLocationModel.fromJson(Map<String, dynamic> json) {
    return DetailedLocationModel(
      regionId: json['regionId'],
      regionEn: json['regionEn'],
      regionAr: json['regionAr'],
      cityId: json['cityId'],
      cityEn: json['cityEn'],
      cityAr: json['cityAr'],
      neighborhoodId: json['neighborhoodId'],
      neighborhoodEn: json['neighborhoodEn'],
      neighborhoodAr: json['neighborhoodAr'],
      lon: json['lon'],
      lat: json['lat'],
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
      'neighborhoodId': neighborhoodId,
      'neighborhoodEn': neighborhoodEn,
      'neighborhoodAr': neighborhoodAr,
      'lat': lat,
      'lon': lon,
    };
  }

  DetailedLocationModel copyWith({
    String? regionId,
    String? regionEn,
    String? regionAr,
    String? cityId,
    String? cityEn,
    String? cityAr,
    String? neighborhoodId,
    String? neighborhoodEn,
    String? neighborhoodAr,
    double? lon,
    double? lat,
  }) {
    return DetailedLocationModel(
      regionId: regionId ?? this.regionId,
      regionEn: regionEn ?? this.regionEn,
      regionAr: regionAr ?? this.regionAr,
      cityId: cityId ?? this.cityId,
      cityEn: cityEn ?? this.cityEn,
      cityAr: cityAr ?? this.cityAr,
      neighborhoodId: neighborhoodId ?? this.neighborhoodId,
      neighborhoodEn: neighborhoodEn ?? this.neighborhoodEn,
      neighborhoodAr: neighborhoodAr ?? this.neighborhoodAr,
      lon: lon ?? this.lon,
      lat: lat ?? this.lat,
    );
  }

  // Helper methods
  String getProvinceName(bool isArabic) =>
      isArabic ? (regionAr ?? regionEn ?? '') : (regionEn ?? '');

  String getGovernorateName(bool isArabic) =>
      isArabic ? (cityAr ?? cityEn ?? '') : (cityEn ?? '');

  String getNeighborhoodName(bool isArabic) => isArabic
      ? (neighborhoodAr ?? neighborhoodEn ?? '')
      : (neighborhoodEn ?? '');

  // Get full address: Neighborhood, Governorate, Province
  String getFullAddress(bool isArabic) {
    final parts = <String>[];
    if (neighborhoodEn != null && neighborhoodEn!.isNotEmpty) {
      parts.add(getNeighborhoodName(isArabic));
    }
    if (cityEn != null && cityEn!.isNotEmpty) {
      parts.add(getGovernorateName(isArabic));
    }
    if (regionEn != null && regionEn!.isNotEmpty) {
      parts.add(getProvinceName(isArabic));
    }
    return parts.join(', ');
  }

  // Get short address (Neighborhood, Governorate)
  String getShortAddress(bool isArabic) {
    final parts = <String>[];
    if (neighborhoodEn != null && neighborhoodEn!.isNotEmpty) {
      parts.add(getNeighborhoodName(isArabic));
    }
    if (cityEn != null && cityEn!.isNotEmpty) {
      parts.add(getGovernorateName(isArabic));
    }
    return parts.join(', ');
  }

  @override
  String toString() {
    return 'DetailedLocationModel(province: $regionEn, governorate: $cityEn, neighborhood: $neighborhoodEn)';
  }
}

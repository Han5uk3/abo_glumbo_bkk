import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/location.dart'; // Added
import 'package:abo_glumbo_bbk/helpers/country_code_detector.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerModel {
  final String role;
  final String? uid;
  final String? name;
  final String? email;
  final String? phone;
  final String? country;
  final String? fcmToken;
  final String? lanCode;
  
  // Detailed address fields added for consistency with technician app and invoices
  final LocationModel? location;
  final String? buildingNumber;
  final String? streetName;
  final String? districtName;
  final String? cityName;
  final String? postcode;

  // Multiple saved addresses
  final List<AddressModel> addresses;

  // Favorites (technician UIDs)
  final List<String> favourites;

  // Timestamps
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  // Admin flag
  final bool? isAdmin;

  // Block status
  final bool? isBlocked;

  CustomerModel({
    this.uid,
    required this.role,
    this.name,
    this.email,
    this.phone,
    this.fcmToken,
    this.lanCode,
    this.country,
    this.location,
    this.buildingNumber,
    this.streetName,
    this.districtName,
    this.cityName,
    this.postcode,
    this.addresses = const [],
    this.favourites = const [],
    this.createdAt,
    this.updatedAt,
    this.isAdmin,
    this.isBlocked,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      uid: json['uid'] ?? '',
      name: json['name'],
      email: json['email'],
      role: json['role'],
      phone: json['phone'],
      fcmToken: json['fcmToken'],
      lanCode: json['lanCode'],
      country: json['country'],
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      buildingNumber: json['buildingNumber'],
      streetName: json['streetName'],
      districtName: json['districtName'],
      cityName: json['cityName'],
      postcode: json['postcode'],
      addresses:
          (json['addresses'] as List<dynamic>?)
              ?.map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      favourites:
          (json['favourites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isAdmin: json['isAdmin'],
      isBlocked: json['isBlocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    // Format phone number with country code when storing to Firebase
    final formattedPhone = phone != null
        ? CountryCodeDetector.convertToFirebaseFormat(phone!, countryCode: country)
        : null;

    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': formattedPhone,
      'role': role,
      'fcmToken': fcmToken,
      'lanCode': lanCode,
      'country': country,
      'location': location?.toJson(),
      'buildingNumber': buildingNumber,
      'streetName': streetName,
      'districtName': districtName,
      'cityName': cityName,
      'postcode': postcode,
      'addresses': addresses.map((e) => e.toJson()).toList(),
      'favourites': favourites,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isAdmin': isAdmin,
      'isBlocked': isBlocked ?? false,
    };
  }

  CustomerModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? fcmToken,
    String? lanCode,
    required String role,
    String? country,
    LocationModel? location,
    String? buildingNumber,
    String? streetName,
    String? districtName,
    String? cityName,
    String? postcode,
    List<AddressModel>? addresses,
    List<String>? favourites,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    bool? isAdmin,
    bool? isBlocked,
  }) {
    return CustomerModel(
      uid: uid ?? this.uid,
      role: role,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      lanCode: lanCode ?? this.lanCode,
      country: country ?? this.country,
      location: location ?? this.location,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      streetName: streetName ?? this.streetName,
      districtName: districtName ?? this.districtName,
      cityName: cityName ?? this.cityName,
      postcode: postcode ?? this.postcode,
      addresses: addresses ?? this.addresses,
      favourites: favourites ?? this.favourites,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isAdmin: isAdmin ?? this.isAdmin,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  Map<String, dynamic> toEditJson({required CustomerModel previous}) {
    final Map<String, dynamic> json = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    void checkAndSet(String key, dynamic current, dynamic previousValue) {
      if (current != previousValue && current != null) {
        json[key] = current;
      }
    }

    checkAndSet('name', name, previous.name);
    checkAndSet('role', role, previous.role);
    checkAndSet('email', email, previous.email);
    
    // Format phone number with country code for Firebase
    final formattedPhone = phone != null
        ? CountryCodeDetector.convertToFirebaseFormat(phone!, countryCode: country)
        : null;
    final formattedPreviousPhone = previous.phone != null
        ? CountryCodeDetector.convertToFirebaseFormat(previous.phone!, countryCode: previous.country)
        : null;
    checkAndSet('phone', formattedPhone, formattedPreviousPhone);
    
    checkAndSet('fcmToken', fcmToken, previous.fcmToken);
    checkAndSet('lanCode', lanCode, previous.lanCode);
    checkAndSet('country', country, previous.country);
    checkAndSet('location', location?.toJson(), previous.location?.toJson());
    checkAndSet('buildingNumber', buildingNumber, previous.buildingNumber);
    checkAndSet('streetName', streetName, previous.streetName);
    checkAndSet('districtName', districtName, previous.districtName);
    checkAndSet('cityName', cityName, previous.cityName);
    checkAndSet('postcode', postcode, previous.postcode);

    checkAndSet(
      'addresses',
      addresses.map((e) => e.toJson()).toList(),
      previous.addresses.map((e) => e.toJson()).toList(),
    );
    checkAndSet('favourites', favourites, previous.favourites);
    checkAndSet('createdAt', createdAt, previous.createdAt);
    checkAndSet('isAdmin', isAdmin, previous.isAdmin);
    checkAndSet('isBlocked', isBlocked, previous.isBlocked);

    return json;
  }
}

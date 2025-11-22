import 'package:abo_glumbo_bbk/models/address.dart';
import 'package:abo_glumbo_bbk/models/location.dart';
import 'package:abo_glumbo_bbk/models/user.dart';
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

  // Location models
  final LocationModel?
  location; // Old location model (keep for backward compatibility)
  final DetailedLocationModel? detailedLocation; // ✅ New structured location

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
    this.detailedLocation,
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
      detailedLocation: json['detailedLocation'] != null
          ? DetailedLocationModel.fromJson(json['detailedLocation'])
          : null,
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
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'fcmToken': fcmToken,
      'lanCode': lanCode,
      'country': country,
      'location': location?.toJson(),
      'detailedLocation': detailedLocation?.toJson(),
      'addresses': addresses.map((e) => e.toJson()).toList(),
      'favourites': favourites,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isAdmin': isAdmin,
      // Don't include deprecated fields in new documents
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
    DetailedLocationModel? detailedLocation,
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
      detailedLocation: detailedLocation ?? this.detailedLocation,
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
    checkAndSet('phone', phone, previous.phone);
    checkAndSet('fcmToken', fcmToken, previous.fcmToken);
    checkAndSet('lanCode', lanCode, previous.lanCode);
    checkAndSet('country', country, previous.country);
    checkAndSet('location', location?.toJson(), previous.location?.toJson());
    checkAndSet(
      'detailedLocation',
      detailedLocation?.toJson(),
      previous.detailedLocation?.toJson(),
    );
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

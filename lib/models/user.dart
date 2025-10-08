import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/location.dart';

class UserModel {
  String uid;
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
  String? rating;

  UserModel({
    required this.uid,
    this.name,
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
  });

  UserModel copyWith({
    String? uid,
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
    String? rating,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
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
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      lanCode: json['lanCode'],
      country: json['country'],
      liveLocation: json['liveLocation'] != null
          ? LiveLocation.fromJson(json['liveLocation'])
          : null,
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      isAdmin: json['isAdmin'] ?? false,
      isVerified: json['isVerified'] ?? false,
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'])
          : null,
      districtName: json['districtName'],
      jobRoles: json['jobRoles'] != null
          ? List<String>.from(json['jobRoles'])
          : <String>[],
      docUrl: json['docUrl'],
      profileUrl: json['profileUrl'],
      fcmToken: json['fcmToken'],
      rating: json['rating'],
    );
  }

  // from document snapshot
  factory UserModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return UserModel.fromJson(data).copyWith(uid: snapshot.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'lanCode': lanCode,
      'country': country,
      'createdAt': createdAt,
      'location': location?.toJson(),
      'updatedAt': updatedAt,
      'isAdmin': isAdmin ?? false,
      'isVerified': isVerified ?? false,
      'districtName': districtName,
      'jobRoles': jobRoles,
      'docUrl': docUrl,
      'profileUrl': profileUrl,
      'fcmToken': fcmToken,
    };
  }

  // to edit json
  Map<String, dynamic> toEditJson({required UserModel previous}) {
    Map<String, dynamic> json = {'updatedAt': FieldValue.serverTimestamp()};

    if (name != previous.name && name != null) {
      json['name'] = name;
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
    return json;
  }
}

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

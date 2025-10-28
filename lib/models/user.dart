import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/location.dart';

class UserModel {
  String? uid;
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
  List<PayoutAccountModel>? payoutAccounts = <PayoutAccountModel>[];

  // Optional: Tier summary fields (for quick access on dashboard)
  String? highestTier; // 'Bronze', 'Silver', 'Gold', 'Platinum'
  double?
  totalMonthlyBonus; // Total bonus earned this month across all categories
  Timestamp? lastBonusDate; // Last time bonus was received

  UserModel({
    this.uid,
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
    this.payoutAccounts,
    this.availableBalance,
    this.paidAmounts,
    this.highestTier,
    this.totalMonthlyBonus,
    this.lastBonusDate,
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
    double? rating,
    List<PayoutAccountModel>? payoutAccounts,
    String? availableBalance,
    String? paidAmounts,
    String? highestTier,
    double? totalMonthlyBonus,
    Timestamp? lastBonusDate,
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
      availableBalance: availableBalance ?? this.availableBalance,
      paidAmounts: paidAmounts ?? this.paidAmounts,
      payoutAccounts: payoutAccounts ?? this.payoutAccounts,
      highestTier: highestTier ?? this.highestTier,
      totalMonthlyBonus: totalMonthlyBonus ?? this.totalMonthlyBonus,
      lastBonusDate: lastBonusDate ?? this.lastBonusDate,
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
      districtName: json['districtName'],
      location: json['location'] != null
          ? LocationModel.fromJson(json['location'])
          : null,
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
          : <PayoutAccountModel>[],
      // FIX: Convert numeric values to strings
      availableBalance: json['availableBalance']?.toString(),
      paidAmounts: json['paidAmounts']?.toString(),
      highestTier: json['highestTier'],
      totalMonthlyBonus: json['totalMonthlyBonus'] != null
          ? (json['totalMonthlyBonus'] as num).toDouble()
          : null,
      lastBonusDate: json['lastBonusDate'],
    );
  }

  factory UserModel.fromDocumentSnapshot(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return UserModel.fromJson(data).copyWith(uid: snapshot.id);
  }
  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return UserModel(
      uid: snapshot.id,
      name: data?['name'],
      email: data?['email'],
      phone: data?['phone'],
      lanCode: data?['lanCode'],
      country: data?['country'],
      liveLocation: data?['liveLocation'] != null
          ? LiveLocation.fromJson(data!['liveLocation'])
          : null,
      location: data?['location'] != null
          ? LocationModel.fromJson(data!['location'])
          : null,
      createdAt: data?['createdAt'],
      updatedAt: data?['updatedAt'],
      isAdmin: data?['isAdmin'] ?? false,
      isVerified: data?['isVerified'] ?? false,
      districtName: data?['districtName'],
      jobRoles: data?['jobRoles'] != null
          ? List<String>.from(data!['jobRoles'])
          : <String>[],
      docUrl: data?['docUrl'],
      profileUrl: data?['profileUrl'],
      fcmToken: data?['fcmToken'],
      rating: data?['rating'] != null
          ? (data!['rating'] as num).toDouble()
          : null,
      payoutAccounts: data?['payoutAccounts'] != null
          ? List<PayoutAccountModel>.from(
              data!['payoutAccounts'].map(
                (x) => PayoutAccountModel.fromJson(x),
              ),
            )
          : <PayoutAccountModel>[],
      // FIX: Convert numeric values to strings
      availableBalance: data?['availableBalance']?.toString(),
      paidAmounts: data?['paidAmounts']?.toString(),
      highestTier: data?['highestTier'],
      totalMonthlyBonus: data?['totalMonthlyBonus'] != null
          ? (data!['totalMonthlyBonus'] as num).toDouble()
          : null,
      lastBonusDate: data?['lastBonusDate'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'lanCode': lanCode,
      'country': country,
      'liveLocation': liveLocation?.toJson(),
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
      'payoutAccounts': payoutAccounts,
      'availableBalance': availableBalance,
      'paidAmounts': paidAmounts,
      'highestTier': highestTier,
      'totalMonthlyBonus': totalMonthlyBonus,
      'lastBonusDate': lastBonusDate,
    };
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
      'rating': rating,
      'payoutAccounts': payoutAccounts,
      'availableBalance': availableBalance,
      'paidAmounts': paidAmounts,
      'highestTier': highestTier,
      'totalMonthlyBonus': totalMonthlyBonus,
      'lastBonusDate': lastBonusDate,
    };
  }

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

    return json;
  }
}

// Keep your existing LiveLocation and PayoutAccountModel classes unchanged
class LiveLocation {
  double? latitude;
  double? longitude;

  LiveLocation({this.latitude, this.longitude});

  LiveLocation.fromJson(Map<String, dynamic> json) {
    latitude = json['latitude'] != null
        ? (json['latitude'] as num).toDouble()
        : null; // FIX HERE
    longitude = json['longitude'] != null
        ? (json['longitude'] as num).toDouble()
        : null; // FIX HERE
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
  String? accountType;
  bool isPrimary;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  PayoutAccountModel({
    this.id,
    this.accountHolderName,
    this.accountNumber,
    this.bankName,
    this.ifscCode,
    this.accountType,
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
      accountType: accountType ?? this.accountType,
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
      accountType: json['accountType'],
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
      'accountType': accountType,
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
      accountType: data?['accountType'],
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
      'accountType': accountType,
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
      accountType: map['accountType'],
      isPrimary: map['isPrimary'] ?? false,
      createdAt: map['createdAt'],
      updatedAt: map['updatedAt'],
    );
  }
}

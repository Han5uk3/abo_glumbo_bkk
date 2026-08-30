import 'package:abo_glumbo_bbk/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class WarrantyModel {
  String? id;
  String? assignedTechnicianId;
  String warrantyStatusCode;
  bool? claimrequested;
  List<RejectedTechnicianModel>? rejectedTechnicians;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? requestedOn;
  DateTime? completedAt;
  DateTime? acceptedAt;
  DateTime? rejectedAt;
  DateTime? expiredOn;
  DateTime? preferredDateTime;
  bool? availability;
  Map<String, dynamic>? assignedTechnician;

  UserModel? get assignedTechnicianModel {
    if (assignedTechnician != null && assignedTechnician!.isNotEmpty) {
      try {
        return UserModel.fromJson(assignedTechnician!);
      } catch (e) {
        debugPrint('Error parsing assignedTechnician: $e');
      }
    }
    return null;
  }


  WarrantyModel({
    this.id,
    this.assignedTechnicianId,
    this.warrantyStatusCode = 'A',
    this.claimrequested,
    this.rejectedTechnicians = const [],
    this.createdAt,
    this.updatedAt,
    this.requestedOn,
    this.completedAt,
    this.acceptedAt,
    this.rejectedAt,
    this.expiredOn,
    this.preferredDateTime,
    this.availability,
    this.assignedTechnician,
  });

  factory WarrantyModel.fromJson(Map<String, dynamic> json) {
    return WarrantyModel(
      id: json['id'],
      assignedTechnicianId: json['assignedTechnicianId'],
      warrantyStatusCode: json['warrantyStatusCode']?.toString() ?? 'A',
      claimrequested: json['claimrequested'] as bool?,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : json['createdAt'] as DateTime?,
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : json['updatedAt'] as DateTime?,
      requestedOn: json['requestedOn'] is Timestamp
          ? (json['requestedOn'] as Timestamp).toDate()
          : json['requestedOn'] as DateTime?,
      completedAt: json['completedAt'] is Timestamp
          ? (json['completedAt'] as Timestamp).toDate()
          : json['completedAt'] as DateTime?,
      acceptedAt: json['acceptedAt'] is Timestamp
          ? (json['acceptedAt'] as Timestamp).toDate()
          : (json['acceptedAt'] as DateTime?) ??
                (json['acceptedOn'] is Timestamp
                    ? (json['acceptedOn'] as Timestamp).toDate()
                    : json['acceptedOn'] as DateTime?),
      rejectedAt: json['rejectedAt'] is Timestamp
          ? (json['rejectedAt'] as Timestamp).toDate()
          : json['rejectedAt'] as DateTime?,
      expiredOn: json['expiredOn'] is Timestamp
          ? (json['expiredOn'] as Timestamp).toDate()
          : json['expiredOn'] as DateTime?,
      preferredDateTime: json['preferredDateTime'] is Timestamp
          ? (json['preferredDateTime'] as Timestamp).toDate()
          : json['preferredDateTime'] as DateTime?,
      availability: json['availability'] as bool?,
      assignedTechnician: json['assignedTechnician'] is Map
          ? (json['assignedTechnician'] is Map<String, dynamic>
              ? json['assignedTechnician'] as Map<String, dynamic>
              : Map<String, dynamic>.from(json['assignedTechnician'] as Map))
          : null,

      rejectedTechnicians: (json['rejectedTechnicians'] is List)
          ? (json['rejectedTechnicians'] as List)
                .map(
                  (e) => RejectedTechnicianModel.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignedTechnicianId': assignedTechnicianId,
      'warrantyStatusCode': warrantyStatusCode,
      'claimrequested': claimrequested,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'requestedOn': requestedOn,
      'completedAt': completedAt,
      'acceptedAt': acceptedAt,
      'rejectedAt': rejectedAt,
      'expiredOn': expiredOn,
      'preferredDateTime': preferredDateTime,
      'availability': availability,
      'assignedTechnician': assignedTechnician,

      'rejectedTechnicians': rejectedTechnicians
          ?.map((e) => e.toJson())
          .toList(),
    };
  }

  static WarrantyModel fromDocumentSnapshot(QueryDocumentSnapshot doc) {
    return WarrantyModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  @override
  String toString() {
    return 'WarrantyModel(id: $id, status: $warrantyStatusCode, '
        'assignedTo: $assignedTechnicianId, '
        'requestedOn: $requestedOn, acceptedAt: $acceptedAt, '
        'completedAt: $completedAt, rejectedAt: $rejectedAt)';
  }
}

class RejectedTechnicianModel {
  String? uid;
  String? name;
  String? phone;
  String? reason;
  DateTime? rejectedAt;

  RejectedTechnicianModel({this.uid, this.name, this.phone, this.reason, this.rejectedAt});

  factory RejectedTechnicianModel.fromJson(Map<String, dynamic> json) {
    return RejectedTechnicianModel(
      uid: json['uid'],
      name: json['name'],
      phone: json['phone'],
      reason: json['reason'],
      rejectedAt: (json['rejectedAt'] is Timestamp)
          ? (json['rejectedAt'] as Timestamp).toDate()
          : (json['rejectedAt'] as DateTime?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid, 
      'name': name, 
      'phone': phone,
      'reason': reason,
      'rejectedAt': rejectedAt
    };
  }
}

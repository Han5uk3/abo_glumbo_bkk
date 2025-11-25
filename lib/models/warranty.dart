import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyModel {
  String? id;
  String? assignedTechnicianId;
  String warrantyStatusCode;
  bool? claimrequested;
  List<RejectedTechnicianModel>? rejectedTechnicians;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime? requestedOn;
  DateTime? completedOn;
  DateTime? acceptedOn;
  DateTime? rejectedOn;
  DateTime? expiredOn;

  WarrantyModel({
    this.id,
    this.assignedTechnicianId,
    this.warrantyStatusCode = 'A',
    this.claimrequested,
    this.rejectedTechnicians = const [],
    this.createdAt,
    this.updatedAt,
    this.requestedOn,
    this.completedOn,
    this.acceptedOn,
    this.rejectedOn,
    this.expiredOn,
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
      completedOn: json['completedOn'] is Timestamp
          ? (json['completedOn'] as Timestamp).toDate()
          : json['completedOn'] as DateTime?,
      acceptedOn: json['acceptedOn'] is Timestamp
          ? (json['acceptedOn'] as Timestamp).toDate()
          : json['acceptedOn'] as DateTime?,
      rejectedOn: json['rejectedOn'] is Timestamp
          ? (json['rejectedOn'] as Timestamp).toDate()
          : json['rejectedOn'] as DateTime?,
      expiredOn: json['expiredOn'] is Timestamp
          ? (json['expiredOn'] as Timestamp).toDate()
          : json['expiredOn'] as DateTime?,
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
      'completedOn': completedOn,
      'acceptedOn': acceptedOn,
      'rejectedOn': rejectedOn,
      'expiredOn': expiredOn,
      'rejectedTechnicians': rejectedTechnicians
          ?.map((e) => e.toJson())
          .toList(),
    };
  }

  static WarrantyModel fromDocumentSnapshot(QueryDocumentSnapshot doc) {
    return WarrantyModel.fromJson(doc.data() as Map<String, dynamic>);
  }
}

class RejectedTechnicianModel {
  String? uid;
  String? name;
  DateTime? rejectedOn;

  RejectedTechnicianModel({this.uid, this.name, this.rejectedOn});

  factory RejectedTechnicianModel.fromJson(Map<String, dynamic> json) {
    return RejectedTechnicianModel(
      uid: json['uid'],
      name: json['name'],
      rejectedOn: (json['rejectedOn'] is Timestamp)
          ? (json['rejectedOn'] as Timestamp).toDate()
          : (json['rejectedOn'] as DateTime?),
    );
  }

  Map<String, dynamic> toJson() {
    return {'uid': uid, 'name': name, 'rejectedOn': rejectedOn};
  }
}

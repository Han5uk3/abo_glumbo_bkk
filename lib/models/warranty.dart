import 'package:cloud_firestore/cloud_firestore.dart';

class WarrantyModel {
  String? id;
  String? bookingId;
  String? customerId;
  String? assignedTechnicianId;
  String? technicianId;
  bool? availability;
  bool? claimStatus;
  List<RejectedTechnicianModel>? rejectedTechnicians;
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isTracking = false;
  bool completed = false;

  WarrantyModel({
    this.id,
    this.bookingId,
    this.customerId,
    this.assignedTechnicianId,
    this.technicianId,
    this.availability,
    this.claimStatus,
    this.createdAt,
    this.rejectedTechnicians,
    this.updatedAt,
    this.isTracking = false,
    this.completed = false,
  });

  factory WarrantyModel.fromJson(Map<String, dynamic> json) {
    return WarrantyModel(
      id: json['id'],
      bookingId: json['bookingId'],
      customerId: json['customerId'],
      assignedTechnicianId: json['assignedTechnicianId'],
      technicianId: json['technicianId'],
      availability: json['availability'],
      isTracking: json['isTracking'],
      completed: json['completed'],
      claimStatus: json['claimStatus'],
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : (json['createdAt'] as DateTime?),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : (json['updatedAt'] as DateTime?),
      rejectedTechnicians: json['rejectedTechnicians'] != null
          ? (json['rejectedTechnicians'] as List)
                .map((e) => RejectedTechnicianModel.fromJson(e))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookingId': bookingId,
      'customerId': customerId,
      'assignedTechnicianId': assignedTechnicianId,
      'technicianId': technicianId,
      'availability': availability,
      'claimStatus': claimStatus,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'rejectedTechnicians': rejectedTechnicians,
      'isTracking': isTracking,
      'completed': completed,
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

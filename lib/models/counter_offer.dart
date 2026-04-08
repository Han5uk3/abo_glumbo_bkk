import 'package:cloud_firestore/cloud_firestore.dart';

class CounterOfferModel {
  final String? id;
  final String bookingId;
  final String proposedBy; // 'technician' or 'customer'
  final String proposedByUid;
  final String proposedByName;
  final Timestamp proposedTime;
  final String status; // 'pending', 'accepted', 'rejected'
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  CounterOfferModel({
    this.id,
    required this.bookingId,
    required this.proposedBy,
    required this.proposedByUid,
    required this.proposedByName,
    required this.proposedTime,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  factory CounterOfferModel.fromMap(Map<String, dynamic> map, {String? id}) {
    return CounterOfferModel(
      id: id ?? map['id'],
      bookingId: map['bookingId'] ?? '',
      proposedBy: map['proposedBy'] ?? '',
      proposedByUid: map['proposedByUid'] ?? '',
      proposedByName: map['proposedByName'] ?? '',
      proposedTime: map['proposedTime'] as Timestamp,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] as Timestamp,
      updatedAt: map['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'bookingId': bookingId,
      'proposedBy': proposedBy,
      'proposedByUid': proposedByUid,
      'proposedByName': proposedByName,
      'proposedTime': proposedTime,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? createdAt,
    };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceModel {
  final String id;
  final String invoiceUrl;
  final Timestamp createdAt;
  final String bookingId;
  final String? newBookingId;
  final String userId;
  final String? technicianId;

  InvoiceModel({
    required this.id,
    required this.invoiceUrl,
    required this.createdAt,
    required this.bookingId,
    this.newBookingId,
    required this.userId,
    this.technicianId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceUrl': invoiceUrl,
      'createdAt': createdAt,
      'bookingId': bookingId,
      if (newBookingId != null) 'newBookingId': newBookingId,
      'userId': userId,
      if (technicianId != null) 'technicianId': technicianId,
    };
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> map) {
    return InvoiceModel(
      id: map['id'],
      invoiceUrl: map['invoiceUrl'],
      createdAt: map['createdAt'],
      bookingId: map['bookingId'],
      newBookingId: map['newBookingId'],
      userId: map['userId'],
      technicianId: map['technicianId'],
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:abo_glumbo_bbk/models/service.dart';
import 'package:abo_glumbo_bbk/models/customer.dart';
import 'package:abo_glumbo_bbk/models/address.dart';

class JobRequestModel {
  final String id;
  final String? newBookingId;
  final ServiceModel service;
  final CustomerModel customer;
  final AddressModel address;
  final String notes;
  final String? issueImage;
  final String? issueVideo;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final bool isOnHour;
  final Timestamp? bookingDateTime;
  final String status;
  final bool isRebook;
  final String? rebookTechnicianId;

  JobRequestModel({
    required this.id,
    this.newBookingId,
    required this.service,
    required this.customer,
    required this.address,
    required this.notes,
    this.issueImage,
    this.issueVideo,
    required this.createdAt,
    required this.expiresAt,
    required this.isOnHour,
    this.bookingDateTime,
    required this.status,
    this.isRebook = false,
    this.rebookTechnicianId,
  });

  factory JobRequestModel.fromJson(Map<String, dynamic> json) {
    return JobRequestModel(
      id: json['id'] ?? '',
      newBookingId: json['newBookingId'],
      service: ServiceModel.fromJson(json['service']),
      customer: CustomerModel.fromJson(json['customer']),
      address: AddressModel.fromJson(json['address']),
      notes: json['notes'] ?? '',
      issueImage: json['issueImage'],
      issueVideo: json['issueVideo'],
      createdAt: json['createdAt'] as Timestamp,
      expiresAt: json['expiresAt'] as Timestamp,
      isOnHour: json['isOnHour'] ?? true,
      bookingDateTime: json['bookingDateTime'] as Timestamp?,
      status: json['status'] ?? 'pending',
      isRebook: json['isRebook'] ?? false,
      rebookTechnicianId: json['rebookTechnicianId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'newBookingId': newBookingId,
      'service': service.toJson(),
      'customer': customer.toJson(),
      'address': address.toJson(),
      'notes': notes,
      'issueImage': issueImage,
      'issueVideo': issueVideo,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'isOnHour': isOnHour,
      'bookingDateTime': bookingDateTime,
      'status': status,
      'isRebook': isRebook,
      'rebookTechnicianId': rebookTechnicianId,
    };
  }
}

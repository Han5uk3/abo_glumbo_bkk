import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      titleEn: data['titleEn'] ?? '',
      titleAr: data['titleAr'] ?? '',
      bodyEn: data['bodyEn'] ?? '',
      bodyAr: data['bodyAr'] ?? '',
      data: data['data'] as Map<String, dynamic>? ?? {},
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleEn': titleEn,
      'titleAr': titleAr,
      'bodyEn': bodyEn,
      'bodyAr': bodyAr,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

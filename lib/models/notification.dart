import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String titleEn;
  final String titleAr;
  final String titleUr;
  final String bodyEn;
  final String bodyAr;
  final String bodyUr;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.titleUr,
    required this.bodyEn,
    required this.bodyAr,
    required this.bodyUr,
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
      titleUr: data['titleUr'] ?? '',
      bodyEn: data['bodyEn'] ?? '',
      bodyAr: data['bodyAr'] ?? '',
      bodyUr: data['bodyUr'] ?? '',
      data: data['data'] as Map<String, dynamic>? ?? {},
      read: data['read'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titleEn': titleEn,
      'titleAr': titleAr,
      'titleUr': titleUr,
      'bodyEn': bodyEn,
      'bodyAr': bodyAr,
      'bodyUr': bodyUr,
      'data': data,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

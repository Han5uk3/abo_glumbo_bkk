import 'package:cloud_firestore/cloud_firestore.dart';

class AllTipsModel {
  DateTime? createdAt;
  DateTime? updatedAt;
  String? paymentMethod;
  String? agentId;
  String? id;
  double? totalTipAmount;
  List<Map<String, dynamic>>? proofs;

  AllTipsModel({
    this.agentId,
    this.id,
    this.proofs,
    this.totalTipAmount,
    this.createdAt,
    this.updatedAt,
    this.paymentMethod,
  });

  factory AllTipsModel.fromJson(Map<String, dynamic> json) {
    return AllTipsModel(
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is Timestamp
                ? (json['createdAt'] as Timestamp).toDate()
                : json['createdAt'] as DateTime)
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp).toDate()
                : json['updatedAt'] as DateTime)
          : null,
      agentId: json['agentId'] as String?,
      id: json['id'] as String?,
      totalTipAmount: json['totalTipAmount'] != null
          ? (json['totalTipAmount'] is double
                ? json['totalTipAmount'] as double
                : (json['totalTipAmount'] as num).toDouble())
          : null,
      proofs: json['proofs'] != null
          ? List<Map<String, dynamic>>.from(json['proofs'])
          : null,
      paymentMethod: json['paymentMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentId': agentId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'id': id,
      'Amount': totalTipAmount,
      'proofs': proofs,
      'paymentMethod': paymentMethod,
    };
  }
}

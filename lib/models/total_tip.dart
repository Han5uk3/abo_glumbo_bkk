import 'package:cloud_firestore/cloud_firestore.dart';

class AllTipsModel {
  Timestamp? createdAt;
  Timestamp? updatedAt;
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
                ? (json['createdAt'] as Timestamp)
                : json['createdAt'] as Timestamp)
          : null,
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] is Timestamp
                ? (json['updatedAt'] as Timestamp)
                : json['updatedAt'] as Timestamp)
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
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'id': id,
      'Amount': totalTipAmount,
      'proofs': proofs,
      'paymentMethod': paymentMethod,
    };
  }
}

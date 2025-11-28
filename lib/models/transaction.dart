import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final double amount;
  final String customerId;
  final String workerId;
  final String paymentStatus;
  final String paymentMethod;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String bookingId;
  final String orderId;

  TransactionModel(
    this.updatedAt, {
    required this.amount,
    required this.customerId,
    required this.workerId,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    required this.orderId,
    required this.bookingId,
  });

  // Add any necessary methods for your transaction model

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'customerId': customerId,
      'workerId': workerId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'bookingId': bookingId,
      'orderId': orderId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      Timestamp.fromDate(map['updatedAt']),
      amount: map['amount'],
      bookingId: map['bookingId'],
      customerId: map['customerId'],
      workerId: map['workerId'],
      paymentStatus: map['paymentStatus'],
      paymentMethod: map['paymentMethod'],
      createdAt: Timestamp.fromDate(map['createdAt']),
      
      orderId: map['orderId'],
    );
  }

  @override
  String toString() {
    return 'TransactionModel{amount: $amount, paymentStatus: $paymentStatus, paymentMethod: $paymentMethod, createdAt: $createdAt, updatedAt: $updatedAt, orderId: $orderId, customerId: $customerId, workerId: $workerId, bookingId: $bookingId}';
  }
}

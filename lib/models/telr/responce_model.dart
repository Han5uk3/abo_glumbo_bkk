import 'package:flutter/material.dart';

class TelrPaymentResponse {
  final String? paymentUrl;
  final String? orderId;
  final String? errorMessage;
  final String? errorCode;
  final String? trace;
  final bool success;

  TelrPaymentResponse({
    this.paymentUrl,
    this.orderId,
    this.errorMessage,
    this.errorCode,
    this.trace,
    required this.success,
  });

  factory TelrPaymentResponse.fromJson(Map<String, dynamic> json) {
    debugPrint('Full Telr Response: $json'); // Debug log

    if (json['error'] != null) {
      final error = json['error'];
      return TelrPaymentResponse(
        success: false,
        errorMessage: error['message'] ?? 'Unknown error occurred',
        errorCode: error['code']?.toString(),
        trace: json['trace']?.toString(),
      );
    }

    if (json['order'] != null) {
      return TelrPaymentResponse(
        success: true,
        paymentUrl: json['order']['url'],
        orderId: json['order']['ref'],
        trace: json['trace']?.toString(),
      );
    }

    return TelrPaymentResponse(
      success: false,
      errorMessage: 'Invalid response format',
      trace: json['trace']?.toString(),
    );
  }
}

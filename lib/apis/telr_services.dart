import 'dart:convert';
import 'package:abo_glumbo_bbk/models/telr/request_model.dart';
import 'package:abo_glumbo_bbk/models/telr/responce_model.dart';
import 'package:http/http.dart' as http;

class TelrPaymentService {
  static const String _baseUrl = 'https://secure.telr.com/gateway/order.json';

  Future<TelrPaymentResponse> createPayment(TelrPaymentRequest request) async {
    try {
      // Validate request first
      final validationError = request.validate();
      if (validationError != null) {
        return TelrPaymentResponse(
          success: false,
          errorMessage: validationError,
        );
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Flutter-App/1.0',
        },
        body: request.toMap(),
      );

      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          return TelrPaymentResponse.fromJson(jsonResponse);
        } catch (e) {
          return TelrPaymentResponse(
            success: false,
            errorMessage: 'Failed to parse response: $e',
          );
        }
      } else {
        return TelrPaymentResponse(
          success: false,
          errorMessage: 'HTTP Error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      return TelrPaymentResponse(
        success: false,
        errorMessage: 'Network error: $e',
      );
    }
  }
}

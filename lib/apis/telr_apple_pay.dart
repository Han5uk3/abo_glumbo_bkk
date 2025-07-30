import 'dart:convert';
import 'package:http/http.dart' as http;

class ApplePayService {
  final String storeId;
  final String authKey;

  ApplePayService({required this.storeId, required this.authKey});

  Future<bool> sendApplePayTokenToTelr({
    required Map<String, dynamic> applePayToken,
    required double amount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      final fullName = customerName.split(" ");
      final firstName = fullName.first;
      final lastName = fullName.length > 1 ? fullName.last : '';

      final payload = {
        "store": storeId,
        "authkey": authKey,
        "tran": {
          "test": 1,
          "type": "auth",
          "class": "ecom",
          "cartid": orderId,
          "description": "Apple Pay Purchase",
          "currency": "SAR",
          "amount": amount.toStringAsFixed(2),
          "applepay": {"token": applePayToken["token"] ?? applePayToken}
        },
        "customer": {
          "name": {"first": firstName, "last": lastName},
          "email": customerEmail,
          "phone": {"country": "966", "number": customerPhone}
        }
      };

      final response = await http.post(
        Uri.parse('https://secure.telr.com/gateway/remote.json'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['order']?['status'] == 'A'; 
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}

// ignore_for_file: non_constant_identifier_names

class TelrPaymentRequest {
  final String ivp_method;
  final String ivp_store;
  final String ivp_authkey;
  final OrderData ivp_order;
  final String return_auth;
  final String return_can;
  final String return_decl;
  final String? ivp_lang;
  final String? bill_custref;
  final String? bill_fname;
  final String? bill_addr1;
  final String? bill_city;
  final String? bill_country;
  final String? bill_zip;
  final String? bill_email;
  final String? bill_phone;

  TelrPaymentRequest({
    this.ivp_method = 'create',
    required this.ivp_store,
    required this.ivp_authkey,
    required this.ivp_order,
    required this.return_auth,
    required this.return_can,
    required this.return_decl,
    this.ivp_lang,
    this.bill_custref,
    this.bill_fname,
    this.bill_addr1,
    this.bill_city,
    this.bill_country,
    this.bill_zip,
    this.bill_email,
    this.bill_phone,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ivp_method': ivp_method,
      'ivp_store': ivp_store,
      'ivp_authkey': ivp_authkey,
      'bill_custref': bill_custref ?? '',
      'return_auth': return_auth,
      'return_can': return_can,
      'return_decl': return_decl,
    };

    // Flatten order fields into the main map
    map.addAll(ivp_order.toMap());

    // Add optional fields only if they're not null and not empty
    if (ivp_lang != null && ivp_lang!.isNotEmpty) map['ivp_lang'] = ivp_lang!;
    if (bill_fname != null && bill_fname!.isNotEmpty) {
      map['bill_fname'] = bill_fname!;
    }
    if (bill_addr1 != null && bill_addr1!.isNotEmpty) {
      map['bill_addr1'] = bill_addr1!;
    }
    if (bill_city != null && bill_city!.isNotEmpty) {
      map['bill_city'] = bill_city!;
    }
    if (bill_country != null && bill_country!.isNotEmpty) {
      map['bill_country'] = bill_country!;
    }
    if (bill_zip != null && bill_zip!.isNotEmpty) map['bill_zip'] = bill_zip!;
    if (bill_email != null && bill_email!.isNotEmpty) {
      map['bill_email'] = bill_email!;
    }
    if (bill_phone != null && bill_phone!.isNotEmpty) {
      map['bill_phone'] = bill_phone!;
    }

    return map;
  }

  String? validate() {
    if (ivp_store.isEmpty) return 'Store ID is required';
    if (ivp_authkey.isEmpty) return 'Auth Key is required';
    if (ivp_order.ivp_amount.isEmpty ||
        double.tryParse(ivp_order.ivp_amount) == null) {
      return 'Valid amount is required';
    }
    if (ivp_order.ivp_cart.isEmpty) return 'Cart/Order ID is required';
    if (ivp_order.ivp_desc.isEmpty) return 'Description is required';
    if (bill_email != null &&
        bill_email!.isNotEmpty &&
        !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(bill_email!)) {
      return 'Valid email is required';
    }
    return null;
  }
}

class OrderData {
  final String ivp_test;
  final String ivp_cart;
  final String ivp_ref;
  final String ivp_amount;
  final String ivp_currency;
  final String ivp_desc;

  OrderData({
    this.ivp_currency = 'SAR',
    this.ivp_test = '1',
    required this.ivp_cart,
    required this.ivp_ref,
    required this.ivp_amount,
    required this.ivp_desc,
  });
  Map<String, String> toMap() {
    return {
      'ivp_test': ivp_test,
      'ivp_cart': ivp_cart,
      'ivp_ref': ivp_ref,
      'ivp_amount': ivp_amount,
      'ivp_currency': ivp_currency,
      'ivp_desc': ivp_desc,
    };
  }
}

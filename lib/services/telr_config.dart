class TelrConfig {
  static const String storeId = '31767';
  static const String authKey = 'TTGj@kqqms^7QVz2';
  //  'hSpz8-KLzZn~W5mp';
  // test ;

  // Test or live mode is read for each payment from app_settings/gateway
  // (AppSettingsService.resolveGatewayTestMode).
  static const String currency = 'SAR';
  static const String returnAuthUrl = 'https://yourapp.com/payment/success';
  static const String returnCanUrl = 'https://yourapp.com/payment/cancelled';
  static const String returnDeclUrl = 'https://yourapp.com/payment/declined';
  static bool get isConfigured {
    return storeId.isNotEmpty && authKey.isNotEmpty;
  }
}

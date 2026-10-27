import 'package:flutter/services.dart';

/// Helper class for country code detection and phone number formatting
class CountryCodeDetector {
  static const String saudiDialCode = '+966';

  static const Map<String, Map<String, dynamic>> countryMap = {
    'SA': {
      'code': '+966',
      'dialCode': '+966',
      'flag': '🇸🇦',
      'name': 'Saudi Arabia',
      'pattern': r'^(?:\+?966|0)?[0-9]{9}$',
      'localPattern': r'^(?:0)?(?:5|1)[0-9]{8}$',
    },
    'AE': {
      'code': '+971',
      'dialCode': '+971',
      'flag': '🇦🇪',
      'name': 'United Arab Emirates',
      'pattern': r'^(?:\+?971|0)?[0-9]{9}$',
      'localPattern': r'^(?:0)?(?:5|2|3|4|6|7|9)[0-9]{8}$',
    },
    'KW': {
      'code': '+965',
      'dialCode': '+965',
      'flag': '🇰🇼',
      'name': 'Kuwait',
      'pattern': r'^(?:\+?965)?[0-9]{8}$',
      'localPattern': r'^(?:0)?(?:4|5|6|9|2)[0-9]{7}$',
    },
    'QA': {
      'code': '+974',
      'dialCode': '+974',
      'flag': '🇶🇦',
      'name': 'Qatar',
      'pattern': r'^(?:\+?974)?[0-9]{8}$',
      'localPattern': r'^(?:0)?(?:3|5|6|7|4)[0-9]{7}$',
    },
    'OM': {
      'code': '+968',
      'dialCode': '+968',
      'flag': '🇴🇲',
      'name': 'Oman',
      'pattern': r'^(?:\+?968)?[0-9]{8}$',
      'localPattern': r'^(?:0)?(?:7|9|2)[0-9]{7}$',
    },
    'BH': {
      'code': '+973',
      'dialCode': '+973',
      'flag': '🇧🇭',
      'name': 'Bahrain',
      'pattern': r'^(?:\+?973)?[0-9]{8}$',
      'localPattern': r'^(?:0)?(?:3|6|1)[0-9]{7}$',
    },
    'EG': {
      'code': '+20',
      'dialCode': '+20',
      'flag': '🇪🇬',
      'name': 'Egypt',
      'pattern': r'^(?:\+?20|0)?[0-9]{10}$',
      'localPattern': r'^(?:0)?1[0-9]{9}$',
    },
  };

  /// Detect country code from phone number only when it starts with +
  /// Returns null if the number is in local format (starts with 0)
  /// This prevents false detection when user is typing local format numbers
  static Map<String, dynamic>? detectCountryFromPrefix(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;

    // Remove all non-digit characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Only detect if number clearly shows country code (starts with +)
    if (cleanNumber.startsWith('+')) {
      String code = cleanNumber.substring(1);
      // Try to match against known country codes
      for (var entry in countryMap.entries) {
        if (code.startsWith(
          entry.value['dialCode'].toString().replaceAll('+', ''),
        )) {
          return {'country': entry.key, ...entry.value};
        }
      }
    }

    // Return null for local format numbers (don't auto-detect)
    return null;
  }

  /// Detect country by matching phone number pattern
  /// Works with both local format (0512345678) and international format (+966512345678)
  static Map<String, dynamic>? detectCountryByPattern(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;

    // Remove all non-digit characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If already has + prefix, use standard detection
    if (cleanNumber.startsWith('+')) {
      String code = cleanNumber.substring(1);
      for (var entry in countryMap.entries) {
        if (code.startsWith(
          entry.value['dialCode'].toString().replaceAll('+', ''),
        )) {
          return {'country': entry.key, ...entry.value};
        }
      }
    }

    // For local format, try to match against country local patterns first
    for (var entry in countryMap.entries) {
      String? localPattern = entry.value['localPattern'];
      if (localPattern != null && RegExp(localPattern).hasMatch(cleanNumber)) {
        return {'country': entry.key, ...entry.value};
      }
    }

    // Fallback: If no local pattern matched, try the general pattern (less strict)
    for (var entry in countryMap.entries) {
      String? pattern = entry.value['pattern'];
      if (pattern != null && RegExp(pattern).hasMatch(cleanNumber)) {
        return {'country': entry.key, ...entry.value};
      }
    }

    // If no match found, return null
    return null;
  }

  /// Detect country code from phone number
  static Map<String, dynamic>? detectCountry(String phoneNumber) {
    if (phoneNumber.isEmpty) return null;

    // Remove all non-digit characters except +
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Check if number starts with + and extract country code
    if (cleanNumber.startsWith('+')) {
      String code = cleanNumber.substring(1);
      // Try to match against known country codes
      for (var entry in countryMap.entries) {
        if (code.startsWith(
          entry.value['dialCode'].toString().replaceAll('+', ''),
        )) {
          return {'country': entry.key, ...entry.value};
        }
      }
    }

    // If no + prefix, try to detect from the beginning of the number
    for (var entry in countryMap.entries) {
      String countryCode = entry.value['dialCode'].toString().replaceAll(
        '+',
        '',
      );
      if (cleanNumber.startsWith(countryCode)) {
        return {'country': entry.key, ...entry.value};
      }
    }

    // If no match found, return null
    return null;
  }

  /// Converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII digits.
  static String toAsciiDigits(String input) {
    return input.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (m) {
      final code = m[0]!.codeUnitAt(0);
      return (code >= 0x06F0 ? code - 0x06F0 : code - 0x0660).toString();
    });
  }

  /// Normalizes a Saudi phone number to E.164, for example "+966512312312".
  ///
  /// All of these give "+966512312312": "512312312", "0512312312",
  /// "966512312312", "00966512312312", "+966512312312" and "+966 0512312312",
  /// with or without spaces, dashes or brackets, and with Arabic or Persian
  /// digits. A doubled country code ("966966…") is removed too.
  ///
  /// A number with another country's code ("+971…" or "00971…") is returned
  /// as "+" plus its digits, so it isn't corrupted. Returns "" when there are
  /// no digits.
  static String normalizeSaudiPhone(String input) {
    final cleaned = toAsciiDigits(input).trim();
    var digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    final hasInternationalPrefix =
        cleaned.startsWith('+') || digits.startsWith('00');
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (hasInternationalPrefix && !digits.startsWith('966')) {
      return '+$digits';
    }

    // Drop the country code (repeated if it was added twice), but never from
    // a number that is already down to its 9 local digits.
    while (digits.startsWith('966') && digits.length > 9) {
      digits = digits.substring(3);
    }
    // Drop the leading "0" of the local format (0512312312).
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    return digits.isEmpty ? '' : '$saudiDialCode$digits';
  }

  /// Whether [input] is a Saudi number: +966 followed by exactly 9 digits
  /// once normalized.
  static bool isValidSaudiPhone(String input) {
    return RegExp(r'^\+966\d{9}$').hasMatch(normalizeSaudiPhone(input));
  }

  /// The 9 local digits of a Saudi number ("512312312"), for fields that
  /// show "+966" as a fixed prefix. Non-Saudi numbers are returned normalized.
  static String saudiLocalNumber(String input) {
    final normalized = normalizeSaudiPhone(input);
    return normalized.startsWith(saudiDialCode)
        ? normalized.substring(saudiDialCode.length)
        : normalized;
  }

  /// Format phone number with country code
  static String formatPhoneNumber(String phoneNumber, {String? countryCode}) {
    // Determine which country to use
    String country = countryCode ?? 'SA';
    if (country == 'SA' || !countryMap.containsKey(country)) {
      return normalizeSaudiPhone(phoneNumber);
    }

    String cleanNumber = toAsciiDigits(
      phoneNumber,
    ).replaceAll(RegExp(r'[^\d+]'), '');

    // If already has country code, return as is
    if (cleanNumber.startsWith('+')) {
      return cleanNumber;
    }

    String dialCode = countryMap[country]!['dialCode'];

    // Remove leading 0 if present
    if (cleanNumber.startsWith('0')) {
      cleanNumber = cleanNumber.substring(1);
    }

    return '$dialCode$cleanNumber';
  }

  /// Get all available countries
  static List<Map<String, dynamic>> getAvailableCountries() {
    return countryMap.entries
        .map((e) => {'country': e.key, ...e.value})
        .toList();
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phoneNumber, {String? countryCode}) {
    String country = countryCode ?? 'SA';
    String? pattern = countryMap[country]?['pattern'];

    if (pattern == null) return false;

    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    return RegExp(pattern).hasMatch(cleanNumber);
  }

  /// Convert local phone number format to international E.164 format for Firebase storage
  /// Handles input like "0512345678" (SA) and converts to "+966512345678"
  static String convertToFirebaseFormat(
    String phoneNumber, {
    String? countryCode,
  }) {
    if (phoneNumber.isEmpty) return phoneNumber;

    // First, format with country code
    String formatted = formatPhoneNumber(phoneNumber, countryCode: countryCode);
    if (formatted.isEmpty) return formatted;

    // Ensure it starts with +
    if (!formatted.startsWith('+')) {
      String country = countryCode ?? 'SA';
      String dialCode = countryMap[country]?['dialCode'] ?? '+966';
      formatted = '$dialCode$formatted';
    }

    return formatted;
  }
}

/// Input formatter for phone fields: turns Arabic and Persian digits into
/// ASCII digits and keeps only digits, plus "+" as the first character, so
/// "+966…", "00966…", "966…" and "05…" can all be typed or pasted.
class PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final ascii = CountryCodeDetector.toAsciiDigits(newValue.text);
    final buffer = StringBuffer();
    for (var i = 0; i < ascii.length; i++) {
      final ch = ascii[i];
      final isDigit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
      if (isDigit || (ch == '+' && buffer.isEmpty)) buffer.write(ch);
    }
    final text = buffer.toString();
    if (text == newValue.text) return newValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

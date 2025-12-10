class SearchUtils {
  // Arabic to English character mapping for keyboard layouts
  static const Map<String, String> _arabicToEnglishMap = {
    'ض': 'q',
    'ص': 'w',
    'ث': 'e',
    'ق': 'r',
    'ف': 't',
    'غ': 'y',
    'ع': 'u',
    'ه': 'i',
    'خ': 'o',
    'ح': 'p',
    'ش': 'a',
    'س': 's',
    'ي': 'd',
    'ب': 'f',
    'ل': 'g',
    'ا': 'h',
    'ت': 'j',
    'ن': 'k',
    'م': 'l',
    'ك': ';',
    'ظ': 'z',
    'ط': 'x',
    'ذ': 'c',
    'د': 'v',
    'ج': 'b',
    'ز': 'n',
    'و': 'm',
  };

  /// Normalize text by removing diacritics
  static String _removeDiacritics(String text) {
    // Remove Arabic diacritics
    text = text.replaceAll(RegExp(r'[\u064B-\u065F]'), '');
    // Use intl for general diacritics removal
    return text;
  }

  /// Convert Arabic characters to their potential English keyboard equivalents
  static String _arabicToEnglish(String text) {
    String result = text;
    _arabicToEnglishMap.forEach((arabic, english) {
      result = result.replaceAll(arabic, english);
    });
    return result;
  }

  /// Check if text contains Arabic characters
  static bool _hasArabic(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text);
  }

  /// Perform bidirectional search (search in both Arabic and English)
  static bool matchesSearchQuery(String text, String query) {
    if (query.isEmpty) return true;

    final normalizedText = _removeDiacritics(text).toLowerCase();
    final normalizedQuery = _removeDiacritics(query).toLowerCase();

    // Direct match in normalized text
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // If query has Arabic, try converting to English equivalents
    if (_hasArabic(normalizedQuery)) {
      final englishQuery = _arabicToEnglish(normalizedQuery);
      if (normalizedText.contains(englishQuery)) {
        return true;
      }
    }

    // If query is English, also try searching
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    return false;
  }

  /// Fuzzy search that works with both Arabic and English
  static bool fuzzyMatch(String text, String query) {
    final normalizedText = _removeDiacritics(text).toLowerCase();
    final normalizedQuery = _removeDiacritics(query).toLowerCase();

    // Try direct fuzzy match first
    if (_fuzzyMatchHelper(normalizedText, normalizedQuery)) {
      return true;
    }

    // If query has Arabic, try converting
    if (_hasArabic(normalizedQuery)) {
      final englishQuery = _arabicToEnglish(normalizedQuery);
      if (_fuzzyMatchHelper(normalizedText, englishQuery)) {
        return true;
      }
    }

    return false;
  }

  static bool _fuzzyMatchHelper(String text, String query) {
    int searchIndex = 0;
    for (int i = 0; i < text.length && searchIndex < query.length; i++) {
      if (text[i] == query[searchIndex]) {
        searchIndex++;
      }
    }
    return searchIndex == query.length;
  }
}

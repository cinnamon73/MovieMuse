class LanguageUtils {
  static const Map<String, String> _languageMap = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'th': 'Thai',
    'tr': 'Turkish',
    'pl': 'Polish',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'da': 'Danish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'is': 'Icelandic',
    'cs': 'Czech',
    'sk': 'Slovak',
    'hu': 'Hungarian',
    'ro': 'Romanian',
    'bg': 'Bulgarian',
    'hr': 'Croatian',
    'sr': 'Serbian',
    'sl': 'Slovenian',
    'et': 'Estonian',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'uk': 'Ukrainian',
    'be': 'Belarusian',
    'mk': 'Macedonian',
    'sq': 'Albanian',
    'mt': 'Maltese',
    'ga': 'Irish',
    'cy': 'Welsh',
    'eu': 'Basque',
    'ca': 'Catalan',
    'gl': 'Galician',
    'he': 'Hebrew',
    'fa': 'Persian',
    'ur': 'Urdu',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'kn': 'Kannada',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'mr': 'Marathi',
    'ne': 'Nepali',
    'si': 'Sinhala',
    'my': 'Burmese',
    'km': 'Khmer',
    'lo': 'Lao',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'ms': 'Malay',
    'tl': 'Filipino',
    'sw': 'Swahili',
    'am': 'Amharic',
    'yo': 'Yoruba',
    'ig': 'Igbo',
    'ha': 'Hausa',
    'zu': 'Zulu',
    'af': 'Afrikaans',
    'xh': 'Xhosa',
    'st': 'Southern Sotho',
    'tn': 'Tswana',
    'ss': 'Swazi',
    've': 'Venda',
    'ts': 'Tsonga',
    'nr': 'Southern Ndebele',
    'nso': 'Northern Sotho',
    'nd': 'Northern Ndebele',
  };

  /// Converts a language code to its full name
  /// Returns the full language name if found, otherwise returns the uppercase code
  static String getFullLanguageName(String languageCode) {
    return _languageMap[languageCode.toLowerCase()] ?? languageCode.toUpperCase();
  }

  /// Gets all available language codes
  static List<String> getAllLanguageCodes() {
    return _languageMap.keys.toList();
  }

  /// Gets all available language names
  static List<String> getAllLanguageNames() {
    return _languageMap.values.toList();
  }

  /// Checks if a language code is supported
  static bool isLanguageSupported(String languageCode) {
    return _languageMap.containsKey(languageCode.toLowerCase());
  }
} 
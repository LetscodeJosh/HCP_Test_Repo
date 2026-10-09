/// Enterprise Data Sanitizer for HCP Profiling & SFE Territory Reconfiguration.
///
/// Ensures all data sent to ERPNext, stored in local models, or exported to CSV/Excel
/// is strictly Clean, Trimmed, and Properly formatted (Clean, Trim, Proper) so external
/// SFE processes, VLOOKUPs, pivot tables, and ERPNext data exports run error-free.
class DataSanitizer {
  // Known acronyms and Roman numerals that should stay uppercase
  static final Set<String> _uppercaseTokens = {
    'MD', 'PRC', 'ENT', 'PIMS', 'SFE', 'NCR', 'BGC', 'PGH', 'UST', 'UERM',
    'DOH', 'FDA', 'HIV', 'ER', 'ICU', 'ADC', 'BAY', 'COR', 'EMP', 'HCP',
    'INST', 'TERR', 'ACC', 'SUB', 'WF', 'API', 'II', 'III', 'IV', 'V',
    'VI', 'VII', 'VIII', 'IX', 'X', 'JR', 'SR', 'OB-GYN', 'OB', 'GYN',
    'PSGC', 'R&D', 'HQ'
  };

  // Minor connecting words in locations and facilities to keep lowercase unless at start
  static final Set<String> _lowercaseConnectors = {
    'of', 'the', 'in', 'on', 'at', 'to', 'for', 'and'
  };

  /// Cleans a string of control characters, invisible whitespace, and collapses multiple spaces.
  /// Also trims leading and trailing whitespace.
  static String clean(String? input) {
    if (input == null) return '';
    
    // Replace non-breaking and zero-width spaces
    String text = input
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\t', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');

    // Collapse multiple consecutive spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Check for literal string representations of null or empty values
    final lower = text.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower == 'none' || lower == 'nil' || lower == 'n/a') {
      return '';
    }

    return text;
  }

  /// Trims leading and trailing whitespace after cleaning.
  static String trim(String? input) {
    return clean(input);
  }

  /// Converts a string into clean, proper Title Case.
  /// Handles compound names, hyphens, prefixes like Dr., St., De Los Santos, and preserves medical acronyms.
  static String properCase(String? input) {
    final text = clean(input);
    if (text.isEmpty) return '';

    // Split into tokens preserving hyphens, slashes, and periods
    final words = text.split(' ');
    final List<String> formattedWords = [];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;

      final upper = word.toUpperCase();
      if (_uppercaseTokens.contains(upper)) {
        formattedWords.add(upper);
        continue;
      }

      // Handle words with hyphens (e.g. OB-GYN, San-Juan)
      if (word.contains('-')) {
        final hyphenParts = word.split('-');
        final formattedParts = hyphenParts.map((p) => _formatSingleWord(p, i == 0)).toList();
        formattedWords.add(formattedParts.join('-'));
        continue;
      }

      // Handle words with slashes (e.g. N/A)
      if (word.contains('/')) {
        final slashParts = word.split('/');
        final formattedParts = slashParts.map((p) => _formatSingleWord(p, i == 0)).toList();
        formattedWords.add(formattedParts.join('/'));
        continue;
      }

      formattedWords.add(_formatSingleWord(word, i == 0));
    }

    return formattedWords.join(' ');
  }

  static String _formatSingleWord(String word, bool isFirstWord) {
    if (word.isEmpty) return '';

    final upper = word.toUpperCase();
    if (_uppercaseTokens.contains(upper)) {
      return upper;
    }

    final lower = word.toLowerCase();
    if (!isFirstWord && _lowercaseConnectors.contains(lower)) {
      return lower;
    }

    // Capitalize first character, lowercase the rest
    if (word.length == 1) {
      return word.toUpperCase();
    }

    // Preserve honorifics like St., Dr., Fr.
    if (word.endsWith('.') && word.length <= 4) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }

    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }

  /// Clean, Trim, and Proper Case combined.
  static String cleanTrimProper(String? input) {
    return properCase(input);
  }

  /// Clean, Trim, and UPPERCASE (for Territory codes, Record IDs, and Statuses).
  static String cleanTrimUpper(String? input) {
    final text = clean(input);
    return text.toUpperCase();
  }

  /// Clean, Trim, and lowercase (for email addresses and web identifiers).
  static String cleanTrimLower(String? input) {
    final text = clean(input);
    return text.toLowerCase();
  }

  /// Cleans and formats phone numbers (digits and optional leading +).
  static String cleanPhone(String? input) {
    final text = clean(input);
    if (text.isEmpty) return '';

    final hasPlus = text.startsWith('+');
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) return '';

    return hasPlus ? '+$digitsOnly' : digitsOnly;
  }

  /// Recursively sanitizes a JSON payload map before transmitting to ERPNext.
  static Map<String, dynamic> sanitizePayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> result = {};

    payload.forEach((key, value) {
      if (value is String) {
        final k = key.toLowerCase();
        if (k.contains('name') || k.contains('middle')) {
          result[key] = cleanTrimProper(value);
        } else if (k.contains('code') || k.contains('territory') || k.contains('status') || k.contains('prc') ||
            k == 'id' || k.endsWith('_id') || k.startsWith('id_') || k.contains('_id_')) {
          result[key] = cleanTrimUpper(value);
        } else if (k.contains('email')) {
          result[key] = cleanTrimLower(value);
        } else if (k.contains('phone') || k.contains('mobile') || k.contains('contact_number')) {
          result[key] = cleanPhone(value);
        } else if (k.contains('date') || k.contains('time')) {
          result[key] = trim(value);
        } else {
          result[key] = cleanTrimProper(value);
        }
      } else if (value is Map<String, dynamic>) {
        result[key] = sanitizePayload(value);
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return sanitizePayload(item);
          } else if (item is String) {
            return cleanTrimProper(item);
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    });

    return result;
  }
}

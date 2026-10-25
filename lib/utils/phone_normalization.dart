import 'package:flutter/services.dart';

/// Normalizes a Lebanese phone number to a bare local-subscriber form so the
/// same person's number always matches for debtor de-duplication, e.g.
/// "70123456", "70 123 456", "+961 70 123 456" and "00961 70 123 456" all
/// normalize to "70123456".
///
/// Returns an empty string if [raw] has no digits at all.
String normalizeLebanesePhone(String raw) {
  final digitsOnly = raw.replaceAll(RegExp(r'\D'), '');
  if (digitsOnly.isEmpty) {
    return '';
  }

  var normalized = digitsOnly;
  if (normalized.startsWith('00961')) {
    normalized = normalized.substring(5);
  } else if (normalized.startsWith('961') && normalized.length > 8) {
    normalized = normalized.substring(3);
  }

  // Local dialing sometimes prefixes a trunk "0" (e.g. old "03 xxx xxx"
  // landline-style mobile dialing) — strip exactly one leading zero once
  // any country code has already been removed above.
  if (normalized.length == 9 && normalized.startsWith('0')) {
    normalized = normalized.substring(1);
  }

  return normalized;
}

/// Formats a phone number without adding a country code the user did not
/// enter. An explicitly entered Lebanese code is retained.
String formatLebanesePhoneDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return '';
  }

  var localDigits = digits;
  var prefix = '';
  if (digits.startsWith('00961') && digits.length > 5) {
    prefix = '+961 ';
    localDigits = digits.substring(5);
  } else if (digits.startsWith('961') && digits.length > 8) {
    prefix = '+961 ';
    localDigits = digits.substring(3);
  }

  final buffer = StringBuffer(prefix);
  for (var i = 0; i < localDigits.length; i++) {
    if (i == 2 || i == 5) {
      buffer.write(' ');
    }
    buffer.write(localDigits[i]);
  }
  return buffer.toString();
}

/// Live-formats a phone field as the user types, so typing "76889816"
/// becomes "76 889 816" (see [formatLebanesePhoneDigits]).
///
/// Always collapses the cursor to the end after reformatting — editing a
/// phone number from the middle is rare enough that this simplification is
/// an acceptable trade-off for keeping the formatting logic straightforward.
class LebanesePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatLebanesePhoneDigits(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

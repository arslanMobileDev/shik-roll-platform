import 'package:flutter/services.dart';

/// Mask for the phone field: the `+7` prefix lives in the decoration,
/// the guest types 10 digits shown as `(XXX) XXX-XX-XX`.
final class PhoneInputFormatter extends TextInputFormatter {
  const PhoneInputFormatter();

  static const maxDigits = 10;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > maxDigits
        ? digits.substring(0, maxDigits)
        : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6 || i == 8) buffer.write('-');
      buffer.write(clipped[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// E.164 (`+7XXXXXXXXXX`) for the API, or null while the mask is incomplete.
String? e164FromMaskedPhone(String masked) {
  final digits = masked.replaceAll(RegExp(r'\D'), '');
  return digits.length == PhoneInputFormatter.maxDigits ? '+7$digits' : null;
}

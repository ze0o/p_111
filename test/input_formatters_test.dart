import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:car_insurance_app/shared/utils/input_formatters.dart';

TextEditingValue _format(TextInputFormatter formatter, String input) {
  return formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(text: input),
  );
}

void main() {
  group('CardNumberFormatter', () {
    final formatter = CardNumberFormatter();

    test('groups digits in blocks of four', () {
      expect(_format(formatter, '4242424242424242').text, '4242 4242 4242 4242');
    });

    test('does not add a trailing space', () {
      expect(_format(formatter, '42424242').text, '4242 4242');
    });

    test('places the cursor at the end', () {
      final value = _format(formatter, '123456');
      expect(value.selection.baseOffset, value.text.length);
    });

    test('leaves empty input untouched', () {
      expect(_format(formatter, '').text, '');
    });
  });

  group('ExpiryDateFormatter', () {
    final formatter = ExpiryDateFormatter();

    test('inserts a slash after the month', () {
      expect(_format(formatter, '0427').text, '04/27');
    });

    test('does not add a slash before the year is typed', () {
      expect(_format(formatter, '04').text, '04');
    });
  });
}

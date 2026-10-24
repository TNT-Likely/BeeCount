import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = BeeDecimalInputFormatter();
  for (final (raw, expected) in [
    ('0.', '0.'),
    ('7.10000000', '7.10000000'),
    ('0。149123456789', '0.149123456789'),
    ('1．25', '1.25'),
    ('1.2.3', '1.2.3'),
    ('abc7.10', '7.10')
  ]) {
    test('提交数字草稿 $raw -> $expected，范围/多点校验仍由App负责', () {
      final result = formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
              text: raw,
              selection: TextSelection.collapsed(offset: raw.length)));
      expect(result.text, expected);
      expect(result.selection.end, expected.length);
    });
  }
  test('IME组合态不截断或移动光标，提交后规范化为小数点', () {
    const preedit = TextEditingValue(
        text: '0。149',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5));
    expect(
        formatter.formatEditUpdate(TextEditingValue.empty, preedit), preedit);
    final committed = formatter.formatEditUpdate(
        preedit, preedit.copyWith(composing: TextRange.empty));
    expect(committed.text, '0.149');
    expect(committed.selection, preedit.selection);
    expect(committed.composing, TextRange.empty);
  });
}

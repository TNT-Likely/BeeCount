import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/ai/core/json_response_parser.dart';

void main() {
  // logger 用了 MethodChannel + SharedPreferences,需要先 mock
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('JsonResponseParser', () {
    const parser = JsonResponseParser();

    test('数组格式:N 笔正确解析', () {
      const raw = '[{"amount":-30,"time":"2026-05-26T12:00:00","category":"餐饮","type":"expense"},'
          '{"amount":-50,"time":"2026-05-26T18:00:00","note":"水果","type":"expense"}]';
      final bills = parser.parse(raw);
      expect(bills, hasLength(2));
      expect(bills[0].amount, -30);
      expect(bills[0].category, '餐饮');
      expect(bills[1].note, '水果');
    });

    test('单对象格式:1 笔(老用户自定义 prompt 兼容)', () {
      const raw = '{"amount":-30,"time":"2026-05-26T12:00:00","category":"餐饮"}';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -30);
    });

    test('Markdown ```json 包裹', () {
      const raw = '```json\n[{"amount":-30,"time":"2026-05-26T12:00:00"}]\n```';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -30);
    });

    test('Trailing comma 容错(JSON5 风格)', () {
      const raw = '[\n'
          '  {\n'
          '    "amount": -30,\n'
          '    "time": "2026-05-26T12:00:00",\n'
          '    "note": ""\n'
          ',\n'
          '  }\n'
          ']';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -30);
    });

    test('字符串字面量内的逗号保留', () {
      const raw = '[{"amount":-30,"time":"2026-05-26T12:00:00","note":"苹果, 香蕉"}]';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.note, '苹果, 香蕉');
    });

    test('时间字符串内嵌空格 → strip 后 parse', () {
      // 原样不可 parse,strip 后 "2026-05-26T12:00:00" 可 parse
      const raw = '[{"amount":-30,"time":"2026-05-26 T 12:00:00"}]';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.time?.year, 2026);
    });

    test('时间不可解析 → sanitize 兜底当前时间', () {
      const raw = '[{"amount":-30,"time":"2222 - 2 2 - 2 T 7:17"}]';
      final before = DateTime.now();
      final bills = parser.parse(raw);
      final after = DateTime.now();
      expect(bills, hasLength(1));
      expect(bills.first.time, isNotNull);
      // 兜底时间应在 [before, after] 范围内
      expect(
        bills.first.time!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        bills.first.time!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('amount 缺失 → 丢弃', () {
      const raw = '[{"time":"2026-05-26T12:00:00","note":"无金额"}]';
      final bills = parser.parse(raw);
      expect(bills, isEmpty);
    });

    test('amount 为 0 → 丢弃', () {
      const raw = '[{"amount":0,"time":"2026-05-26T12:00:00"}]';
      final bills = parser.parse(raw);
      expect(bills, isEmpty);
    });

    test('多笔中部分缺 amount → 过滤后保留有效', () {
      const raw = '['
          '{"amount":-30,"time":"2026-05-26T12:00:00"},'
          '{"note":"无金额项"},'
          '{"amount":0,"time":"2026-05-26T18:00:00"},'
          '{"amount":-40,"time":"2026-05-26T19:00:00"}'
          ']';
      final bills = parser.parse(raw);
      expect(bills, hasLength(2));
      expect(bills[0].amount, -30);
      expect(bills[1].amount, -40);
    });

    test('完全无 JSON → 空列表', () {
      const raw = '抱歉,我无法识别这条信息';
      final bills = parser.parse(raw);
      expect(bills, isEmpty);
    });

    test('空字符串 → 空列表', () {
      final bills = parser.parse('');
      expect(bills, isEmpty);
    });

    test('JSON 前后有解释文字 → 仍能提取', () {
      const raw = '好的,识别结果如下:[{"amount":-30,"time":"2026-05-26T12:00:00"}] 共 1 笔。';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -30);
    });

    test('数组中混入非对象项 → 跳过非对象,保留有效', () {
      const raw = '['
          '"乱字符串",'
          '{"amount":-30,"time":"2026-05-26T12:00:00"},'
          '42'
          ']';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -30);
    });

    test('AI 类型字段中英文兼容', () {
      const raw = '['
          '{"amount":-30,"time":"2026-05-26T12:00:00","type":"支出"},'
          '{"amount":100,"time":"2026-05-26T12:00:00","type":"INCOME"},'
          '{"amount":50,"time":"2026-05-26T12:00:00","type":"轉帳"}'
          ']';
      final bills = parser.parse(raw);
      expect(bills, hasLength(3));
      expect(bills[0].type, BillType.expense);
      expect(bills[1].type, BillType.income);
      expect(bills[2].type, BillType.transfer);
    });

    test('字符串金额 + 中文时间不再被跳过(回归 issue #297)', () {
      // issue #297 原始响应:qwen-vl-ocr 把 amount 输出成字符串、time 用中文,
      // 还带 ```json 包裹。旧实现 amount `as num?` 强转抛 CastError → 整笔被
      // 跳过、记账失败。
      const raw = '```json\n'
          '[\n'
          '    {\n'
          '        "amount": "-800.00",\n'
          '        "time": "2026年5月29日 23:35:16",\n'
          '        "note": "转账-xxxxx",\n'
          '        "category": "转账",\n'
          '        "type": "expense",\n'
          '        "tag": []\n'
          '    }\n'
          ']\n'
          '```';
      final bills = parser.parse(raw);
      expect(bills, hasLength(1));
      expect(bills.first.amount, -800.0);
      expect(bills.first.time, DateTime(2026, 5, 29, 23, 35, 16));
      expect(bills.first.category, '转账');
    });
  });
}

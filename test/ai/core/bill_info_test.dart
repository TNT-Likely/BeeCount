import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/core/bill_info.dart';

void main() {
  group('BillInfo.fromJson', () {
    test('完整字段', () {
      final bill = BillInfo.fromJson({
        'amount': -30.5,
        'time': '2026-05-26T12:00:00',
        'note': '星巴克',
        'category': '咖啡',
        'type': 'expense',
        'account': '支付宝',
      });
      expect(bill.amount, -30.5);
      expect(bill.time, DateTime.parse('2026-05-26T12:00:00'));
      expect(bill.note, '星巴克');
      expect(bill.category, '咖啡');
      expect(bill.type, BillType.expense);
      expect(bill.account, '支付宝');
    });

    test('time 内嵌空格自动 strip(strip 后仍是合法 ISO8601)', () {
      // 原样 parse 失败,strip 全部空白后变成 "2026-05-26T12:00:00",可 parse
      final bill = BillInfo.fromJson({
        'amount': -30,
        'time': '2026-05-26 T 12:00:00',
      });
      expect(bill.time, isNotNull);
      expect(bill.time?.year, 2026);
      expect(bill.time?.month, 5);
      expect(bill.time?.day, 26);
      expect(bill.time?.hour, 12);
    });

    test('time strip 后仍非法 → 返回 null(由下游 sanitize 兜底)', () {
      // "2222 2-1-26T18:08:00" → strip 后 "22222-1-26T18:08:00" 仍非法
      final bill = BillInfo.fromJson({
        'amount': -30,
        'time': '2222 2-1-26T18:08:00',
      });
      expect(bill.time, isNull);
    });

    test('time 非字符串 → null', () {
      final bill = BillInfo.fromJson({'amount': -30, 'time': 12345});
      expect(bill.time, isNull);
    });

    test('type 中英文兼容', () {
      expect(
        BillInfo.fromJson({'amount': -1, 'type': '收入'}).type,
        BillType.income,
      );
      expect(
        BillInfo.fromJson({'amount': -1, 'type': 'expense'}).type,
        BillType.expense,
      );
      expect(
        BillInfo.fromJson({'amount': -1, 'type': '轉帳'}).type,
        BillType.transfer,
      );
      expect(
        BillInfo.fromJson({'amount': -1, 'type': 'TRANSFER'}).type,
        BillType.transfer,
      );
    });

    test('tags 字符串和数组都支持', () {
      final fromString = BillInfo.fromJson({
        'amount': -1,
        'tags': '日用,饮料、咖啡',
      });
      expect(fromString.tags, ['日用', '饮料', '咖啡']);

      final fromArray = BillInfo.fromJson({
        'amount': -1,
        'tags': ['日用', '饮料', '咖啡'],
      });
      expect(fromArray.tags, ['日用', '饮料', '咖啡']);
    });

    test('tag (单数) 也支持', () {
      final bill = BillInfo.fromJson({'amount': -1, 'tag': '自用'});
      expect(bill.tags, ['自用']);
    });

    test('from_account / to_account camelCase 兼容', () {
      final fromSnake = BillInfo.fromJson({
        'amount': 100,
        'from_account': '建行',
        'to_account': '零钱',
      });
      expect(fromSnake.fromAccount, '建行');
      expect(fromSnake.toAccount, '零钱');

      final fromCamel = BillInfo.fromJson({
        'amount': 100,
        'fromAccount': '建行',
        'toAccount': '零钱',
      });
      expect(fromCamel.fromAccount, '建行');
      expect(fromCamel.toAccount, '零钱');
    });

    test('note 兼容老 merchant 字段', () {
      final bill = BillInfo.fromJson({'amount': -30, 'merchant': '星巴克'});
      expect(bill.note, '星巴克');
    });
  });

  group('BillInfo.copyWith', () {
    test('替换指定字段,其余沿用', () {
      const original = BillInfo(
        amount: -30,
        category: '餐饮',
        account: '支付宝',
        ledgerId: 1,
      );
      final updated = original.copyWith(
        category: '咖啡',
        ledgerId: 2,
      );
      expect(updated.amount, -30);
      expect(updated.category, '咖啡');
      expect(updated.account, '支付宝');
      expect(updated.ledgerId, 2);
    });

    test('不传任何参数 → 等价副本', () {
      const original = BillInfo(amount: -30, note: 'x');
      final copy = original.copyWith();
      expect(copy.amount, -30);
      expect(copy.note, 'x');
    });
  });

  group('BillInfo.toJson', () {
    test('字段双向 roundtrip', () {
      const bill = BillInfo(
        amount: -30,
        note: '星巴克',
        category: '咖啡',
        type: BillType.expense,
        account: '支付宝',
      );
      final json = bill.toJson();
      expect(json['amount'], -30);
      expect(json['type'], 'expense');
      final restored = BillInfo.fromJson(Map<String, dynamic>.from(json));
      expect(restored.amount, bill.amount);
      expect(restored.type, bill.type);
      expect(restored.category, bill.category);
    });
  });

  group('BillInfo.isComplete', () {
    test('amount + time 都有 → true', () {
      final bill = BillInfo(
        amount: -1,
        time: DateTime(2026, 5, 26),
      );
      expect(bill.isComplete, isTrue);
    });

    test('缺 amount → false', () {
      final bill = BillInfo(time: DateTime(2026, 5, 26));
      expect(bill.isComplete, isFalse);
    });

    test('缺 time → false', () {
      const bill = BillInfo(amount: -1);
      expect(bill.isComplete, isFalse);
    });
  });
}

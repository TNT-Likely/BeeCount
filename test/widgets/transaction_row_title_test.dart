import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/widgets/biz/transaction_row_title.dart';

void main() {
  group('composeTransactionRowTitle', () {
    test('category 模式(默认):分类为主,备注挂括号', () {
      final r = composeTransactionRowTitle(
          mode: 'category', categoryName: '餐饮', title: '午餐');
      expect(r.primary, '餐饮');
      expect(r.parenNote, '午餐');
    });

    test('category 模式:无备注只显示分类', () {
      final r = composeTransactionRowTitle(
          mode: 'category', categoryName: '餐饮', title: '');
      expect(r.primary, '餐饮');
      expect(r.parenNote, isNull);
    });

    test('category 模式:备注与分类同名时不挂括号', () {
      final r = composeTransactionRowTitle(
          mode: 'category', categoryName: '餐饮', title: '餐饮');
      expect(r.primary, '餐饮');
      expect(r.parenNote, isNull);
    });

    test('note 模式:有备注则只显示备注,无括号', () {
      final r = composeTransactionRowTitle(
          mode: 'note', categoryName: '餐饮', title: '午餐');
      expect(r.primary, '午餐');
      expect(r.parenNote, isNull);
    });

    test('note 模式:无备注退回显示分类名', () {
      final r = composeTransactionRowTitle(
          mode: 'note', categoryName: '餐饮', title: '');
      expect(r.primary, '餐饮');
      expect(r.parenNote, isNull);
    });

    test('转账/调整(categoryName==null):两种模式都只显示 title、无括号', () {
      for (final mode in ['category', 'note']) {
        final r = composeTransactionRowTitle(
            mode: mode, categoryName: null, title: '转账');
        expect(r.primary, '转账', reason: 'mode=$mode');
        expect(r.parenNote, isNull, reason: 'mode=$mode');
      }
    });

    test('未知 mode 兜底按 category', () {
      final r = composeTransactionRowTitle(
          mode: 'bogus', categoryName: '餐饮', title: '午餐');
      expect(r.primary, '餐饮');
      expect(r.parenNote, '午餐');
    });
  });
}

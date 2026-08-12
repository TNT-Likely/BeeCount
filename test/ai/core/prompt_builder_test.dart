import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/core/ai_extraction_context.dart';
import 'package:beecount/ai/core/prompt_builder.dart';
import 'package:beecount/utils/currency_aliases.dart';

void main() {
  group('PromptBuilder', () {
    const builder = PromptBuilder();

    test('注入分类列表替换 {{CATEGORIES}}', () {
      final ctx = AiExtractionContext(
        expenseCategories: const ['餐饮', '奶茶', '咖啡'],
        incomeCategories: const ['工资', '理财'],
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        ocrText: 'Y',
        now: DateTime(2026, 5, 26, 21, 30),
      );
      expect(out, contains('支出：餐饮、奶茶、咖啡'));
      expect(out, contains('收入：工资、理财'));
      expect(out, isNot(contains('{{CATEGORIES}}')));
    });

    test('注入账户列表替换 {{ACCOUNTS}}', () {
      final ctx = AiExtractionContext(
        accounts: const [
          (name: '支付宝', currency: 'CNY'),
          (name: '微信零钱', currency: 'CNY'),
          (name: '招行储蓄', currency: 'CNY'),
        ],
        ledgerCurrency: 'CNY',
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        ocrText: 'Y',
        now: DateTime(2026, 5, 26),
      );
      // 单币种账本:账户清单**不带**币种后缀,与加多币种之前逐字相同
      expect(out, contains('账户列表：支付宝、微信零钱、招行储蓄'));
    });

    // 智能记账多币种(.docs/multi-currency-ai)
    test('外币账户在清单里带币种后缀', () {
      final ctx = AiExtractionContext(
        accounts: const [
          (name: '微信', currency: 'CNY'),
          (name: 'Chase', currency: 'USD'),
        ],
        ledgerCurrency: 'CNY',
        availableCurrencies: const ['CNY', 'USD'],
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('账户列表：微信、Chase(USD)'));
    });

    test('单币种账本的币种提示只有一行主币种', () {
      final ctx = AiExtractionContext(
        accounts: const [(name: '微信', currency: 'CNY')],
        ledgerCurrency: 'CNY',
        availableCurrencies: const ['CNY'],
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('账本主币种：CNY'));
      expect(out, isNot(contains('已有外币账户')));
    });

    test('有外币账户时列出可用币种', () {
      final ctx = AiExtractionContext(
        accounts: const [(name: 'Chase', currency: 'USD')],
        ledgerCurrency: 'CNY',
        availableCurrencies: const ['CNY', 'USD'],
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('账本主币种：CNY；账本内已有外币账户：USD'));
    });

    test('默认模板含 currency 字段说明与外币示例', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('10. currency:'));
      // 多币种示例要覆盖多个币种:只给 JPY 一个样例时,实测「美元」会漏填
      expect(out, contains('"currency":"JPY"'));
      expect(out, contains('"currency":"USD"'));
      expect(out, contains('"currency":"EUR"'));
    });

    test('默认模板明令禁止填符号/中文名,并给出符号对应', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('不要填货币符号'));
      expect(out, contains('\$ → USD'));
    });

    // 「日元能识别、美元不行」的根因之一:只靠一句「填 ISO 代码」,模型对没有
    // 样例的币种会漏填。对照表从别名表运行时生成,prompt 与解析器同一份数据。
    group('币种对照表', () {
      test('常用币种都在表里,且只给一个规范名(不带繁体/口语变体)', () {
        final out = builder.build(
          context: AiExtractionContext.fallback,
          inputSource: 'X',
          now: DateTime(2026, 5, 26),
        );
        expect(out, contains('币种对照'));
        expect(out, contains('美元=USD'));
        expect(out, contains('日元=JPY'));
        expect(out, contains('欧元=EUR'));
        expect(out, contains('英镑=GBP'));
        expect(out, contains('港币=HKD'));
        expect(out, contains('泰铢=THB'));
        // 繁体变体只用于解析,不该出现在 prompt 里(白烧 token)
        expect(out, isNot(contains('歐元')));
        expect(out, isNot(contains('港幣')));
      });

      test('账本主币种自己不进对照表(相同就该省略字段)', () {
        final out = builder.build(
          context: const AiExtractionContext(
              ledgerCurrency: 'JPY', availableCurrencies: ['JPY']),
          inputSource: 'X',
          now: DateTime(2026, 5, 26),
        );
        expect(out, contains('账本主币种：JPY'));
        expect(out, isNot(contains('日元=JPY')));
      });

      test('账本在用的长尾币种也带上(哪怕不在常用列表里)', () {
        final out = builder.build(
          context: const AiExtractionContext(
              ledgerCurrency: 'CNY', availableCurrencies: ['CNY', 'KES']),
          inputSource: 'X',
          now: DateTime(2026, 5, 26),
        );
        // KES 没登记中文别名 → 只出 code
        expect(out, contains('KES'));
      });

      test('对照表里的每个中文名都能被解析器认回来(prompt 与解析不脱节)', () {
        final out = builder.build(
          context: AiExtractionContext.fallback,
          inputSource: 'X',
          now: DateTime(2026, 5, 26),
        );
        final line = out
            .split('\n')
            .firstWhere((l) => l.startsWith('币种对照'));
        final pairs = line.split('：').last.split('、');
        for (final pair in pairs) {
          if (!pair.contains('=')) continue; // 纯 code 项
          final parts = pair.split('=');
          expect(currencyCodeFromAlias(parts[0]), parts[1],
              reason: 'prompt 教 AI 写「${parts[0]}」,解析器却认不出');
        }
      });
    });

    test('「插入币种段落」补丁与默认模板共用同一份字段说明(防漂移)', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      // 补丁 = 字段说明 + {{CURRENCIES}};字段说明部分必须逐字出现在默认模板里
      final spec =
          PromptBuilder.currencySectionSnippet.replaceAll('\n{{CURRENCIES}}', '');
      expect(out, contains(spec));
    });

    test('A7 回归锁:自定义模板不含 {{CURRENCIES}} → 不注入币种段落', () {
      final ctx = AiExtractionContext(
        accounts: const [(name: 'Chase', currency: 'USD')],
        ledgerCurrency: 'CNY',
        availableCurrencies: const ['CNY', 'USD'],
        customPromptTemplate: 'CUSTOM: {{INPUT_SOURCE}} / {{CATEGORIES}}',
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        now: DateTime(2026, 5, 26),
      );
      expect(out, startsWith('CUSTOM: X'));
      expect(out, isNot(contains('账本主币种')));
      expect(out, isNot(contains('账户列表')));
    });

    test('空 context → 走 hardcoded fallback 分类', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'X',
        ocrText: 'Y',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('餐饮、交通、购物、娱乐、居家'));
      expect(out, contains('工资、理财、红包'));
      expect(out, isNot(contains('账户列表'))); // accounts 为空时不输出
    });

    test('自定义模板优先于默认模板', () {
      final ctx = AiExtractionContext(
        expenseCategories: const ['测试分类'],
        customPromptTemplate: 'CUSTOM: {{INPUT_SOURCE}} / {{CATEGORIES}}',
      );
      final out = builder.build(
        context: ctx,
        inputSource: '来源',
        ocrText: '',
        now: DateTime(2026, 5, 26),
      );
      expect(out, startsWith('CUSTOM:'));
      expect(out, contains('来源'));
      expect(out, contains('测试分类'));
    });

    test('time / date 占位符正确填充', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'X',
        ocrText: 'Y',
        now: DateTime(2026, 1, 9, 7, 5),
      );
      expect(out, contains('2026-01-09 07:05'));
      // 默认模板里也有 {{CURRENT_DATE}} 占位符,应该被填上
      expect(out, contains('2026-01-09T09:00:00'));
    });

    test('OCR_TEXT 嵌入', () {
      final out = builder.build(
        context: AiExtractionContext.fallback,
        inputSource: 'from this text',
        ocrText: '昨天午餐50元',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('from this text'));
      expect(out, contains('昨天午餐50元'));
    });

    test('空白自定义模板视为未配置,走默认', () {
      final ctx = AiExtractionContext(customPromptTemplate: '   \n\t  ');
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        ocrText: '',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('JSON数组'));
    });
  });
}

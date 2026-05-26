import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/core/ai_extraction_context.dart';
import 'package:beecount/ai/core/prompt_builder.dart';

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
        accounts: const ['支付宝', '微信零钱', '招行储蓄'],
      );
      final out = builder.build(
        context: ctx,
        inputSource: 'X',
        ocrText: 'Y',
        now: DateTime(2026, 5, 26),
      );
      expect(out, contains('账户列表：支付宝、微信零钱、招行储蓄'));
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

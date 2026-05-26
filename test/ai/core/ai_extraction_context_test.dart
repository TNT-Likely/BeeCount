import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/core/ai_extraction_context.dart';
import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('forLedger 返回的分类包含用户可用分类', () async {
    final ledgerId = await repo.createLedger(name: 'test');
    final catA = await repo.createCategory(
      name: '自定义餐饮',
      kind: 'expense',
    );
    final catB = await repo.createCategory(name: '副业收入', kind: 'income');

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: ledgerId,
    );

    expect(ctx.expenseCategories, contains('自定义餐饮'));
    expect(ctx.incomeCategories, contains('副业收入'));
    expect(catA, greaterThan(0));
    expect(catB, greaterThan(0));
  });

  test('forLedger 加载用户自定义 prompt 模板', () async {
    SharedPreferences.setMockInitialValues({
      AIConstants.keyAiCustomPrompt: '自定义模板内容',
    });
    final ledgerId = await repo.createLedger(name: 'test');

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: ledgerId,
    );

    expect(ctx.customPromptTemplate, '自定义模板内容');
  });

  test('空白自定义模板视为未配置', () async {
    SharedPreferences.setMockInitialValues({
      AIConstants.keyAiCustomPrompt: '   ',
    });
    final ledgerId = await repo.createLedger(name: 'test');

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: ledgerId,
    );

    expect(ctx.customPromptTemplate, isNull);
  });

  test('accounts 按账本币种过滤', () async {
    final cnyLedgerId = await repo.createLedger(name: '人民币', currency: 'CNY');
    await repo.createAccount(
      ledgerId: cnyLedgerId,
      name: '招行 CNY',
      currency: 'CNY',
    );
    await repo.createAccount(
      ledgerId: cnyLedgerId,
      name: 'PayPal USD',
      currency: 'USD',
    );

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: cnyLedgerId,
    );

    expect(ctx.accounts, contains('招行 CNY'));
    expect(ctx.accounts, isNot(contains('PayPal USD')));
  });

  test('AiExtractionContext.fallback 是常量,字段全空', () {
    const ctx = AiExtractionContext.fallback;
    expect(ctx.expenseCategories, isEmpty);
    expect(ctx.incomeCategories, isEmpty);
    expect(ctx.accounts, isEmpty);
    expect(ctx.customPromptTemplate, isNull);
  });
}

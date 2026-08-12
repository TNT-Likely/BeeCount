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

  // 智能记账多币种(.docs/multi-currency-ai A3):账户候选**不再**按账本本位币
  // 过滤 —— 过滤掉外币账户,AI 就永远匹配不到它们,「用我的美元卡付的」这类
  // 指令无解(#437)。改为全量喂给 AI 并标注币种,由 BillCreationService 按
  // 这笔的币种去匹配。
  test('accounts 包含外币账户,并带上各自币种', () async {
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

    final names = ctx.accounts.map((a) => a.name).toList();
    expect(names, contains('招行 CNY'));
    expect(names, contains('PayPal USD'));
    expect(
      ctx.accounts.firstWhere((a) => a.name == 'PayPal USD').currency,
      'USD',
    );
  });

  test('隐藏账户仍然被排除(#240 回归锁)', () async {
    final ledgerId = await repo.createLedger(name: '人民币', currency: 'CNY');
    final hiddenId = await repo.createAccount(
      ledgerId: ledgerId,
      name: '已隐藏',
      currency: 'CNY',
    );
    await repo.setAccountHidden(hiddenId, true);

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: ledgerId,
    );

    expect(ctx.accounts.map((a) => a.name), isNot(contains('已隐藏')));
  });

  test('ledgerCurrency / availableCurrencies 反映账本与账户币种', () async {
    final ledgerId = await repo.createLedger(name: '人民币', currency: 'CNY');
    await repo.createAccount(
      ledgerId: ledgerId,
      name: 'PayPal',
      currency: 'USD',
    );

    final ctx = await AiExtractionContext.forLedger(
      repository: repo,
      ledgerId: ledgerId,
    );

    expect(ctx.ledgerCurrency, 'CNY');
    expect(ctx.availableCurrencies, containsAll(<String>['CNY', 'USD']));
  });

  test('AiExtractionContext.fallback 是常量,字段全空', () {
    const ctx = AiExtractionContext.fallback;
    expect(ctx.expenseCategories, isEmpty);
    expect(ctx.incomeCategories, isEmpty);
    expect(ctx.accounts, isEmpty);
    expect(ctx.customPromptTemplate, isNull);
    expect(ctx.ledgerCurrency, 'CNY');
  });
}

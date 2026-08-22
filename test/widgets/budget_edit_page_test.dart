import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/budget/budget_edit_page.dart';
import 'package:beecount/providers/database_providers.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.into(db.ledgers).insert(
          LedgersCompanion.insert(name: '测试账本'),
        );
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '住房',
            kind: 'expense',
            syncId: const Value('cat-housing'),
          ),
        );
    await db.into(db.categories).insert(
          CategoriesCompanion.insert(
            name: '餐饮',
            kind: 'expense',
            syncId: const Value('cat-food'),
          ),
        );
  });

  tearDown(() async => db.close());

  Widget host() => ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const BudgetEditPage(isCategory: true),
        ),
      );

  Future<void> pumpUi(WidgetTester tester) async {
    // 页面头部可能存在持续主题动效，不能用 pumpAndSettle 等待动画归零。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('分类选择器不再列出已经设置预算的分类', (tester) async {
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('category'),
            categoryId: const Value(1),
            amount: 1000,
            syncId: const Value('budget-housing'),
          ),
        );

    await tester.pumpWidget(host());
    await pumpUi(tester);
    await tester.tap(find.text('请选择预算分类'));
    await pumpUi(tester);

    expect(find.text('住房'), findsNothing);
    expect(find.text('餐饮'), findsOneWidget);

    // 关闭弹窗，让 _selectCategory 的 Future 完整结束。
    await tester.tap(find.byIcon(Icons.close));
    await pumpUi(tester);
  });

  testWidgets('选择分类后若同步进同分类预算，保存时阻止重复创建', (tester) async {
    await tester.pumpWidget(host());
    await pumpUi(tester);
    await tester.tap(find.text('请选择预算分类'));
    await pumpUi(tester);
    await tester.tap(find.text('住房'));
    await pumpUi(tester);

    // 模拟选择器关闭后，另一设备同步进同分类预算。
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            ledgerId: 1,
            type: const Value('category'),
            categoryId: const Value(1),
            amount: 1000,
            syncId: const Value('budget-remote'),
          ),
        );

    await tester.enterText(find.byType(TextField).last, '2000');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('该分类已设置预算'), findsOneWidget);
    expect(await db.select(db.budgets).get(), hasLength(1));

    // showToastOnOverlay 的移除计时器。
    await tester.pump(const Duration(seconds: 3));
  });
}

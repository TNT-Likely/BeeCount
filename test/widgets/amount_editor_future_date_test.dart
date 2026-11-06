/// issue #581 —— 新建记账支持选择未来日期
///
///   - 记账编辑器日期选择器上界从「今天」放宽到「今天 + 1 年」(与日历页
///     calendar_page 的可浏览上界一致),覆盖季度房租分摊等未来预记账场景
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount/widgets/ui/wheel_date_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() async {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, 'L', 'CNY')");
  });

  tearDown(() async => db.close());

  Ledger cnyLedger() => Ledger(
        id: 1,
        name: 'L',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        myRole: 'owner',
        memberCount: 1,
        isShared: false,
        monthStartDay: 1,
      );

  /// 默认 800x600 测试视口装不下整个数字键盘,日期键可能不参与布局。
  /// 撑高到手机比例,让日期键稳定可点。
  void useTallPhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerProvider
            .overrideWith((ref) => Stream<Ledger?>.value(cnyLedger())),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: AmountEditorSheet(
            categoryName: '餐饮',
            initialDate: DateTime(2026, 7, 12),
            ledgerId: 1,
            onSubmit: (_) {},
          ),
        ),
      ),
    );
  }

  /// 边界比较看「同一个日历日」,不看 DateTime 实例相等
  /// (与 calendar_month_jump_test.dart 同一范式)
  Matcher sameCalendarDay(DateTime expected) => predicate<DateTime?>(
        (v) =>
            v != null &&
            v.year == expected.year &&
            v.month == expected.month &&
            v.day == expected.day,
        '与 ${expected.year}-${expected.month}-${expected.day} 同一日历日',
      );

  testWidgets('日期选择器上界放宽到「今天 + 1 年」,可选未来日期', (tester) async {
    useTallPhoneViewport(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // 点数字键盘上的日期键(initialDate=2026/7/12 → 文案 2026/7/12)
    await tester.tap(find.text('2026/7/12'));
    await tester.pumpAndSettle();

    expect(find.byType(WheelDatePicker), findsOneWidget);
    final picker = tester.widget<WheelDatePicker>(find.byType(WheelDatePicker));
    final now = DateTime.now();
    final expectedMax =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 365));
    // 改造前 maxDate=DateTime.now(),未来日期不可选
    expect(picker.maxDate, sameCalendarDay(expectedMax));
  });
}

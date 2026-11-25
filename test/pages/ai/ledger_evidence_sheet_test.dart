import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/ai/ai_chat_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ai_eval/support/ledger_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsZh();
  late LedgerEvalFixture fixture;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'ai_capability_binding_v2': '{}'});
    fixture = await LedgerEvalFixture.create();
  });
  tearDown(() => fixture.close());

  Future<void> openFromChat(
      WidgetTester tester, List<Map<String, Object?>> filters,
      {Brightness brightness = Brightness.light}) async {
    final ledgerId = fixture.ledgers['main']!;
    final queries = [
      for (final (index, filter) in filters.indexed)
        {
          'ref': 'answer/$index',
          'ledgerId': ledgerId,
          'tool': 'query_transactions',
          'filters': {
            'start': '2026-09-01',
            'end': '2026-10-01',
            'flowType': 'expense',
            ...filter,
          },
        },
    ];
    final conversation = await fixture.repository
        .createConversation(const ConversationsCompanion());
    await fixture.repository.createMessage(MessagesCompanion.insert(
        conversationId: conversation,
        role: 'assistant',
        content: '已核对',
        messageType: 'text',
        metadata: Value(jsonEncode({
          'contextLedgerId': ledgerId,
          'queryContext': {
            'displayRefs': queries.map((query) => query['ref']).toList(),
            'queries': queries,
          },
        }))));
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(fixture.database),
          repositoryProvider.overrideWithValue(fixture.repository),
          localAgentToolGatewayProvider.overrideWithValue(fixture.gateway),
          currentLedgerIdProvider.overrideWith((ref) => ledgerId),
        ],
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AIChatPage())));
    await tester.pumpAndSettle();
    final open = find.text(l.agentEvidenceBills);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  Finder sheetText(String part) => find.descendant(
      of: find.byType(BeeSheet).last, matching: find.textContaining(part));

  testWidgets('从聊天打开单个查询，紧凑深色弹层复用账单行并随隐私开关隐藏金额', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openFromChat(
        tester,
        [
          {
            'categoryNames': ['餐饮'],
            'minAmount': 42,
          },
        ],
        brightness: Brightness.dark);

    final sheet = find.byType(BeeSheet);
    expect(sheet, findsOneWidget);
    expect(Theme.of(tester.element(sheet)).brightness, Brightness.dark);
    expect(tester.getSize(sheet).height, lessThan(568 * .75));
    expect(sheetText(l.agentEvidenceCount(2)), findsOneWidget);
    expect(find.byType(CloseButton).hitTestable(), findsOneWidget);
    expect(sheetText('餐饮'), findsOneWidget);
    expect(find.byType(BeeSelectField<int>), findsNothing);
    final dates = MaterialLocalizations.of(tester.element(sheet));
    expect(sheetText(dates.formatCompactDate(DateTime(2026, 9, 30))),
        findsOneWidget);
    expect(sheetText(dates.formatCompactDate(DateTime(2026, 10, 1))),
        findsNothing);
    expect(sheetText('≥ 42'), findsOneWidget);

    final rows =
        tester.widgetList<BeeTransactionRow>(find.byType(BeeTransactionRow));
    expect(rows.map((row) => row.accountName), ['储蓄卡', '现金']);
    List<String> visibleAmounts() => tester
        .widgetList<Text>(find.byKey(const ValueKey('transaction-amount')))
        .map((text) => text.textSpan!.toPlainText())
        .toList();
    expect(visibleAmounts(), [endsWith('70.00'), endsWith('50.00')]);
    final scope = ProviderScope.containerOf(tester.element(sheet));
    scope.read(hideAmountsProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(visibleAmounts(), ['••••', '••••']);
    expect(sheetText('≥ ••••'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text(l.agentEvidenceBills), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('在已保存的查询之间切换会重新查账，也能展示零笔并返回有结果的范围', (tester) async {
    await openFromChat(tester, [
      {
        'categoryNames': ['午餐']
      },
      {
        'categoryNames': ['住房'],
        'minAmount': 9000
      },
    ]);
    expect(sheetText(l.agentEvidenceCount(1)), findsOneWidget);
    expect(
        tester
            .widget<BeeTransactionRow>(find.byType(BeeTransactionRow))
            .accountName,
        '储蓄卡');
    await tester.tap(find.byType(BeeSelectField<int>));
    await tester.pumpAndSettle();
    await tester.tap(sheetText('住房'));
    await tester.pumpAndSettle();
    expect(find.byType(BeeEmptyState), findsOneWidget);
    expect(find.byType(BeeTransactionRow), findsNothing);
    await tester.tap(find.byType(BeeSelectField<int>));
    await tester.pumpAndSettle();
    await tester.tap(sheetText('午餐'));
    await tester.pumpAndSettle();
    expect(sheetText(l.agentEvidenceCount(1)), findsOneWidget);
    expect(
        tester
            .widget<BeeTransactionRow>(find.byType(BeeTransactionRow))
            .accountName,
        '储蓄卡');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('较长的相关账单可翻页并返回首屏，匹配总数始终包括全部页', (tester) async {
    await openFromChat(tester, [
      {
        'categoryNames': ['购物'],
        'includeExcludedFromStats': false,
      },
    ]);
    final rowFinder = find.byType(BeeTransactionRow);
    Set<String?> notes() => tester
        .widgetList<BeeTransactionRow>(rowFinder)
        .map((row) => row.detailsNote)
        .toSet();
    Future<void> tapPage(String label) async {
      final control = sheetText(label);
      if (control.hitTestable().evaluate().isEmpty) {
        final scrolling = find.descendant(
            of: find.byType(BeeSheet),
            matching: find.byWidgetPredicate((widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down));
        await tester.dragUntilVisible(
            control.hitTestable(), scrolling.first, const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await tester.tap(control.hitTestable());
      await tester.pumpAndSettle();
    }

    expect(sheetText(l.agentEvidenceCount(27)), findsOneWidget);
    expect(notes(), contains('批量小额 25'));
    await tapPage('下一页');
    expect(sheetText(l.agentEvidenceCount(27)), findsOneWidget);
    expect(notes(), contains('批量小额 5'));
    expect(notes(), isNot(contains('批量小额 25')));
    await tapPage(l.agentEvidenceFirstPage);
    expect(sheetText(l.agentEvidenceCount(27)), findsOneWidget);
    expect(notes(), contains('批量小额 25'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

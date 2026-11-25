import 'dart:async';
import 'dart:convert';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/ai/chat/widgets/agent_empty_conversation.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsZh();
  late BeeDatabase database;
  late LocalRepository repo;
  late int ledger;

  void configure({bool enabled = true}) {
    SharedPreferences.setMockInitialValues({
      'ai_capability_binding_v2': '{"textProviderId":"zhipu_glm"}',
      'ai_providers_v2': jsonEncode([
        {
          'id': 'zhipu_glm',
          'name': 'Offline start screen fixture',
          'apiKey': enabled ? 'offline-test-only' : '',
          'baseUrl': 'https://offline.invalid',
          'textModel': 'offline-text',
        }
      ])
    });
  }

  setUp(() async {
    configure();
    database = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(database);
    ledger = await repo.createLedger(name: '手测账本', currency: 'CNY');
  });
  tearDown(() => database.close());

  Future<int> add(DateTime when, double amount,
          {int? ledgerId,
          String type = 'expense',
          double? localAmount,
          bool excluded = false}) =>
      database.into(database.transactions).insert(TransactionsCompanion.insert(
            ledgerId: ledgerId ?? ledger,
            type: type,
            amount: amount,
            happenedAt: Value(when),
            excludeFromStats: Value(excluded),
            nativeAmount: Value(localAmount),
            currencyCode: Value(localAmount == null ? null : 'USD'),
          ));

  Widget host(Widget body, {LocalRepository? repository}) => ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          repositoryProvider.overrideWithValue(repository ?? repo),
          currentLedgerIdProvider.overrideWith((_) => ledger),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            darkTheme: beeTheme(brightness: Brightness.dark),
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(body: body)),
      );

  Map<String, Object?> insights(DateTime start, DateTime end) => {
        'source': 'insights',
        'ledgerId': ledger,
        'scope': 'month',
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };

  testWidgets('历史洞察的首屏按当天汇总本币支出，忽略转账、非统计项、范围外与其它账本；原地编辑会刷新', (tester) async {
    final second = await repo.createLedger(name: '另一账本');
    final view = insights(DateTime(2025, 2, 10), DateTime(2025, 2, 14));
    final edited = await add(DateTime(2025, 2, 10), 10);
    await add(DateTime(2025, 2, 12), 2, localAmount: 16);
    await add(DateTime(2025, 2, 13), 10);
    await add(DateTime(2025, 2, 9), 11);
    await add(DateTime(2025, 2, 14), 12);
    await add(DateTime(2025, 2, 12), 13, excluded: true);
    await add(DateTime(2025, 2, 12), 14, type: 'income');
    await add(DateTime(2025, 2, 12), 15, type: 'transfer');
    await add(DateTime(2025, 2, 12), 16, ledgerId: second);
    await tester.pumpWidget(host(AgentEmptyConversation(view: view)));
    await tester.pumpAndSettle();
    final overview = find.byType(BeeConversationOverviewCard);
    BeeConversationOverviewCard card() => tester.widget(overview);
    expect(card().countLabel, l.aiChatStartExpenseCount(3));
    expect(card().points, [10, 10, 26, 36]);
    expect(find.text('¥36'), findsOneWidget);

    await (database.update(database.transactions)
          ..where((t) => t.id.equals(edited)))
        .write(const TransactionsCompanion(amount: Value(21)));
    await tester.pumpAndSettle();
    expect(card().points, [21, 21, 37, 47]);
    final container =
        ProviderScope.containerOf(tester.element(overview), listen: false);
    container.read(hideAmountsProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.text('****'), findsOneWidget);
    expect(card().showTrend, isFalse);
    container.read(currentLedgerIdProvider.notifier).state = second;
    await tester.pumpAndSettle();
    expect(card().countLabel, l.aiChatStartExpenseCount(0));
    expect(find.text(l.aiChatStartNoBills), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('从当前账本自定义月初至今天，零收入支出期与无流水账本有不同入口', (tester) async {
    await repo.updateLedger(id: ledger, monthStartDay: 10);
    final today = DateTime.now();
    final begin =
        DateTime(today.year, today.month - (today.day < 10 ? 1 : 0), 10);
    await tester.pumpWidget(host(const AgentEmptyConversation()));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartNoBills), findsOneWidget);
    await add(DateTime(begin.year, begin.month, begin.day - 1), 30);
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartExpenseCount(0)), findsOneWidget);
    await add(begin, 25);
    await add(DateTime(today.year, today.month, today.day + 1), 40);
    await tester.pumpAndSettle();
    final instance = tester.widget<BeeConversationOverviewCard>(
        find.byType(BeeConversationOverviewCard));
    expect(instance.countLabel, l.aiChatStartExpenseCount(1));
    expect(instance.points.first, 25);
    expect(instance.points.last, 25);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('复盘、轮换建议和快捷菜单共享历史账期；记账只打开草稿', (tester) async {
    final view = insights(DateTime(2025, 9, 1), DateTime(2025, 10, 1));
    await add(DateTime(2025, 9, 5), 19);
    final sent = <({String text, bool readOnly, bool review})>[];
    var drafts = 0;
    void ask(String text, {required bool readOnly, required bool review}) =>
        sent.add((text: text, readOnly: readOnly, review: review));
    void record() => drafts++;
    await tester.pumpWidget(host(Builder(
        builder: (context) => Column(children: [
              Expanded(
                  child: AgentEmptyConversation(
                      view: view, onPrompt: ask, onRecord: record)),
              TextButton(
                  onPressed: () => showAgentQuickActions(context,
                      view: view, onPrompt: ask, onRecord: record),
                  child: Text(l.aiChatStartQuickActions)),
            ]))));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
    await tester.tap(find.text(l.aiChatStartReview));
    expect(sent.single, (
      text: l.aiChatStartReviewPrompt('2025-09-01', '2025-09-30'),
      readOnly: true,
      review: true
    ));
    await tester.tap(find.text(l.aiChatStartFood));
    expect(sent.last.text, l.aiChatStartFoodPrompt('2025-09-01', '2025-09-30'));
    await tester.tap(find.text(l.aiChatStartRecord));
    expect(drafts, 1);
    await tester.tap(find.text(l.agentFollowUpRotate));
    await tester.pump();
    await tester.tap(find.text(l.aiChatStartShopping));
    expect(sent.last, (
      text: l.aiChatStartShoppingPrompt('2025-09-01', '2025-09-30'),
      readOnly: true,
      review: false
    ));
    await tester.tap(find.text(l.aiChatStartQuickActions));
    await tester.pumpAndSettle();
    final sheet = find.byType(BeeSheet);
    await tester.tap(
        find.descendant(of: sheet, matching: find.text(l.aiChatStartFood)));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(sent.last.text, sent[1].text);
    expect(sent.length, 4);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('320 像素深色大字首屏仍能读账期、复盘并滚动到建议', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.textScaleFactorTestValue = 1.45;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await add(DateTime(2025, 7, 8), 99999999.55);
    var calls = 0;
    await tester.pumpWidget(host(AgentEmptyConversation(
      view: insights(DateTime(2025, 7), DateTime(2025, 8)),
      onPrompt: (_, {required readOnly, required review}) => calls++,
    )));
    await tester.pumpAndSettle();
    final card = find.byType(BeeConversationOverviewCard);
    expect(Theme.of(tester.element(card)).brightness, Brightness.dark);
    expect(tester.widget<BeeConversationOverviewCard>(card).period,
        contains('7月1日'));
    await tester.tap(find.text(l.aiChatStartReview));
    await tester.ensureVisible(find.text(l.aiChatStartFood));
    await tester.tap(find.text(l.aiChatStartFood));
    expect(calls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('未绑定文本模型时提供设置入口；绑定恢复后才显示真实首笔引导', (tester) async {
    configure(enabled: false);
    int visits = 0;
    await tester.pumpWidget(
        host(AgentEmptyConversation(onConfigureModel: () => visits++)));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartNoModel), findsOneWidget);
    expect(find.text(l.aiChatStartNoBills), findsNothing);
    await tester.tap(find.text(l.aiChatStartModelSettings));
    expect(visits, 1);
    configure();
    final state = ProviderScope.containerOf(
        tester.element(find.byType(AgentEmptyConversation)),
        listen: false);
    state.invalidate(aiChatTextModelConfiguredProvider);
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartNoBills), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('本地读取待定、失败重试、恢复有账本摘要分开显示', (tester) async {
    final failing = _FirstReadFails(database);
    await add(DateTime.now(), 7);
    await tester
        .pumpWidget(host(const AgentEmptyConversation(), repository: failing));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartLoading), findsOneWidget);
    failing.first.completeError(StateError('offline local read failure'));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartLoadError), findsOneWidget);
    expect(find.text(l.aiChatStartNoBills), findsNothing);
    await tester.tap(find.text(l.helpCenterRetry));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatStartExpenseCount(1)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _FirstReadFails extends LocalRepository {
  _FirstReadFails(super.db);
  final first = Completer<List<Transaction>>();
  var reads = 0;

  @override
  Future<List<Transaction>> getTransactionsByLedgerInRange({
    required int ledgerId,
    required DateTime start,
    required DateTime end,
  }) =>
      reads++ == 0
          ? first.future
          : super.getTransactionsByLedgerInRange(
              ledgerId: ledgerId, start: start, end: end);
}

import 'dart:convert';

import 'package:beecount/cloud/recurring/cloud_recurring_rules.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/transaction/recurring/cloud_recurring_page.dart';
import 'package:beecount/pages/transaction/recurring/cloud_rule_editor.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/styles/header_skins.dart';
import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RuleBook extends CloudRuleBook {
  _RuleBook()
      : super(
            BeeCountCloudProvider(),
            Ledger(
                id: 1,
                name: 'QA ledger',
                currency: 'CNY',
                type: 'personal',
                createdAt: DateTime(2026),
                myRole: 'owner',
                memberCount: 1,
                isShared: false,
                monthStartDay: 1),
            'test',
            {
              'time_zone': 'Asia/Shanghai',
              'scheduler_enabled': true,
              'can_create': true,
              'items': <RuleJson>[],
              'accounts': <RuleJson>[],
              'categories': <RuleJson>[
                {'id': 'rent', 'name': 'Rent', 'kind': 'expense'}
              ],
            },
            false);

  final requests = <RuleJson>[];

  @override
  Future<RuleJson> change(RuleJson payload) async {
    requests.add(jsonDecode(jsonEncode(payload)) as RuleJson);
    return {
      'next_occurrences': ['2030-01-01T00:00:00+08:00'],
    };
  }
}

void main() {
  final l = AppLocalizationsEn();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Cloud list updates on its own and when returning to the app',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final book = _RuleBook();
    var reads = 0;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          displayHeaderSkinProvider.overrideWithValue(kHeaderSkinNone),
          headerSkinsEnabledProvider.overrideWithValue(false),
          cloudRuleBookProvider(1).overrideWith((ref) async {
            reads++;
            return book;
          }),
          pendingRecurringProvider(1).overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const CloudRecurringPage())));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.byType(RefreshIndicator), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(reads, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads, 3);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Future<void> open(WidgetTester tester, _RuleBook book,
      {CloudRule? row, RuleJson? draft}) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          displayHeaderSkinProvider.overrideWithValue(kHeaderSkinNone),
          headerSkinsEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
            navigatorKey: navigator,
            theme: beeTheme(),
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const Scaffold())));
    navigator.currentState!.push(MaterialPageRoute<bool>(
        builder: (_) => CloudRuleEditor(book: book, row: row, draft: draft)));
    await tester.pumpAndSettle();
    expect(
        find.byWidgetPredicate((widget) =>
            widget is TextField &&
            widget.decoration?.labelText == l.cloudRecurringName),
        findsNothing);
  }

  Future<void> enter(WidgetTester tester, String text,
      {bool note = false}) async {
    final form = tester
        .widget<BeeRecurringEditorForm>(find.byType(BeeRecurringEditorForm));
    final field = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        widget.controller ==
            (note ? form.noteController : form.amountController));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  Future<Finder> preview(WidgetTester tester) async {
    await tester.tap(find.text(l.commonSave));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final dialog = find.byType(BeeDialog);
    expect(dialog, findsOneWidget);
    return dialog;
  }

  Future<void> save(WidgetTester tester) async {
    final dialog = await preview(tester);
    await tester
        .tap(find.descendant(of: dialog, matching: find.text(l.commonSave)));
    await tester.pumpAndSettle();
    expect(find.byType(CloudRuleEditor), findsNothing);
  }

  testWidgets('create derives a name from the selected category',
      (tester) async {
    final book = _RuleBook();
    await open(tester, book);
    await enter(tester, '25');
    final category = find.byKey(const ValueKey('recurring-editor-category'));
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(book.requests.map((request) => request['confirm']), [false, true]);
    expect(book.requests.map((request) => request['data']['name']),
        ['Rent', 'Rent']);
  });

  testWidgets('reopened draft derives its latest title and keeps the full memo',
      (tester) async {
    final book = _RuleBook();
    await open(tester, book);
    await enter(tester, '25');
    final dialog = await preview(tester);
    expect(book.requests.single['data']['name'], l.categoryExpense);
    await tester
        .tap(find.descendant(of: dialog, matching: find.text(l.commonCancel)));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final key =
        prefs.getKeys().singleWhere((key) => key.startsWith(book.draftKey));
    final draft = jsonDecode(prefs.getString(key)!) as RuleJson;
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester, book, draft: draft);
    final memo = List.filled(260, '🐝').join();
    await enter(tester, '  $memo  ', note: true);
    await save(tester);

    final data = book.requests.last['data'] as RuleJson;
    expect(data['name'], List.filled(255, '🐝').join());
    expect(data['transaction']['note'], '  $memo  ');
  });

  testWidgets('edit preserves a saved Web title when changing the memo',
      (tester) async {
    final book = _RuleBook();
    final item = CloudRule({
      'id': 'saved-rule',
      'revision': 4,
      'status': 'active',
      'data': {
        'rule': {
          'name': 'Custom Web title',
          'transaction': {
            'tx_type': 'expense',
            'amount': 25,
            'note': 'Old memo'
          },
          'time_zone': 'Asia/Shanghai',
          'starts_at': '2030-01-01',
          'frequency': 'monthly',
          'interval': 1,
          'enabled': true,
        }
      }
    });
    await open(tester, book, row: item);
    await enter(tester, 'Updated memo', note: true);
    await save(tester);

    final request = book.requests.last;
    expect(request['action'], 'update');
    expect(request['expected_revision'], 4);
    expect(request['data']['name'], 'Custom Web title');
    expect(request['data']['transaction']['note'], 'Updated memo');
  });
}

// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';

import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/pages/account/account_edit_page.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/settings/automation_page.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/transaction/recurring_transaction_edit_page.dart';
import 'package:beecount/pages/transaction/recurring_transaction_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/statistics_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount_business_ui/recurring_editor.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runId = String.fromEnvironment('QA_RUN_ID');
const origin = String.fromEnvironment('QA_ORIGIN');
const email = String.fromEnvironment('QA_EMAIL');
const password = String.fromEnvironment('QA_PASSWORD');
const appId = String.fromEnvironment('QA_APP_ID');

Future<http.Response> request(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final uri = Uri.parse(origin).resolve(path);
  if (uri.origin != origin || uri.host != '127.0.0.1' || uri.scheme != 'http') {
    throw StateError('Refusing a request outside this QA Cloud');
  }
  final client = http.Client();
  try {
    final req = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json';
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    if (method == 'PATCH') {
      req.headers['Idempotency-Key'] =
          '$runId-${DateTime.now().microsecondsSinceEpoch}';
    }
    if (body != null) req.body = jsonEncode(body);
    return await http.Response.fromStream(await client.send(req))
        .timeout(const Duration(seconds: 30));
  } finally {
    client.close();
  }
}

Future<Map<String, dynamic>> api(
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? token,
}) async {
  final response = await request(method, path, body: body, token: token);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('QA API $method $path returned ${response.statusCode}');
  }
  return response.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(response.body) as Map<String, dynamic>;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {
    'run_id': runId,
    'scenario': 'recurring-consolidation',
    'cases': cases,
  };

  testWidgets(
      'recurring consolidation: cold-start catch-up, live preview, edit cursor preservation, hidden-account guard, and live Cloud round trip',
      (tester) async {
    final l = AppLocalizationsZh();
    final package = await PackageInfo.fromPlatform();
    expect(appId, 'com.tntlikely.beecount.qa');
    expect(
      package.packageName,
      appId,
      reason: 'Never run this target in a normal installed application',
    );
    expect(runId.startsWith('beecount-qa-'), isTrue);

    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], isTrue);

    await api('POST', '/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': runId,
    });

    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setBool('account_feature_enabled', true);
    await prefs.setBool('welcome_shown', true);
    await prefs.setString('noteDisplayMode', 'note');

    await CloudServiceStore().saveAndActivate(const CloudServiceConfig(
      type: CloudBackendType.beecountCloud,
      name: 'Isolated QA Cloud',
      beecountCloudBaseUrl: origin,
      beecountCloudEmail: email,
      beecountCloudPassword: password,
    ));

    final container = ProviderContainer();
    final runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final cloud = runtime.provider! as BeeCountCloudProvider;
    expect(cloud.baseUrl, origin);
    await cloud.auth.signInWithEmail(email: email, password: password);
    final engine = runtime.syncEngine!;
    final db = container.read(databaseProvider);
    final repo = container.read(repositoryProvider) as LocalRepository;

    final ledgerId = await repo.createLedger(name: 'QA 周期账单 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);

    final diningCatId = await repo.createCategory(
      name: 'QA 餐饮',
      kind: 'expense',
      icon: 'restaurant',
    );
    await repo.createCategory(
      name: 'QA 房租',
      kind: 'expense',
      icon: 'home',
    );
    final cmbAccountId = await repo.createAccount(
      ledgerId: ledgerId,
      name: 'QA 招商卡',
      type: 'bank_card',
      initialBalance: 10000,
    );
    final savingsAccountId = await repo.createAccount(
      ledgerId: ledgerId,
      name: 'QA 储蓄卡',
      type: 'bank_card',
      initialBalance: 5000,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Fixture 1 (#584): rule created earlier with a past target day in the
    // current period and never opened on that exact day (lastGeneratedDate=null).
    final bool useMonthlyPastDay = today.day >= 3;
    final DateTime expectedDate584 = useMonthlyPastDay
        ? DateTime(today.year, today.month, today.day - 1)
        : today;
    final rule584Id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 88.0,
      categoryId: diningCatId,
      accountId: cmbAccountId,
      note: 'QA 跨日补记584',
      frequency: useMonthlyPastDay ? 'monthly' : 'daily',
      interval: 1,
      dayOfMonth: useMonthlyPastDay ? today.day - 1 : null,
      startDate: useMonthlyPastDay
          ? DateTime(today.year, today.month, 1)
          : today.subtract(const Duration(days: 2)),
    );

    // Fixture 2 (#135): ancient 30-day-old ungenerated daily rule must generate
    // ONLY 1 transaction for today, never flooding 31 historical records.
    final rule135Id = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 15.0,
      categoryId: diningCatId,
      accountId: cmbAccountId,
      note: 'QA 远古防刷135',
      frequency: 'daily',
      interval: 1,
      startDate: today.subtract(const Duration(days: 30)),
    );

    // Fixture 3: paused due-today rule to exercise real Switch toggle-ON under 503.
    final pausedRuleId = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 33.0,
      categoryId: diningCatId,
      accountId: savingsAccountId,
      note: 'QA 断网开启补记',
      frequency: 'monthly',
      interval: 1,
      dayOfMonth: today.day,
      startDate: today,
      enabled: false,
    );

    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web',
    });
    final token = login['access_token'] as String;

    Future<Map<String, dynamic>> snapshot(String ledgerSyncId) async {
      final result = await api(
        'GET',
        '/api/v1/sync/full?ledger_id=$ledgerSyncId',
        token: token,
      );
      return jsonDecode(result['snapshot']['payload']['content'] as String)
          as Map<String, dynamic>;
    }

    List<Map<String, dynamic>> cloudItems(Map<String, dynamic> s) =>
        (s['items'] as List).cast<Map<String, dynamic>>();

    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});

    Future<void> waitUi(bool Function() ready, {String tag = 'ui'}) async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.takeScreenshot('failure-$tag');
      throw StateError('Production UI did not reach expected state ($tag)');
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await binding.takeScreenshot(name);
    }

    Future<void> captureDark(String name) async {
      final originalThemeMode = container.read(themeModeProvider);
      try {
        container.read(themeModeProvider.notifier).state = ThemeMode.dark;
        await capture(name);
      } finally {
        container.read(themeModeProvider.notifier).state = originalThemeMode;
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Finder homeRow(String note) => find.byWidgetPredicate(
          (w) => w is TransactionListItem && w.title == note,
          skipOffstage: false,
        );

    // -------------------------------------------------------------------------
    // R01: Boot real MainApp through SplashPage -> appSplashInitProvider
    // (NOT skipping splash), proving #584 catch-up, #135 anti-flood, and B4
    // activeCloudConfigProvider + ChangeTracker ordering on real startup!
    // -------------------------------------------------------------------------
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MainApp()),
    );
    await waitUi(
      () => find.byType(HomePage).evaluate().isNotEmpty,
      tag: 'splash-to-home',
    );
    await waitUi(
      () =>
          homeRow('QA 跨日补记584').evaluate().isNotEmpty &&
          homeRow('QA 远古防刷135').evaluate().isNotEmpty,
      tag: 'startup-rows',
    );

    final startupTxs = await db.select(db.transactions).get();
    expect(startupTxs, hasLength(2));
    var tx584 = startupTxs.singleWhere((t) => t.note == 'QA 跨日补记584');
    var tx135 = startupTxs.singleWhere((t) => t.note == 'QA 远古防刷135');
    expect(tx584.amount, 88.0);
    expect(tx584.recurringId, rule584Id);
    expect(tx584.happenedAt, expectedDate584);
    expect(tx135.amount, 15.0);
    expect(tx135.recurringId, rule135Id);
    expect(tx135.happenedAt, today);

    await sync();
    tx584 = (await repo.getTransactionById(tx584.id))!;
    tx135 = (await repo.getTransactionById(tx135.id))!;
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final ledgerSyncId = ledger.syncId!;
    final startupSnap = await snapshot(ledgerSyncId);
    final startupCloudTxs = cloudItems(startupSnap);
    expect(startupCloudTxs, hasLength(2));
    expect(
      startupCloudTxs.singleWhere((t) => t['syncId'] == tx584.syncId)['amount'],
      88.0,
    );
    expect(
      startupCloudTxs.singleWhere((t) => t['syncId'] == tx135.syncId)['amount'],
      15.0,
    );
    await capture('01-home-startup-catchup');
    pass(
      'R01',
      'Real SplashPage -> appSplashInitProvider caught up #584 past-target-day bill once, kept #135 30-day rule to 1 today bill, recorded local_changes after activeCloudConfigProvider, and synced both to BeeCount Cloud',
    );

    // -------------------------------------------------------------------------
    // R02: Navigate through real bottom tab 我的 -> 自动化 -> 周期记账, and create
    // a monthly 31st rule verifying the live 3-occurrence preview & month-end tag
    // -------------------------------------------------------------------------
    Future<void> tapText(String text, {bool last = true}) async {
      await waitUi(() => find.text(text).evaluate().isNotEmpty, tag: text);
      final target = last ? find.text(text).last : find.text(text).first;
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(target);
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tapText(l.tabMine);
    await waitUi(
      () => find.text(l.automation).evaluate().isNotEmpty,
      tag: 'mine-automation',
    );
    await tapText(l.automation);
    await waitUi(
      () => find.byType(AutomationPage).evaluate().isNotEmpty,
      tag: 'automation-page',
    );
    await tapText(l.mineRecurringTransactions);
    await waitUi(
      () => find.byType(RecurringTransactionPage).evaluate().isNotEmpty,
      tag: 'recurring-page',
    );

    Future<void> openAddEditor() async {
      final addBtn = find.byTooltip(l.recurringTransactionAdd);
      await waitUi(() => addBtn.evaluate().isNotEmpty, tag: 'add-btn');
      await tester.tap(addBtn.first);
      await waitUi(
        () =>
            find.byType(RecurringTransactionEditPage).evaluate().isNotEmpty &&
            find.byType(BeeRecurringEditorForm).evaluate().isNotEmpty,
        tag: 'editor-open',
      );
    }

    Future<void> enterEditorField(String keyName, String value) async {
      final field = find.descendant(
        of: find.byKey(ValueKey(keyName)),
        matching: find.byType(TextFormField),
      );
      await waitUi(() => field.evaluate().isNotEmpty, tag: keyName);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> pickEditorRow(BeeRecurringEditorField field) async {
      final finder = find.byKey(ValueKey('recurring-editor-${field.name}'));
      await waitUi(() => finder.evaluate().isNotEmpty, tag: field.name);
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<void> saveEditor() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 200));
      final btn = find.byKey(const ValueKey('recurring-editor-save'));
      await waitUi(() => btn.evaluate().isNotEmpty, tag: 'save-btn');
      await tester.tap(btn);
      await waitUi(
        () => find.byType(RecurringTransactionEditPage).evaluate().isEmpty,
        tag: 'editor-closed',
      );
    }

    await openAddEditor();
    await enterEditorField('recurring-editor-amount', '3200');
    await enterEditorField('recurring-editor-note', 'QA 月末31日房租');
    await pickEditorRow(BeeRecurringEditorField.category);
    await tapText('QA 房租');
    await pickEditorRow(BeeRecurringEditorField.account);
    await tapText('QA 储蓄卡');
    await pickEditorRow(BeeRecurringEditorField.dayOfMonth);
    await waitUi(
      () => find.byType(CupertinoPicker).evaluate().isNotEmpty,
      tag: 'day-wheel',
    );
    final dayPicker =
        tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    dayPicker.scrollController!.jumpToItem(30); // Day 31
    await tester.pump(const Duration(milliseconds: 400));
    await tapText(l.commonOk);

    final previewFinder =
        find.byKey(const ValueKey('recurring-editor-schedule-preview'));
    await tester.ensureVisible(previewFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l.v4RecurringPreviewTitle), findsOneWidget);
    expect(find.text(l.v4RecurringPreviewCount(3)), findsOneWidget);
    expect(find.textContaining('月末对齐'), findsWidgets);
    expect(find.text(l.v4RecurringPreviewMonthEndNote(31)), findsOneWidget);
    await capture('02-editor-month-end-preview');
    await captureDark('02b-editor-month-end-preview-dark');

    await saveEditor();
    expect(
      find.text(l.v4RecurringMonthlyOnDay(l.recurringTransactionMonthly, 31)),
      findsWidgets,
    );
    final rentRule = (await repo.getAllRecurringTransactions())
        .singleWhere((r) => r.note == 'QA 月末31日房租');
    expect(rentRule.dayOfMonth, 31);
    pass(
      'R02',
      'Navigated via real Mine -> Automation -> Recurring Bills, configured monthly day 31 in editor, verified live 3-occurrence schedule preview + month-end alignment badge/footnote, and saved',
    );

    // -------------------------------------------------------------------------
    // R03: Create due-today rule via real UI -> immediate generation on save
    // -------------------------------------------------------------------------
    await openAddEditor();
    expect(find.text(l.v4RecurringPreviewDueToday), findsOneWidget);
    await enterEditorField('recurring-editor-amount', '45');
    await enterEditorField('recurring-editor-note', 'QA 今日立即记账');
    await pickEditorRow(BeeRecurringEditorField.category);
    await tapText('QA 餐饮');
    await pickEditorRow(BeeRecurringEditorField.account);
    await tapText('QA 招商卡');
    await tester.ensureVisible(previewFinder);
    await tester.pump(const Duration(milliseconds: 300));
    await capture('03-editor-due-today-preview');

    await saveEditor();
    var dueTodayRule = (await repo.getAllRecurringTransactions())
        .singleWhere((r) => r.note == 'QA 今日立即记账');
    expect(dueTodayRule.startDate, today);
    expect(dueTodayRule.lastGeneratedDate, today);
    final dueTodayTxs = (await db.select(db.transactions).get())
        .where((t) => t.recurringId == dueTodayRule.id)
        .toList();
    expect(dueTodayTxs, hasLength(1));
    expect(dueTodayTxs.single.amount, 45.0);
    expect(dueTodayTxs.single.note, 'QA 今日立即记账');
    expect(dueTodayTxs.single.happenedAt, today);
    pass(
      'R03',
      'Due-today recurring rule normalized startDate to local midnight, previewed immediate run, and generated exact 1 transaction upon saving without waiting for next cold start',
    );

    // -------------------------------------------------------------------------
    // R04: Edit existing generated rule's amount/note via real UI -> preserves
    // lastGeneratedDate and creates ZERO duplicate transactions
    // -------------------------------------------------------------------------
    final dueCardFinder =
        find.byKey(ValueKey('recurring-rule-${dueTodayRule.id}'));
    await tester.scrollUntilVisible(
      dueCardFinder,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(dueCardFinder);
    await waitUi(
      () =>
          find.byType(RecurringTransactionEditPage).evaluate().isNotEmpty &&
          find.byType(BeeRecurringEditorForm).evaluate().isNotEmpty,
      tag: 'edit-due-rule',
    );
    expect(find.textContaining('已保留上次进度'), findsOneWidget);
    await enterEditorField('recurring-editor-amount', '49.50');
    await enterEditorField('recurring-editor-note', 'QA 编辑保留进度');
    await saveEditor();

    dueTodayRule = (await repo.getAllRecurringTransactions())
        .singleWhere((r) => r.id == dueTodayRule.id);
    expect(dueTodayRule.amount, 49.5);
    expect(dueTodayRule.note, 'QA 编辑保留进度');
    expect(
      dueTodayRule.lastGeneratedDate,
      today,
      reason: 'Editing amount/note must preserve lastGeneratedDate cursor',
    );
    expect(
      (await db.select(db.transactions).get())
          .where((t) => t.recurringId == dueTodayRule.id)
          .length,
      1,
    );
    pass(
      'R04',
      'Editing an already-generated recurring rule via UI preserved lastGeneratedDate and produced zero duplicate transactions',
    );

    // -------------------------------------------------------------------------
    // R05: Hide linked account via real AccountEditPage UI -> inline warning
    // banner & blocked status on RecurringTransactionPage; unhide -> recovers
    // -------------------------------------------------------------------------
    final rootNavigator = Navigator.of(
      tester.element(find.byType(RecurringTransactionPage).first),
    );
    final cmbBeforeHide = (await repo.getAccount(cmbAccountId))!;
    rootNavigator.push(
      MaterialPageRoute<bool>(
        builder: (_) =>
            AccountEditPage(account: cmbBeforeHide, ledgerId: ledgerId),
      ),
    );
    await waitUi(
      () => find.byType(AccountEditPage).evaluate().isNotEmpty,
      tag: 'account-edit-hide',
    );
    await tapText(l.accountHide);
    // Confirm dialog warns that active recurring bills use this account.
    await waitUi(
      () => find.text(l.accountHideConfirmTitle).evaluate().isNotEmpty,
      tag: 'account-hide-confirm',
    );
    await tapText(l.accountHide, last: true);
    await waitUi(
      () => find.byType(AccountEditPage).evaluate().isEmpty,
      tag: 'account-hide-done',
    );

    // Scroll to top of RecurringTransactionPage so warning cards are in frame.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 400));
    await waitUi(
      () => find
          .text(l.v4RecurringAccountHiddenWarning('QA 招商卡'))
          .evaluate()
          .isNotEmpty,
      tag: 'hidden-warning-visible',
    );
    expect(find.text(l.v4RecurringStatusBlocked), findsWidgets);
    await capture('04-bills-hidden-account-warning');

    final cmbHidden = (await repo.getAccount(cmbAccountId))!;
    expect(cmbHidden.hidden, isTrue);
    rootNavigator.push(
      MaterialPageRoute<bool>(
        builder: (_) => AccountEditPage(account: cmbHidden, ledgerId: ledgerId),
      ),
    );
    await waitUi(
      () => find.byType(AccountEditPage).evaluate().isNotEmpty,
      tag: 'account-edit-unhide',
    );
    await tapText(l.accountUnhide);
    await waitUi(
      () => find.byType(AccountEditPage).evaluate().isEmpty,
      tag: 'account-unhide-done',
    );
    await waitUi(
      () => find
          .text(l.v4RecurringAccountHiddenWarning('QA 招商卡'))
          .evaluate()
          .isEmpty,
      tag: 'hidden-warning-cleared',
    );
    expect(find.text(l.v4RecurringStatusBlocked), findsNothing);
    // Let the account-restored toast disappear before capturing card alignment.
    await tester.pump(const Duration(seconds: 3));
    await capture('05-bills-healthy-tracking');
    await captureDark('05b-bills-healthy-tracking-dark');
    pass(
      'R05',
      'Hiding a linked account via production AccountEditPage showed inline warning and blocked status on recurring cards; unhiding immediately restored healthy schedule status, captured in light and dark themes',
    );

    // -------------------------------------------------------------------------
    // R06: QA Cloud 503 outage simulation + real Switch toggle-ON immediate
    // generation + single-delivery recovery after Cloud comes back online
    // -------------------------------------------------------------------------
    await api('POST', '/__qa__/fault',
        body: {'run_id': runId, 'offline': true});
    try {
      final pausedCardFinder =
          find.byKey(ValueKey('recurring-rule-$pausedRuleId'));
      await tester.scrollUntilVisible(
        pausedCardFinder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 200));
      final pausedSwitch = find.descendant(
        of: pausedCardFinder,
        matching: find.byType(Switch),
      );
      await tester.tap(pausedSwitch);
      await tester.pump(const Duration(milliseconds: 600));
      await waitUi(
        () => tester.widget<Switch>(pausedSwitch).value == true,
        tag: 'paused-switch-on',
      );

      final offlineGenerated = (await db.select(db.transactions).get())
          .where((t) => t.recurringId == pausedRuleId)
          .toList();
      expect(offlineGenerated, hasLength(1));
      expect(offlineGenerated.single.note, 'QA 断网开启补记');
      expect(offlineGenerated.single.amount, 33.0);

      final failedSync = await engine.sync(ledgerId: ledgerId.toString());
      expect(failedSync.error, isNotNull);
    } finally {
      await api('POST', '/__qa__/fault',
          body: {'run_id': runId, 'offline': false});
    }

    await sync();
    await sync();
    var snapAfterRecovery = await snapshot(ledgerSyncId);
    final cloudAfterRecovery = cloudItems(snapAfterRecovery);
    expect(
      cloudAfterRecovery.where((t) => t['note'] == 'QA 断网开启补记').length,
      1,
    );
    pass(
      'R06',
      'QA Cloud 503 simulation: toggling a paused due-today rule ON immediately generated 1 local transaction and synchronized it exactly once after Cloud recovery',
    );

    // -------------------------------------------------------------------------
    // R07: Real Cloud web write API modification + pull back to App preserving
    // local recurringId and transaction count
    // -------------------------------------------------------------------------
    final full = await api(
      'GET',
      '/api/v1/sync/full?ledger_id=$ledgerSyncId',
      token: token,
    );
    await api(
      'PATCH',
      '/api/v1/write/ledgers/$ledgerSyncId/transactions/${tx584.syncId}',
      token: token,
      body: {
        'base_change_id': full['snapshot']['change_id'],
        'amount': 96.0,
        'native_amount': 96.0,
        'note': 'QA Cloud 周期核对后',
      },
    );
    await sync();

    final updatedTx584 = (await repo.getTransactionById(tx584.id))!;
    expect(updatedTx584.note, 'QA Cloud 周期核对后');
    expect(updatedTx584.amount, 96.0);
    expect(
      updatedTx584.recurringId,
      rule584Id,
      reason: 'Pulling a Cloud edit must preserve local recurringId relation',
    );

    final finalTxs = await db.select(db.transactions).get();
    // Wait: if today is NOT the 31st of a month, rentRule (day 31) is future, so
    // total generated transactions = 4 (rule584, rule135, dueTodayRule, pausedRule).
    // If today happens to be the 31st, rentRule also generated 1 bill -> 5.
    final expectedTxCount = today.day == 31 ? 5 : 4;
    expect(finalTxs, hasLength(expectedTxCount));

    // Return to HomePage for final visible verification & screenshot.
    rootNavigator.popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 600));
    await tapText(l.tabHome);
    container.read(statsRefreshProvider.notifier).state++;
    await waitUi(
      () =>
          homeRow('QA Cloud 周期核对后').evaluate().isNotEmpty &&
          homeRow('QA 今日立即记账').evaluate().isNotEmpty,
      tag: 'home-final-rows',
    );
    await capture('07-home-final-synced');
    pass(
      'R07',
      'Real Cloud web write API PATCH updated generated recurring bill to 96.0 ("QA Cloud 周期核对后"), pulled back into App HomePage, and preserved recurringId without duplication',
    );

    final finalRules = await repo.getAllRecurringTransactions();
    final finalCloudItems = cloudItems(await snapshot(ledgerSyncId));
    expect(finalCloudItems, hasLength(expectedTxCount));

    binding.reportData!.addAll({
      'ledger_sync_id': ledgerSyncId,
      'normal_ui_markers': ['QA Cloud 周期核对后', 'QA 今日立即记账'],
      'cloud_updated_tx_sync_id': tx584.syncId,
      'cloud_updated_recurring_id': rule584Id,
      'expected_tx_count': expectedTxCount,
      'final_rules': finalRules
          .map((r) => {
                'id': r.id,
                'note': r.note,
                'amount': r.amount,
                'frequency': r.frequency,
                'interval': r.interval,
                'day_of_month': r.dayOfMonth,
                'enabled': r.enabled,
                'start_date': r.startDate.toIso8601String(),
                'last_generated_date': r.lastGeneratedDate?.toIso8601String(),
              })
          .toList(),
      'final_transactions': finalCloudItems,
    });
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

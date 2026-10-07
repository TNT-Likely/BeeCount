// This target may only run in a verified QA bundle on a newly owned simulator.
import 'dart:convert';
import 'dart:io';

import 'package:beecount/app.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/statistics_providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount/widgets/biz/transaction_list.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const runId = String.fromEnvironment('QA_RUN_ID');
const origin = String.fromEnvironment('QA_ORIGIN');
const email = String.fromEnvironment('QA_EMAIL');
const password = String.fromEnvironment('QA_PASSWORD');
const appId = String.fromEnvironment('QA_APP_ID');
const copyLabel = '复制为新交易';

Future<Map<String, dynamic>> api(String method, String path,
    {Map<String, dynamic>? body, String? token}) async {
  final uri = Uri.parse(origin).resolve(path);
  if (uri.origin != origin || uri.host != '127.0.0.1' || uri.scheme != 'http') {
    throw StateError('Refusing a request outside this QA Cloud');
  }
  final client = http.Client();
  try {
    final request = http.Request(method, uri)
      ..followRedirects = false
      ..headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (method == 'PATCH') {
      request.headers['Idempotency-Key'] =
          '$runId-${DateTime.now().microsecondsSinceEpoch}';
    }
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('QA API $method $path returned ${response.statusCode}');
    }
    return response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {'run_id': runId, 'cases': cases};

  testWidgets('transaction copy: actual home UI and live Cloud round trip',
      (tester) async {
    final package = await PackageInfo.fromPlatform();
    expect(appId, 'com.tntlikely.beecount.qa');
    expect(package.packageName, appId,
        reason: 'Never run this target in a normal installed application');
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
    await prefs.setString('language', 'zh');
    await prefs.setBool('account_feature_enabled', true);
    await prefs.setBool('welcome_shown', true);
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
    final user =
        await cloud.auth.signInWithEmail(email: email, password: password);
    final engine = runtime.syncEngine!;
    final db = container.read(databaseProvider);
    final repo = container.read(repositoryProvider) as LocalRepository;
    final ledgerId = await repo.createLedger(name: 'QA copy $runId');
    final otherLedgerId =
        await repo.createLedger(name: 'QA other $runId', currency: 'USD');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final categoryId = await repo.createCategory(
        name: 'QA 餐饮', kind: 'expense', icon: 'restaurant');
    final incomeCategory = await repo.createCategory(
        name: 'QA 工资', kind: 'income', icon: 'wallet');
    final from = await repo.createAccount(
        ledgerId: ledgerId, name: 'QA 现金', initialBalance: 1000);
    final to = await repo.createAccount(
        ledgerId: ledgerId, name: 'QA 银行', initialBalance: 1000);
    final tagId = await repo.createTag(name: 'QA 工作日');
    final past = DateTime.now().subtract(const Duration(days: 2));
    final sourceId = await repo.addTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 32.1,
      categoryId: categoryId,
      accountId: from,
      happenedAt: past,
      note: 'QA 原交易',
      excludeFromStats: true,
      excludeFromBudget: true,
      currencyCode: 'CNY',
      nativeAmount: 32.1,
    );
    await repo.updateTransactionTags(transactionId: sourceId, tagIds: [tagId]);
    await (db.update(db.transactions)..where((t) => t.id.equals(sourceId)))
        .write(const TransactionsCompanion(recurringId: d.Value(77)));
    final image =
        File('${(await getTemporaryDirectory()).path}/qa-receipt.png');
    await image.writeAsBytes(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jF3sAAAAASUVORK5CYII='));
    await container.read(attachmentServiceProvider).saveAttachments(
        transactionId: sourceId, sourceFiles: [image], startIndex: 0);
    final baseline = (await repo.getTransactionById(sourceId))!;

    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 60));
      expect(result.error, isNull);
    }

    await sync();
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web',
    });
    final token = login['access_token'] as String;
    Future<Map<String, dynamic>> snapshot() async {
      final result = await api(
          'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
          token: token);
      return jsonDecode(result['snapshot']['payload']['content'] as String)
          as Map<String, dynamic>;
    }

    List<Map<String, dynamic>> transactions(Map<String, dynamic> s) =>
        (s['items'] as List).cast<Map<String, dynamic>>();
    final initialSnapshot = await snapshot();
    final cloudBaseline = transactions(initialSnapshot)
        .singleWhere((t) => t['syncId'] == baseline.syncId);

    Future<void> waitFor(bool Function() ready) async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      debugPrint(
          'QA UI timeout: ledger=${container.read(currentLedgerIdProvider)}, '
          'rows=${tester.widgetList<TransactionListItem>(find.byType(TransactionListItem, skipOffstage: false)).map((r) => r.title).toList()}, '
          'lists=${tester.widgetList<TransactionList>(find.byType(TransactionList)).map((l) => l.transactions?.map((t) => t.t.note).toList()).toList()}');
      await binding.takeScreenshot('failure-ui');
      throw StateError('UI did not reach expected state');
    }

    Future<void> host(
        {ThemeMode mode = ThemeMode.light,
        Locale locale = const Locale('zh')}) async {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: mode,
            home: const BeeApp(),
          )));
      await waitFor(() => find.byType(HomePage).evaluate().isNotEmpty);
      await tester.pump(const Duration(seconds: 1));
    }

    // flutter_list_view 1.x leaves debugVisitOnstageChildren empty. Traverse
    // its actual elements, then ensureVisible before sending a real gesture.
    Finder rowFor(String note) => find.byWidgetPredicate(
        (widget) => widget is TransactionListItem && widget.title == note,
        skipOffstage: false);

    Future<void> openCopy(String note, {String label = copyLabel}) async {
      // Route removal completes after its animation; allow the previous sheet
      // and editor barriers to leave before sending another pointer sequence.
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));
      await waitFor(() => rowFor(note).evaluate().isNotEmpty);
      final row = rowFor(note);
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      final position = tester.getTopLeft(row) + const Offset(100, 16);
      debugPrint('QA long press: $note at $position');
      await tester.longPressAt(position);
      await waitFor(() => find.text(label).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PopupMenuItem<String>), findsOneWidget);
      if (note == 'QA 原交易' && cases.isEmpty) {
        await binding.takeScreenshot('01-copy-menu');
      }
      await tester.tap(find.text(label));
      await waitFor(() => find.byType(AmountEditorSheet).evaluate().isNotEmpty);
      await tester.pump(const Duration(milliseconds: 500));
    }

    Future<Transaction> saveCopy(String note, {bool doubleTap = false}) async {
      final before = (await db.select(db.transactions).get()).length;
      await tester.enterText(find.byType(TextField).first, note);
      // Dismiss the keyboard before accessing the numeric submit key.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 500));
      final done = find.text('完成');
      expect(done, findsOneWidget);
      final position = tester.getCenter(done);
      await tester.tapAt(position);
      if (doubleTap) await tester.tapAt(position);
      await waitFor(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
      final rows = await db.select(db.transactions).get();
      expect(rows.length, before + 1);
      return rows.singleWhere((t) => t.note == note);
    }

    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});

    await host();
    await binding.takeScreenshot('00-initial-home');
    await openCopy('QA 原交易');
    final prefill =
        tester.widget<AmountEditorSheet>(find.byType(AmountEditorSheet));
    expect(prefill.editingTransactionId, isNull);
    expect(prefill.initialAmount, baseline.amount);
    expect(prefill.initialNote, baseline.note);
    expect(prefill.initialAccountId, from);
    expect(prefill.initialTagIds, [tagId]);
    final today = DateTime.now();
    expect(prefill.initialDate.year, today.year);
    expect(prefill.initialDate.month, today.month);
    expect(prefill.initialDate.day, today.day);
    expect(prefill.allowContinueAdding, isFalse);
    await binding.takeScreenshot('02-prefilled-new-transaction');
    // Close the sheet and then the category route without creating anything.
    final nav = Navigator.of(tester.element(find.byType(AmountEditorSheet)));
    nav.pop();
    await waitFor(() => find.byType(AmountEditorSheet).evaluate().isEmpty);
    nav.pop();
    await tester.pump(const Duration(milliseconds: 500));
    expect((await db.select(db.transactions).get()).length, 1);
    await sync();
    expect(transactions(await snapshot()).length, 1);
    pass('T02', 'Cancel does not create a local or remote transaction');

    await openCopy('QA 原交易');
    final copied = await saveCopy('QA 复制交易', doubleTap: true);
    expect(copied.id, isNot(sourceId));
    expect(copied.syncId, isNot(baseline.syncId));
    expect(copied.accountId, from);
    expect((await repo.getTagsForTransaction(copied.id)).map((t) => t.id),
        [tagId]);
    expect(copied.excludeFromStats, isTrue);
    expect(copied.excludeFromBudget, isTrue);
    expect(copied.createdByUserId, user.id);
    expect(copied.recurringId, isNull);
    expect(await repo.getAttachmentCountsForTransactions([sourceId, copied.id]),
        containsPair(sourceId, 1));
    expect(
        (await repo
                .getAttachmentCountsForTransactions([copied.id]))[copied.id] ??
            0,
        0);
    await sync();
    var remote = transactions(await snapshot());
    expect(remote.length, 2);
    expect(remote.singleWhere((t) => t['syncId'] == baseline.syncId),
        cloudBaseline);
    final remoteCopy = remote.singleWhere((t) => t['syncId'] == copied.syncId);
    expect(remoteCopy['amount'], copied.amount);
    expect(remoteCopy['excludeFromStats'], isTrue);
    expect(remoteCopy['excludeFromBudget'], isTrue);
    expect(remoteCopy['currencyCode'], 'CNY');
    expect(remoteCopy['nativeAmount'], 32.1);
    expect(remoteCopy['attachments'] ?? [], isEmpty);
    pass('T01',
        'Home long press, prefilled new editor, edited note, independent ID, real push');
    pass('T06',
        'Original receipt and recurring relation remain; copy inherits neither');
    await binding.takeScreenshot('03-original-and-copy');

    final full = await api(
        'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
        token: token);
    await api('PATCH',
        '/api/v1/write/ledgers/${ledger.syncId}/transactions/${copied.syncId}',
        token: token,
        body: {
          'base_change_id': full['snapshot']['change_id'],
          'amount': 55.5,
          'native_amount': 55.5,
          'note': 'QA Cloud 修改后'
        });
    await sync();
    expect((await repo.getTransactionById(copied.id))!.note, 'QA Cloud 修改后');
    expect((await repo.getTransactionById(copied.id))!.amount, 55.5);
    expect(
        transactions(await snapshot())
            .singleWhere((t) => t['syncId'] == baseline.syncId),
        cloudBaseline);
    container.read(statsRefreshProvider.notifier).state++;
    await waitFor(() => rowFor('QA Cloud 修改后').evaluate().isNotEmpty);
    await binding.takeScreenshot('04-cloud-change-pulled-back');
    pass('T09',
        'Real web write API update is pulled into App; original remains unchanged');
    await sync();
    await sync();
    expect(transactions(await snapshot()).length, 2);
    pass('T08', 'Double save and repeated synchronization produce one copy');

    for (final kind in ['income', 'transfer', 'expense']) {
      final name = kind == 'expense' ? 'QA 外币' : 'QA $kind';
      final foreign = kind == 'expense';
      final id = await repo.addTransaction(
        ledgerId: ledgerId,
        type: kind,
        amount: foreign ? 100 : 20,
        categoryId: kind == 'income' ? incomeCategory : categoryId,
        accountId: foreign ? null : from,
        toAccountId: kind == 'transfer' ? to : null,
        happenedAt: past,
        note: name,
        currencyCode: foreign ? 'JPY' : 'CNY',
        nativeAmount: foreign ? 5 : 20,
        excludeFromStats: kind == 'transfer',
        excludeFromBudget: foreign,
      );
      container.read(statsRefreshProvider.notifier).state++;
      final fromBalance = await repo.getAccountBalance(from);
      final toBalance = await repo.getAccountBalance(to);
      await openCopy(name);
      final clone = await saveCopy('$name 复制');
      expect(clone.type, kind);
      expect(clone.accountId, foreign ? null : from);
      expect(clone.toAccountId, kind == 'transfer' ? to : null);
      expect(clone.currencyCode, foreign ? 'JPY' : 'CNY');
      expect(clone.nativeAmount, foreign ? closeTo(5, 0.00001) : 20);
      expect(clone.excludeFromStats, kind == 'transfer');
      expect(clone.excludeFromBudget, foreign);
      if (kind == 'transfer') {
        expect(await repo.getAccountBalance(from),
            closeTo(fromBalance - 20, 0.00001));
        expect(
            await repo.getAccountBalance(to), closeTo(toBalance + 20, 0.00001));
      }
      await sync();
      final rows = transactions(await snapshot());
      expect(rows.where((t) => t['syncId'] == clone.syncId).length, 1);
      expect((await repo.getTransactionById(id))!.note, name);
      pass(
          kind == 'income'
              ? 'T03'
              : kind == 'transfer'
                  ? 'T04'
                  : 'T05',
          '$kind prefill, save and live synchronization');
    }

    // Switch the actual home page to a different ledger before copying.
    final otherSource = await repo.addTransaction(
      ledgerId: otherLedgerId,
      type: 'expense',
      amount: 7,
      categoryId: categoryId,
      happenedAt: past,
      note: 'QA 其他账本',
      currencyCode: 'USD',
      nativeAmount: 7,
    );
    container.read(currentLedgerIdProvider.notifier).state = otherLedgerId;
    container.read(statsRefreshProvider.notifier).state++;
    await openCopy('QA 其他账本');
    final otherCopy = await saveCopy('QA 其他账本复制');
    expect(otherCopy.ledgerId, otherLedgerId);
    expect(otherCopy.currencyCode, 'USD');
    expect(otherCopy.nativeAmount, 7);
    expect(container.read(currentLedgerIdProvider), otherLedgerId);
    expect((await repo.getTransactionById(otherSource))!.note, 'QA 其他账本');
    final otherResult = await engine.sync(ledgerId: otherLedgerId.toString());
    expect(otherResult.error, isNull);
    pass('T07',
        'Home ledger switch keeps source ledger, USD currency and homepage selection');

    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await api('POST', '/__qa__/fault',
        body: {'run_id': runId, 'offline': true});
    await openCopy('QA 原交易');
    final offlineCopy = await saveCopy('QA 离线复制');
    final failedSync = await engine.sync(ledgerId: ledgerId.toString());
    expect(failedSync.error, isNotNull);
    await api('POST', '/__qa__/fault',
        body: {'run_id': runId, 'offline': false});
    await sync();
    expect(
        transactions(await snapshot())
            .where((t) => t['syncId'] == offlineCopy.syncId)
            .length,
        1);
    pass('T10-offline',
        '503 Cloud outage: copy is saved locally, then synchronizes exactly once after recovery');

    // Owner and editor both belong to this new test database.
    final ownerEmail = 'owner-$email';
    final ownerRegistration = await api('POST', '/api/v1/auth/register', body: {
      'email': ownerEmail,
      'password': password,
      'client_type': 'web',
    });
    final ownerToken = ownerRegistration['access_token'] as String;
    final sharedExternal = 'shared-$runId';
    await api('POST', '/api/v1/write/ledgers', token: ownerToken, body: {
      'ledger_id': sharedExternal,
      'ledger_name': 'QA 共享账本',
      'currency': 'CNY',
    });
    final ownerCat = await api(
        'POST', '/api/v1/write/ledgers/$sharedExternal/categories',
        token: ownerToken,
        body: {'base_change_id': 0, 'name': 'QA Owner 分类', 'kind': 'expense'});
    final ownerAccount = await api(
        'POST', '/api/v1/write/ledgers/$sharedExternal/accounts',
        token: ownerToken,
        body: {
          'base_change_id': 0,
          'name': 'QA Owner 账户',
          'currency': 'CNY',
          'account_type': 'cash'
        });
    final ownerTag = await api(
        'POST', '/api/v1/write/ledgers/$sharedExternal/tags',
        token: ownerToken, body: {'base_change_id': 0, 'name': 'QA Owner 标签'});
    final ownerSource = await api(
        'POST', '/api/v1/write/ledgers/$sharedExternal/transactions',
        token: ownerToken,
        body: {
          'base_change_id': 0,
          'tx_type': 'expense',
          'amount': 18,
          'happened_at': past.toUtc().toIso8601String(),
          'note': 'QA Owner 原交易',
          'category_id': ownerCat['entity_id'],
          'account_id': ownerAccount['entity_id'],
          'tag_ids': [ownerTag['entity_id']],
          'currency_code': 'CNY',
          'native_amount': 18
        });
    final invite = await api('POST', '/api/v1/ledgers/$sharedExternal/invites',
        token: ownerToken, body: {'role': 'editor'});
    await api('POST', '/api/v1/invites/${invite['code']}/accept', token: token);
    await engine.syncLedgersFromServer();
    final sharedLedger = await (db.select(db.ledgers)
          ..where((l) => l.syncId.equals(sharedExternal)))
        .getSingle();
    expect(sharedLedger.isShared, isTrue);
    expect(sharedLedger.myRole, 'editor');
    final sharedResult =
        await engine.sync(ledgerId: sharedLedger.id.toString());
    expect(sharedResult.error, isNull);
    container.read(currentLedgerIdProvider.notifier).state = sharedLedger.id;
    container.read(statsRefreshProvider.notifier).state++;
    await openCopy('QA Owner 原交易');
    final sharedPrefill =
        tester.widget<AmountEditorSheet>(find.byType(AmountEditorSheet));
    expect(sharedPrefill.categoryId, lessThan(0));
    expect(sharedPrefill.initialAccountId, lessThan(0));
    expect(sharedPrefill.initialTagIds, hasLength(1));
    final sharedCopy = await saveCopy('QA Editor 复制');
    expect(sharedCopy.createdByUserId, user.id);
    expect(sharedCopy.categorySyncIdOverride, ownerCat['entity_id']);
    expect(sharedCopy.accountSyncIdOverride, ownerAccount['entity_id']);
    final sharedPush = await engine.sync(ledgerId: sharedLedger.id.toString());
    expect(sharedPush.error, isNull);
    final sharedFull = await api(
        'GET', '/api/v1/sync/full?ledger_id=$sharedExternal',
        token: token);
    final sharedRows = transactions(
        jsonDecode(sharedFull['snapshot']['payload']['content'] as String));
    expect(sharedRows.length, 2);
    final ownerRow =
        sharedRows.singleWhere((t) => t['syncId'] == ownerSource['entity_id']);
    final editorRow =
        sharedRows.singleWhere((t) => t['syncId'] == sharedCopy.syncId);
    expect(ownerRow['note'], 'QA Owner 原交易');
    expect(editorRow['createdByUserId'], user.id);
    expect(editorRow['categoryId'], ownerCat['entity_id']);
    expect(editorRow['accountId'], ownerAccount['entity_id']);
    expect(editorRow['tagIds'], [ownerTag['entity_id']]);
    pass('T11',
        'Real owner/editor accounts, invite acceptance, shared resources and editor author survive synchronization');
    binding.reportData!['shared_transactions'] = sharedRows;

    // Locally known read-only membership must stop before the new editor opens.
    await (db.update(db.ledgers)..where((l) => l.id.equals(sharedLedger.id)))
        .write(const LedgersCompanion(myRole: d.Value('viewer')));
    final beforeBlocked = (await db.select(db.transactions).get()).length;
    final blockedRow = rowFor('QA Owner 原交易');
    await tester.longPress(blockedRow);
    await waitFor(() => find.text(copyLabel).evaluate().isNotEmpty);
    await tester.tap(find.text(copyLabel));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AmountEditorSheet), findsNothing);
    expect((await db.select(db.transactions).get()).length, beforeBlocked);
    pass('T12',
        'Known read-only ledger blocks copying before creating a local or remote entity');
    await (db.update(db.ledgers)..where((l) => l.id.equals(sharedLedger.id)))
        .write(const LedgersCompanion(myRole: d.Value('editor')));

    final removedResource = await (db.select(db.sharedLedgerCategories)
          ..where((c) => c.syncId.equals(ownerCat['entity_id'] as String)))
        .getSingle();
    await (db.delete(db.sharedLedgerCategories)
          ..where((c) => c.syncId.equals(removedResource.syncId)))
        .go();
    await tester.longPress(blockedRow);
    await waitFor(() => find.text(copyLabel).evaluate().isNotEmpty);
    await tester.tap(find.text(copyLabel));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AmountEditorSheet), findsNothing);
    expect((await db.select(db.transactions).get()).length, beforeBlocked);
    await db.into(db.sharedLedgerCategories).insert(removedResource);
    pass('T12-resource',
        'Missing shared category blocks copying without silently changing references');

    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await host(mode: ThemeMode.dark, locale: const Locale('en'));
    await openCopy('QA 原交易', label: 'Copy as new transaction');
    await binding.takeScreenshot('05-dark-english-copy');
    Navigator.of(tester.element(find.byType(AmountEditorSheet)))
        .popUntil((route) => route.isFirst);
    await tester.pump(const Duration(milliseconds: 400));
    // Keep production UI visible for a final simulator screenshot.
    await host();
    pass('T13',
        'Chinese/light and English/dark menus render; row tap/selection covered by widget tests');
    binding.reportData!['source_sync_id'] = baseline.syncId;
    binding.reportData!['copy_sync_id'] = copied.syncId;
    binding.reportData!['cloud_baseline'] = cloudBaseline;
    binding.reportData!['final_transactions'] = transactions(await snapshot());
    binding.reportData!['source_local'] =
        (await repo.getTransactionById(sourceId))!.toJson();
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 15)));
}

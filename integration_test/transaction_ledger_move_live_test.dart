// The isolated QA runner verifies the built bundle before installing this target.
import 'dart:convert';
import 'dart:io';

import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/pages/shared/transactions/transaction_list_item.dart';
import 'package:beecount/pages/transaction/search_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
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
import 'package:uuid/uuid.dart';

const runId = String.fromEnvironment('QA_RUN_ID');
const origin = String.fromEnvironment('QA_ORIGIN');
const email = String.fromEnvironment('QA_EMAIL');
const password = String.fromEnvironment('QA_PASSWORD');
const appId = String.fromEnvironment('QA_APP_ID');
const moveLabel = '移到账本';
const finalNote = 'QA 云端核对后';

Future<dynamic> api(String method, String route,
    {Map<String, dynamic>? body, String? token, int status = 200}) async {
  final uri = Uri.parse(origin).resolve(route);
  if (uri.origin != origin || uri.host != '127.0.0.1' || uri.scheme != 'http') {
    throw StateError('Expected the owned loopback Cloud');
  }
  final client = http.Client();
  try {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 20));
    expect(response.statusCode, status, reason: '$method $route');
    return response.body.isEmpty ? null : jsonDecode(response.body);
  } finally {
    client.close();
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, String>>[];
  final evidence = <String, dynamic>{'run_id': runId, 'cases': cases};
  binding.reportData = evidence;

  testWidgets('move from transaction row and batch search with live Cloud',
      (tester) async {
    expect(appId, 'com.tntlikely.beecount.qa');
    expect((await PackageInfo.fromPlatform()).packageName, appId);
    expect(runId.startsWith('beecount-qa-'), isTrue);
    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], isTrue);
    final registration = {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': runId
    };
    await api('POST', '/api/v1/auth/register', body: registration);
    final secondId = const Uuid().v4();
    final legacy = await api('POST', '/api/v1/auth/login', body: {
      ...registration,
      'device_id': secondId,
      'device_name': 'QA older device'
    });
    final token = legacy['access_token'] as String;

    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setString('noteDisplayMode', 'note');
    await prefs.setBool('welcome_shown', true);
    await prefs.setBool('account_feature_enabled', true);
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
    expect(user, isNotNull);
    final engine = runtime.syncEngine!;
    final repo = container.read(repositoryProvider) as LocalRepository;
    final db = container.read(databaseProvider);
    final source = await repo.createLedger(name: 'QA 生活');
    final target = await repo.createLedger(name: 'QA 差旅');
    await repo.createLedger(name: 'QA 外币', currency: 'USD');
    final category = await repo.createCategory(name: 'QA 餐饮', kind: 'expense');
    final tag = await repo.createTag(name: 'QA 差旅凭证');
    final account = await repo.createAccount(ledgerId: source, name: 'QA 现金');
    final initial = <int>[];
    for (final note in ['QA 咖啡小票', 'QA 地铁', 'QA 餐费']) {
      initial.add(await repo.addTransaction(
        ledgerId: source,
        type: 'expense',
        categoryId: category,
        accountId: account,
        happenedAt: DateTime.now(),
        amount: 32.1,
        note: note,
        nativeAmount: 32.1,
        currencyCode: 'CNY',
        excludeFromBudget: true,
      ));
    }
    await repo
        .updateTransactionTags(transactionId: initial.first, tagIds: [tag]);
    final image =
        File('${(await getTemporaryDirectory()).path}/qa-ledger-move.png');
    final originalBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jF3sAAAAASUVORK5CYII=');
    await image.writeAsBytes(originalBytes);
    await container.read(attachmentServiceProvider).saveAttachments(
          transactionId: initial.first,
          sourceFiles: [image],
          startIndex: 0,
        );

    Future<void> sync(int ledger) async {
      final result = await engine.sync(ledgerId: ledger.toString());
      expect(result.error, isNull);
    }

    await sync(source);
    await sync(target);
    final sourceSync = (await repo.getLedgerById(source))!.syncId!;
    final targetSync = (await repo.getLedgerById(target))!.syncId!;
    final oldTx = (await repo.getTransactionById(initial.first))!;
    final oldFile = (await repo.getAttachmentsByTransaction(oldTx.id)).single;
    expect(oldFile.cloudFileId, isNotNull);

    await prefs.setInt('current_ledger_id', source);
    container.read(currentLedgerIdProvider.notifier).state = source;
    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MainApp(),
    ));

    Future<void> waitFor(bool Function() condition) async {
      for (var i = 0; i < 220; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (condition()) return;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      await binding.takeScreenshot('failure-ui');
      throw StateError('Expected QA UI state was not reached');
    }

    Future<void> tap(Finder finder) async {
      await waitFor(() => finder.evaluate().isNotEmpty);
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first);
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> fault(bool drop) async {
      await api('POST', '/__qa__/fault',
          body: {'run_id': runId, 'offline': false, 'drop_move_receipt': drop});
    }

    Finder rowFor(String note) => find.byWidgetPredicate(
          (widget) => widget is TransactionListItem && widget.title == note,
          skipOffstage: false,
        );

    final row = rowFor('QA 咖啡小票');
    await waitFor(() => row.evaluate().isNotEmpty);
    await tester.ensureVisible(row);
    final gesture = await tester
        .startGesture(tester.getTopLeft(row) + const Offset(100, 16));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await waitFor(() => find.text(moveLabel).evaluate().isNotEmpty);
    await binding.takeScreenshot('01-row-action');
    await tap(find.text(moveLabel));
    await waitFor(() => find.text('选择目标账本').evaluate().isNotEmpty);
    expect(find.text('QA 外币'), findsNothing);
    await tap(find.text('QA 差旅'));
    await waitFor(() => find.text('确认移动').evaluate().isNotEmpty);
    await binding.takeScreenshot('02-confirm-move');

    await fault(true);
    try {
      await tap(find.text('移动'));
      await waitFor(() => find.text('等待云端确认。联网后将继续恢复。').evaluate().isNotEmpty);
      expect((await repo.getTransactionById(oldTx.id))?.ledgerId, source);
      expect((await db.select(db.pendingTransactionMoves).get()).length, 1);
      final cloudRows = await api(
          'GET', '/api/v1/read/ledgers/$targetSync/transactions',
          token: token) as List;
      expect(cloudRows, hasLength(1));
    } finally {
      await fault(false);
    }
    await sync(source);
    final moved = (await repo.getTransactionById(oldTx.id))!;
    expect(moved.ledgerId, target);
    expect(moved.syncId, isNot(oldTx.syncId));
    expect(
        moved.copyWith(ledgerId: source, syncId: d.Value(oldTx.syncId)), oldTx);
    expect(await db.select(db.pendingTransactionMoves).get(), isEmpty);
    expect((await repo.getTagsForTransaction(moved.id)).single.id, tag);
    final movedAttachment =
        (await repo.getAttachmentsByTransaction(moved.id)).single;
    expect(movedAttachment.cloudFileId, isNot(oldFile.cloudFileId));
    expect(movedAttachment.fileName, oldFile.fileName);
    expect(await cloud.downloadAttachment(fileId: movedAttachment.cloudFileId!),
        originalBytes);
    cases.add({
      'id': 'row-move-receipt',
      'status': 'PASS',
      'detail':
          'Long-press entry, destination filtering, lost response and same-ID recovery'
    });
    cases.add({
      'id': 'attachment',
      'status': 'PASS',
      'detail': 'New target file ID and identical original bytes'
    });

    final changes = (await api('GET', '/api/v1/sync/pull?device_id=$secondId',
        token: token))['changes'] as List;
    expect(
        changes.any((c) =>
            c['ledger_id'] == sourceSync &&
            c['entity_sync_id'] == oldTx.syncId &&
            c['action'] == 'delete'),
        isTrue);
    expect(
        changes.any((c) =>
            c['ledger_id'] == targetSync &&
            c['entity_sync_id'] == moved.syncId &&
            c['action'] == 'upsert'),
        isTrue);
    final stale = await api('POST', '/api/v1/sync/push', token: token, body: {
      'device_id': secondId,
      'changes': [
        {
          'ledger_id': sourceSync,
          'entity_type': 'transaction',
          'entity_sync_id': oldTx.syncId,
          'action': 'upsert',
          'payload': {'syncId': oldTx.syncId, 'amount': 32.1},
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }
      ]
    });
    expect(stale['rejected'], 1);
    expect(stale['conflict_samples'][0]['reason'], 'transaction_moved');
    cases.add({
      'id': 'older-device-wire',
      'status': 'PASS',
      'detail':
          'Second registered device received standard events and stale push was rejected'
    });

    final home = find.byType(HomePage);
    Navigator.of(tester.element(home)).push(MaterialPageRoute<void>(
        builder: (_) => const SearchPage(initialBatchMode: true)));
    await tap(find.text('全选'));
    await waitFor(() =>
        find.text('已选 2 笔').evaluate().isNotEmpty ||
        find.text(moveLabel).evaluate().isNotEmpty);
    await binding.takeScreenshot('03-batch-selected');
    await tap(find.text(moveLabel));
    await tap(find.text('QA 差旅'));
    expect(find.text('将 2 笔账单从「QA 生活」移动到「QA 差旅」。'), findsOneWidget);
    await tap(find.text('移动'));
    await waitFor(() => find.text('已移动 2 笔账单').evaluate().isNotEmpty);
    expect(await repo.getTransactionsByLedger(source), isEmpty);
    expect(await repo.getTransactionsByLedger(target), hasLength(3));
    Navigator.of(tester.element(find.byType(SearchPage))).pop();
    cases.add({
      'id': 'batch-ui',
      'status': 'PASS',
      'detail': 'Batch selection moved the remaining two rows in one action'
    });

    final web = await api('POST', '/api/v1/auth/login',
        body: {...registration, 'client_type': 'web', 'device_name': 'QA Web'});
    await api('PATCH',
        '/api/v1/write/ledgers/$targetSync/transactions/${moved.syncId}',
        body: {'base_change_id': 0, 'note': finalNote, 'amount': 55.5},
        token: web['access_token'] as String);
    await sync(target);
    expect((await repo.getTransactionById(moved.id))?.note, finalNote);
    expect((await repo.getTransactionById(moved.id))?.amount, 55.5);
    await prefs.setInt('current_ledger_id', target);
    container.read(currentLedgerIdProvider.notifier).state = target;
    await waitFor(() => rowFor(finalNote).evaluate().isNotEmpty);
    await binding.takeScreenshot('04-target-after-cloud-update');
    cases.add({
      'id': 'cloud-roundtrip',
      'status': 'PASS',
      'detail':
          'Web write API edited the target row and the App read it via production sync'
    });
    final rows = await repo.getTransactionsByLedger(target);
    rows.sort((a, b) => a.id.compareTo(b.id));
    evidence['target_ledger_sync_id'] = targetSync;
    evidence['normal_ui_markers'] = [finalNote, '55.5'];
    evidence['final_transactions'] = [
      for (final tx in rows)
        {
          'id': tx.id,
          'sync_id': tx.syncId,
          'ledger_sync_id': targetSync,
          'note': tx.note,
          'amount': tx.amount
        },
    ];
  });
}

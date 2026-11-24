// Shared by the verified iOS target and the host Flutter engine against an isolated live Cloud.
import 'dart:convert';

import 'package:beecount/cloud/recurring/cloud_recurring_rules.dart';
import 'package:beecount/cloud/sync/sync_engine.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

const runId = String.fromEnvironment('QA_RUN_ID');
const origin = String.fromEnvironment('QA_ORIGIN');
const password = String.fromEnvironment('QA_PASSWORD');
const email = String.fromEnvironment('QA_EMAIL');

Future<Map<String, dynamic>> qaRequest(String method, String path,
    {Map<String, dynamic>? data, String? token}) async {
  final uri = Uri.parse(origin).resolve(path);
  if (uri.origin != origin ||
      uri.host != '127.0.0.1' ||
      !runId.startsWith('beecount-qa-')) {
    throw StateError('A private QA Cloud is required');
  }
  final client = http.Client();
  try {
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Content-Type'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (data != null) request.body = jsonEncode(data);
    final response = await http.Response.fromStream(await client.send(request))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('QA $method $path returned ${response.statusCode}');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

Future<void> registerQa(String address) async {
  final identity = await qaRequest('GET', '/__qa__/identity');
  expect(identity['run_id'], runId);
  expect(identity['database_is_isolated'], true);
  await qaRequest('POST', '/api/v1/auth/register', data: {
    'email': address,
    'password': password,
    'client_type': 'app',
    'device_name': runId,
  });
}

Future<Map<String, dynamic>> recurringCloudRoundTrip({
  required BeeCountCloudProvider cloud,
  required SyncEngine engine,
  required LocalRepository repo,
  required BeeDatabase db,
  required String address,
}) async {
  final ledgerId =
      await repo.createLedger(name: 'QA Cloud 周期账本', currency: 'CNY');
  final ledger = (await repo.getLedgerById(ledgerId))!;
  final key = ledger.syncId!;
  await engine.fullPush(ledgerId: ledgerId);
  final login = await qaRequest('POST', '/api/v1/auth/login', data: {
    'email': address,
    'password': password,
    'client_type': 'web',
    'device_name': 'QA Web',
  });
  final token = login['access_token'] as String;
  final path = '/api/v1/ledgers/$key/recurring-rules';
  final localId = await repo.addRecurringTransaction(
      ledgerId: ledgerId,
      type: 'expense',
      amount: 67,
      frequency: 'daily',
      interval: 1,
      startDate: DateTime.now().subtract(const Duration(days: 3)));
  final service = RecurringTransactionService(repo);
  expect(await service.generatePendingTransactions(), isEmpty);

  // A browser can save a future rule. App edits its first posting and amount.
  final today = ruleDate(DateTime.now().toUtc());
  final data = <String, dynamic>{
    'name': 'QA 云端合账',
    'frequency': 'daily',
    'interval': 1,
    'starts_at': ruleDate(DateTime.now().toUtc().add(const Duration(days: 2))),
    'time_zone': 'UTC',
    'transaction': {'tx_type': 'expense', 'amount': 31, 'note': 'QA 服务端入账'}
  };
  final create = {
    'action': 'create',
    'client_id': const Uuid().v4(),
    'data': data,
    'confirm': true
  };
  final row = await qaRequest('POST', path, data: create, token: token);
  expect((await qaRequest('POST', path, data: create, token: token))['id'],
      row['id']);
  final appView = (await cloud.recurringRules(key))['items'] as List;
  expect(appView.single['id'], row['id']);
  final edit = {
    'action': 'update',
    'record_id': row['id'],
    'expected_revision': row['revision'],
    'data': {
      ...data,
      'starts_at': today,
      'transaction': {'amount': 43, 'note': 'QA 服务端入账', 'tx_type': 'expense'}
    }
  };
  final preview =
      await cloud.recurringRules(key, change: {...edit, 'confirm': false});
  expect(preview['next_occurrences'][0].toString(), startsWith(today));
  await cloud.recurringRules(key, change: {...edit, 'confirm': true});
  await expectLater(
      cloud.recurringRules(key, change: {...edit, 'confirm': true}),
      throwsA(isA<RecurringRuleException>()
          .having((e) => e.status, 'revision', 409)));
  expect(
      (await qaRequest('GET', path, token: token))['items'][0]['data']['rule']
          ['transaction']['amount'],
      43);
  await qaRequest('POST', '/__qa__/fault',
      data: {'run_id': runId, 'offline': true});
  try {
    expect(await service.generatePendingTransactions(), isEmpty);
    expect((await db.select(db.transactions).get()), isEmpty);
  } finally {
    await qaRequest('POST', '/__qa__/fault',
        data: {'run_id': runId, 'offline': false});
  }

  // Wait for the production scheduler, with both applications idle.
  for (var n = 0; n < 45; n++) {
    final latest = (await cloud.recurringRules(key))['items'][0] as Map;
    if (latest['data']['executed_count'] == 1) break;
    if (n == 44) {
      throw StateError('Production scheduler did not post the due occurrence');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  await engine.pull(ledgerId.toString());
  await engine.pull(ledgerId.toString(), sinceOverride: 0);
  expect(await service.generatePendingTransactions(), isEmpty);
  final all = await db.select(db.transactions).get();
  final posted = all.where((tx) => tx.ledgerId == ledgerId).single;
  expect(posted.amount, 43);
  expect(posted.recurringId, isNull);
  final current = (await cloud.recurringRules(key))['items'][0];
  await qaRequest('POST', path, token: token, data: {
    'action': 'pause',
    'record_id': row['id'],
    'expected_revision': current['revision'],
    'confirm': true
  });
  expect((await cloud.recurringRules(key))['items'][0]['status'], 'paused');
  return {
    'ledger_id': ledgerId,
    'ledger_sync_id': key,
    'rule_id': row['id'],
    'tx_sync_id': posted.syncId,
    'amount': posted.amount,
    'local_rule_id': localId,
    'normal_ui_markers': ['QA 服务端入账', '43.00'],
    'cases': [
      for (final name in [
        'Web 新建与幂等重试',
        'App 编辑后网页可见',
        '陈旧版本收到冲突',
        '绑定 Cloud 后启动和断网均无本机流水',
        '实际调度后台入账一笔',
        'App 两次拉取保持同一流水',
        '网页暂停后 App 可见'
      ])
        {'id': name, 'status': 'PASS', 'detail': name}
    ]
  };
}

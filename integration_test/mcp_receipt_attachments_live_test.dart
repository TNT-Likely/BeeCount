// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:beecount/pages/attachment/attachment_preview_page.dart';

import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/statistics_providers.dart';
import 'package:beecount/providers/language_provider.dart';
import 'package:beecount/providers/sync_providers.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/providers/ui_state_providers.dart';
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

Future<http.Response> request(String method, String path,
    {Map<String, dynamic>? body, String? token}) async {
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
    if (body != null) req.body = jsonEncode(body);
    return await http.Response.fromStream(await client.send(req))
        .timeout(const Duration(seconds: 30));
  } finally {
    client.close();
  }
}

Future<dynamic> api(String method, String path,
    {Map<String, dynamic>? body, String? token}) async {
  final response = await request(method, path, body: body, token: token);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('QA API $method $path returned ${response.statusCode}');
  }
  return jsonDecode(response.body);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  final cases = <Map<String, dynamic>>[];
  binding.reportData = {
    'run_id': runId,
    'scenario': 'mcp-receipt-attachments',
    'cases': cases
  };
  testWidgets(
      'MCP receipts: real protocol, sync and production App preview/delete UI',
      (tester) async {
    expect(appId, 'com.tntlikely.beecount.qa');
    expect((await PackageInfo.fromPlatform()).packageName, appId);
    expect(runId.startsWith('beecount-qa-'), isTrue);
    final identity = await api('GET', '/__qa__/identity');
    expect(identity['run_id'], runId);
    expect(identity['database_is_isolated'], isTrue);
    await api('POST', '/api/v1/auth/register', body: {
      'email': email,
      'password': password,
      'client_type': 'app',
      'device_name': runId
    });
    await HomeWidget.setAppGroupId('group.com.tntlikely.beecount.qa');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', 'zh');
    await prefs.setBool('welcome_shown', true);
    await prefs.setString('noteDisplayMode', 'note');
    await CloudServiceStore().saveAndActivate(const CloudServiceConfig(
        type: CloudBackendType.beecountCloud,
        name: 'Isolated QA Cloud',
        beecountCloudBaseUrl: origin,
        beecountCloudEmail: email,
        beecountCloudPassword: password));
    final container = ProviderContainer();
    final runtime = (await container.read(activeCloudRuntimeProvider.future))!;
    final cloud = runtime.provider! as BeeCountCloudProvider;
    expect(cloud.baseUrl, origin);
    await cloud.auth.signInWithEmail(email: email, password: password);
    final engine = runtime.syncEngine!;
    final repo = container.read(repositoryProvider) as LocalRepository;
    final ledgerId = await repo.createLedger(name: 'QA MCP小票 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final category = await repo.createCategory(
        name: 'QA餐饮', kind: 'expense', icon: 'restaurant');
    final originalId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 12.3,
        categoryId: category,
        happenedAt: DateTime.now(),
        note: 'QA App原始交易');
    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 90));
      expect(result.error, isNull);
    }

    await sync();
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final original = (await repo.getTransactionById(originalId))!;
    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web'
    });
    final token = login['access_token'] as String;
    Future<String> pat(List<String> scopes) async {
      final value = await api('POST', '/api/v1/profile/pats',
          token: token,
          body: {
            'name': 'Private receipt QA',
            'scopes': scopes,
            'expires_in_days': 1
          });
      return value['token'] as String;
    }

    final writePat = await pat(['mcp:read', 'mcp:write']);
    final readPat = await pat(['mcp:read']);
    var rpcId = 0;
    Future<Map<String, dynamic>> rpc(String method, Map<String, dynamic> params,
        {String? credential}) async {
      final uri = Uri.parse(origin).resolve('/api/v1/mcp');
      if (uri.origin != origin || uri.host != '127.0.0.1') {
        throw StateError('Not an owned QA origin');
      }
      final response = await http
          .post(uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json, text/event-stream',
                'MCP-Protocol-Version': '2025-03-26',
                'Authorization': 'Bearer ${credential ?? writePat}'
              },
              body: jsonEncode({
                'jsonrpc': '2.0',
                'id': ++rpcId,
                'method': method,
                'params': params
              }))
          .timeout(const Duration(seconds: 30));
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      expect(data.containsKey('error'), isFalse);
      return data['result'] as Map<String, dynamic>;
    }

    Future<Map<String, dynamic>> call(String name, Map<String, dynamic> args,
        {String? credential, bool error = false}) async {
      final result = await rpc('tools/call', {'name': name, 'arguments': args},
          credential: credential);
      expect(result['isError'] == true, error);
      if (error) return result;
      return (result['structuredContent'] ??
              jsonDecode(result['content'][0]['text'] as String))
          as Map<String, dynamic>;
    }

    await rpc('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': {},
      'clientInfo': {'name': 'Private receipt QA', 'version': '1.0'}
    });
    final tools = (await rpc('tools/list', {}))['tools'] as List;
    expect(tools.any((t) => t['name'] == 'upload_attachment'), isTrue);
    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});
    pass('M01',
        'Real PAT-authenticated Streamable HTTP initialize and tools/list expose the upload tool');
    Future<List<int>> receipt(String label, Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
          const Rect.fromLTWH(0, 0, 360, 520), Paint()..color = color);
      canvas.drawRect(
          const Rect.fromLTWH(24, 24, 312, 472), Paint()..color = Colors.white);
      final text = TextPainter(
          text: TextSpan(
              text: 'BEECOUNT QA\n\n$label\n\nSynthetic receipt\n\nCNY 78.80',
              style: const TextStyle(
                  color: Colors.black, fontSize: 22, height: 1.5)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: 280);
      text.paint(canvas, const Offset(40, 45));
      final bitmap = await recorder.endRecording().toImage(360, 520);
      final bytes = (await bitmap.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      bitmap.dispose();
      return bytes;
    }

    final imageA = await receipt('Receipt A', const Color(0xffffcb65));
    final imageB = await receipt('Receipt B', const Color(0xffffcb65));
    final imageC = await receipt('Replacement C', const Color(0xffbee9d3));
    Future<Map<String, dynamic>> upload(List<int> bytes) =>
        call('upload_attachment', {
          'ledger_id': ledger.syncId,
          'file_name': 'qa-receipt.png',
          'mime_type': 'image/png',
          'content_base64': base64Encode(bytes)
        });
    final a = await upload(imageA), b = await upload(imageB);
    expect((await upload(imageA))['file_id'], a['file_id']);
    expect(a['sha256'], sha256.convert(imageA).toString());
    pass('M02',
        'Duplicate bytes reuse one file ID; two different receipts with the same name have distinct IDs');
    final created = await call('create_transaction', {
      'ledger_id': ledger.syncId,
      'amount': 78.8,
      'category': 'QA餐饮',
      'note': 'QA MCP最终小票',
      'attachments': [a['file_id'], b['file_id']]
    });
    final sid = created['sync_id'] as String;
    Future<Map<String, dynamic>> remote() =>
        call('get_transaction', {'sync_id': sid});
    Future<List<Map<String, dynamic>>> verify() async {
      final value = await remote();
      await sync();
      final tx = (await repo.getTransactionsByLedger(ledgerId))
          .singleWhere((t) => t.syncId == sid);
      final refs = (value['attachments'] as List).cast<Map<String, dynamic>>();
      final local = await repo.getAttachmentsByTransaction(tx.id);
      expect(local.length, refs.length);
      final files = <Map<String, dynamic>>[];
      for (var i = 0; i < local.length; i++) {
        final row = local[i], ref = refs[i];
        expect(row.cloudFileId, ref['cloudFileId']);
        expect(row.sortOrder, i);
        expect(row.fileName, ref['fileName']);
        expect(row.originalName, ref['originalName']);
        final file = File(await container
            .read(attachmentServiceProvider)
            .getAttachmentPath(row.fileName));
        expect(file.existsSync(), isTrue);
        final digest = sha256.convert(await file.readAsBytes()).toString();
        expect(digest, ref['cloudSha256']);
        files.add({
          'fileName': row.fileName,
          'cloudFileId': row.cloudFileId,
          'sha256': digest,
          'size': file.lengthSync(),
          'sortOrder': row.sortOrder
        });
      }
      expect(tx.amount, value['amount']);
      container.read(statsRefreshProvider.notifier).state++;
      return files;
    }

    Future<void> waitUi(bool Function() ready) async {
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (ready()) return;
      }
      await binding.takeScreenshot('failure-mcp-app-ui');
      throw StateError('Expected production App UI did not become visible');
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await binding.takeScreenshot(name);
    }

    Future<void> home() async {
      Navigator.of(tester.element(find.byType(Scaffold).last))
          .popUntil((r) => r.isFirst);
      await tester.pump(const Duration(milliseconds: 800));
    }

    Future<void> preview(String screenshot) async {
      await waitUi(() => find.byType(HomePage).evaluate().isNotEmpty);
      final row = find.byWidgetPredicate(
          (w) => w is TransactionListItem && w.title == 'QA MCP最终小票',
          skipOffstage: false);
      await waitUi(() => row.evaluate().isNotEmpty);
      final icon = find
          .descendant(
              of: row.first,
              matching: find.byIcon(Icons.image_outlined, skipOffstage: false),
              skipOffstage: false)
          .first;
      await tester.ensureVisible(icon);
      await tester.tap(icon);
      await waitUi(() =>
          find.byType(AttachmentPreviewPage).evaluate().isNotEmpty &&
          find.byType(InteractiveViewer).evaluate().isNotEmpty);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      await capture(screenshot);
    }

    await verify();
    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    await preview('01-app-mcp-receipt-a');
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 700));
    await capture('02-app-mcp-receipt-b');
    await home();
    pass('M03',
        'One MCP-created transaction reaches App with matching IDs/order/SHA; production preview renders both receipts');
    await call('update_transaction', {'sync_id': sid, 'amount': 79.8});
    expect((await verify()).length, 2);
    await call('update_transaction',
        {'sync_id': sid, 'amount': 78.8, 'attachments': null});
    expect((await verify()).length, 2);
    pass('M04',
        'Omitted/null attachments preserve receipts during ordinary edits');
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [b['file_id'], a['file_id']]
    });
    expect((await verify()).first['cloudFileId'], b['file_id']);
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [b['file_id']]
    });
    expect((await verify()).single['sortOrder'], 0);
    final nextA = await upload(imageA);
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [b['file_id'], nextA['file_id']]
    });
    expect((await verify()).length, 2);
    pass('M05',
        'MCP reorder/remove/append keeps file identity and consecutive App sort order');
    final c = await upload(imageC);
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [c['file_id']]
    });
    expect((await verify()).single['sha256'], c['sha256']);
    await preview('03-app-mcp-replacement');
    await home();
    await call('update_transaction', {'sync_id': sid, 'attachments': []});
    expect(await verify(), isEmpty);
    pass('M06',
        'Replacement downloads new bytes; [] clears App attachment rows');
    final next1 = await upload(imageA), next2 = await upload(imageB);
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [next1['file_id'], next2['file_id']]
    });
    await verify();
    await preview('04-app-mcp-before-delete');
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump(const Duration(milliseconds: 500));
    await waitUi(() => find.text('确定').evaluate().isNotEmpty);
    await tester.tap(find.text('确定').last);
    await tester.pump(const Duration(milliseconds: 800));
    await home();
    await sync();
    expect(((await remote())['attachments'] as List).length, 1);
    pass('M07',
        'Actual App preview deletion uploads through the engine and is visible in MCP');
    await call(
        'upload_attachment',
        {
          'ledger_id': ledger.syncId,
          'file_name': 'bad.png',
          'content_base64': 'invalid base64'
        },
        error: true);
    await call(
        'upload_attachment',
        {
          'ledger_id': ledger.syncId,
          'file_name': 'readonly.png',
          'content_base64': base64Encode(imageA)
        },
        credential: readPat,
        error: true);
    await call(
        'update_transaction',
        {
          'sync_id': sid,
          'amount': 999,
          'attachments': ['unknown-file-id']
        },
        error: true);
    expect((await remote())['amount'], 78.8);
    expect(((await remote())['attachments'] as List).length, 1);
    pass('M08',
        'Actual MCP rejects bad Base64, read-only PAT and unknown reference without changing the transaction');
    final finalA = await upload(imageA), finalB = await upload(imageB);
    await call('update_transaction', {
      'sync_id': sid,
      'attachments': [finalA['file_id'], finalB['file_id']]
    });
    final files = await verify();
    await sync();
    await sync();
    final all = await repo.getTransactionsByLedger(ledgerId);
    expect(all.length, 2);
    final stillOriginal = all.singleWhere((t) => t.syncId == original.syncId);
    expect(stillOriginal.note, 'QA App原始交易');
    expect(stillOriginal.amount, 12.3);
    expect(await repo.getAttachmentsByTransaction(stillOriginal.id), isEmpty);
    await preview('05-app-mcp-final-preview');
    await home();
    await capture('06-app-mcp-final-home');
    pass('M09',
        'Repeated sync preserves both transaction identities and the original App record; final two receipts remain for review');
    final full = await api(
        'GET', '/api/v1/sync/full?ledger_id=${ledger.syncId}',
        token: token);
    binding.reportData!.addAll({
      'ledger_sync_id': ledger.syncId,
      'app_transaction_sync_id': original.syncId,
      'mcp_transaction_sync_id': sid,
      'normal_ui_markers': ['QA MCP最终小票', '78.8'],
      'final_snapshot':
          jsonDecode(full['snapshot']['payload']['content'] as String),
      'final_app_files': files
    });
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 20)));
}

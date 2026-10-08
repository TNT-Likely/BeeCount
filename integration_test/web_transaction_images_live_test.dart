// Run only in the verified QA bundle on a simulator owned by this run.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/pages/attachment/attachment_preview_page.dart';
import 'package:beecount/widgets/biz/attachment_picker.dart';

import 'package:beecount/main.dart' show MainApp;
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/pages/main/home_page.dart';
import 'package:beecount/providers/database_providers.dart';
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
    'scenario': 'web-transaction-images',
    'cases': cases
  };
  testWidgets(
      'Web images: real Cloud sync and production App preview/delete UI',
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
    final ledgerId = await repo.createLedger(name: 'QA 图片验收 $runId');
    container.read(currentLedgerIdProvider.notifier).state = ledgerId;
    await prefs.setInt('current_ledger_id', ledgerId);
    final cat = await repo.createCategory(
        name: 'QA餐饮', kind: 'expense', icon: 'restaurant');
    final txId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: 32.1,
        categoryId: cat,
        happenedAt: DateTime.now(),
        note: 'QA App图片');
    // A private synthetic image fixture, saved by the actual attachment service.
    // This setup is not evidence of OS photo-picker interaction.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 360, 240),
        Paint()..color = const Color(0xffffcb65));
    canvas.drawRect(
        const Rect.fromLTWH(40, 40, 280, 160), Paint()..color = Colors.white);
    final bitmap = await recorder.endRecording().toImage(360, 240);
    final bytes = (await bitmap.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    final fixture =
        File('${(await getTemporaryDirectory()).path}/qa-app-receipt.png');
    await fixture.writeAsBytes(bytes);
    final attachment = await container
        .read(attachmentServiceProvider)
        .saveAttachment(
            transactionId: txId, sourceFile: fixture, index: 0, urgent: true);
    expect(attachment, isNotNull);
    Future<void> sync() async {
      final result = await engine
          .sync(ledgerId: ledgerId.toString())
          .timeout(const Duration(seconds: 90));
      expect(result.error, isNull);
    }

    await sync();
    final ledger = (await repo.getLedgerById(ledgerId))!;
    final appTx = (await repo.getTransactionById(txId))!;
    final login = await api('POST', '/api/v1/auth/login', body: {
      'email': email,
      'password': password,
      'client_type': 'web',
      'device_name': '$runId-web'
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
    void pass(String id, String detail) =>
        cases.add({'id': id, 'status': 'PASS', 'detail': detail});
    Future<void> waitUi(bool Function() ready) async {
      for (var i = 0; i < 160; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (ready()) return;
        await Future<void>.delayed(const Duration(milliseconds: 60));
      }
      await binding.takeScreenshot('failure-image-app-ui');
      throw StateError(
          'Production App UI did not reach the expected image state');
    }

    Future<void> tapText(String text) async {
      await waitUi(() => find.text(text).evaluate().isNotEmpty);
      await tester.ensureVisible(find.text(text).first);
      await tester.tap(find.text(text).first);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 500));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await binding.takeScreenshot(name);
    }

    Future<Map<String, dynamic>> waitWeb(
        String note, int count, String stage) async {
      debugPrint('QA_STAGE_READY_$stage');
      for (var i = 0; i < 1200; i++) {
        final s = await snapshot();
        final hits = transactions(s).where((tx) => tx['note'] == note).toList();
        if (hits.length == 1 &&
            ((hits.single['attachments'] as List?) ?? []).length == count)
          return hits.single;
        await tester.pump(const Duration(milliseconds: 100));
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      throw StateError('Actual QA Web action did not complete: $stage');
    }

    Future<List<Map<String, dynamic>>> verifyLocal(
        Map<String, dynamic> remote) async {
      await sync();
      final tx = (await repo.getTransactionsByLedger(ledgerId))
          .singleWhere((tx) => tx.syncId == remote['syncId']);
      final refs = (remote['attachments'] as List?) ?? [];
      final local = await repo.getAttachmentsByTransaction(tx.id);
      expect(local.length, refs.length);
      final evidence = <Map<String, dynamic>>[];
      for (final row in local) {
        final ref = refs
            .cast<Map<String, dynamic>>()
            .singleWhere((r) => r['fileName'] == row.fileName);
        expect(row.cloudFileId, ref['cloudFileId']);
        final path = await container
            .read(attachmentServiceProvider)
            .getAttachmentPath(row.fileName);
        final file = File(path);
        expect(file.existsSync(), isTrue);
        final digest = sha256.convert(await file.readAsBytes()).toString();
        expect(digest, ref['cloudSha256']);
        evidence.add({
          'fileName': row.fileName,
          'cloudFileId': row.cloudFileId,
          'sha256': digest,
          'size': file.lengthSync(),
          'sortOrder': row.sortOrder
        });
      }
      return evidence;
    }

    Future<void> openPreview(String note, String screenshot) async {
      await waitUi(() => find.byType(HomePage).evaluate().isNotEmpty);
      await tapText(note);
      await waitUi(() =>
          find.byType(TransactionEditorPage).evaluate().isNotEmpty &&
          find.byType(AttachmentPicker).evaluate().isNotEmpty);
      final picker = find.byType(AttachmentPicker).first;
      await tester.ensureVisible(picker);
      await tester.pump(const Duration(milliseconds: 600));
      final gesture = find
          .descendant(of: picker, matching: find.byType(GestureDetector))
          .first;
      await tester.tap(gesture);
      await waitUi(() =>
          find.byType(AttachmentPreviewPage).evaluate().isNotEmpty &&
          find.byType(InteractiveViewer).evaluate().isNotEmpty);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      await capture(screenshot);
    }

    Future<void> home() async {
      Navigator.of(tester.element(find.byType(Scaffold).last))
          .popUntil((route) => route.isFirst);
      await tester.pump(const Duration(milliseconds: 800));
    }

    final initial = await snapshot();
    expect(transactions(initial).single['syncId'], appTx.syncId);
    expect((transactions(initial).single['attachments'] as List).length, 1);
    pass('I01',
        'Synthetic App receipt saved by the production service and uploaded by the real sync engine; same Cloud identity and bytes');
    await container.read(primaryColorInitProvider.future);
    await container.read(themeModeInitProvider.future);
    container.read(themeModeProvider.notifier).state = ThemeMode.light;
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
    container.read(appInitStateProvider.notifier).state = AppInitState.ready;
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MainApp()));
    await openPreview('QA App图片', '01-app-existing-receipt');
    await home();
    var remote = await waitWeb('QA Web新建图片', 1, 'WEB_NEW');
    final webSid = remote['syncId'];
    await verifyLocal(remote);
    await openPreview('QA Web新建图片', '02-app-web-created-image');
    await home();
    pass('I02',
        'Actual Web-created transaction pulled to App; image bytes match Cloud SHA and production preview renders');
    remote = await waitWeb('QA Web追加图片', 2, 'WEB_ADD');
    await verifyLocal(remote);
    pass('I03',
        'Web appended image; both ordered references and files match in App');
    final beforeReplace = await repo.getAttachmentsByTransaction(
        (await repo.getTransactionsByLedger(ledgerId))
            .singleWhere((tx) => tx.syncId == webSid)
            .id);
    remote = await waitWeb('QA Web替换图片', 2, 'WEB_REPLACE');
    await verifyLocal(remote);
    final replacementRefs =
        (remote['attachments'] as List).cast<Map<String, dynamic>>();
    for (final old in beforeReplace.where(
        (old) => !replacementRefs.any((r) => r['fileName'] == old.fileName))) {
      expect(
          File(await container
                  .read(attachmentServiceProvider)
                  .getAttachmentPath(old.fileName))
              .existsSync(),
          isFalse);
    }
    await openPreview('QA Web替换图片', '03-app-replaced-image');
    await home();
    pass('I04',
        'Web replacement keeps transaction identity; App downloads new bytes and removes detached local file');
    remote = await waitWeb('QA Web删除全部', 0, 'WEB_REMOVE_ALL');
    await verifyLocal(remote);
    pass('I05',
        'Explicit empty Web attachment list removes all App attachment rows');
    remote = await waitWeb('QA Web重传图片', 1, 'WEB_REUPLOAD');
    await verifyLocal(remote);
    await openPreview('QA Web重传图片', '04-app-reuploaded-image');
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pump(const Duration(milliseconds: 500));
    await tapText('删除');
    await tester.pump(const Duration(milliseconds: 800));
    await home();
    await sync();
    final deleted = transactions(await snapshot())
        .singleWhere((tx) => tx['syncId'] == webSid);
    expect((deleted['attachments'] as List?) ?? [], isEmpty);
    pass('I06',
        'Production App preview delete UI synchronized the empty attachment list back to Cloud');
    remote = await waitWeb('QA Web最终图片', 2, 'WEB_FINAL');
    final files = await verifyLocal(remote);
    await openPreview('QA Web最终图片', '05-app-final-images');
    await home();
    final finalSnapshot = await snapshot();
    expect(transactions(finalSnapshot).length, 2);
    expect(
        transactions(finalSnapshot)
            .singleWhere((tx) => tx['syncId'] == appTx.syncId)['amount'],
        32.1);
    expect(remote['syncId'], webSid);
    await sync();
    expect((await repo.getTransactionsByLedger(ledgerId)).length, 2);
    pass('I07',
        'Repeated sync preserves two transaction identities, amounts and the original App image; final two-image draft persists');
    await capture('06-app-final-home');
    binding.reportData!.addAll({
      'ledger_sync_id': ledger.syncId,
      'app_transaction_sync_id': appTx.syncId,
      'web_transaction_sync_id': webSid,
      'normal_ui_markers': ['QA Web最终图片', '45.6'],
      'initial_snapshot': initial,
      'final_snapshot': finalSnapshot,
      'final_app_files': files
    });
    await prefs.setString('qa_run_id', runId);
  }, timeout: const Timeout(Duration(minutes: 60)));
}

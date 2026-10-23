import 'dart:io';
import 'dart:ui' as ui;

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/attachment/attachment_preview_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_service.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository extends LocalRepository {
  _Repository(super.db);
  bool rejectDelete = false;
  @override
  Future<void> deleteAttachment(int id) {
    if (rejectDelete) throw StateError('Synthetic delete failure');
    return super.deleteAttachment(id);
  }
}

class _Attachments extends AttachmentService {
  _Attachments(super.ref, this.directory);
  final Directory directory;
  bool rejectDirectory = false;
  @override
  Future<Directory> getAttachmentDirectory() async {
    if (rejectDirectory) throw StateError('Synthetic directory failure');
    return directory;
  }

  @override
  Future<Directory> getThumbnailDirectory() async =>
      Directory('${directory.path}/thumbs')..createSync();
}

void main() {
  late Directory directory;
  late BeeDatabase db;
  late _Repository repo;
  late ProviderContainer container;
  late _Attachments service;
  late List<TransactionAttachment> rows;
  late List<File> pending;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    directory = await Directory.systemTemp.createTemp('beecount-v4-viewer-');
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES (1,'QA','CNY')");
    await db.customStatement(
        "INSERT INTO transactions (id,ledger_id,type,amount) VALUES (1,1,'expense',10),(2,1,'income',20)");
    final picture = ui.PictureRecorder();
    ui.Canvas(picture).drawPaint(ui.Paint()..color = const Color(0xfffacd20));
    final recording = picture.endRecording();
    final image = await recording.toImage(40, 80);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    recording.dispose();
    pending = [];
    for (var i = 0; i < 2; i++) {
      final name = 'synthetic-$i.png';
      pending.add(await File('${directory.path}/$name')
          .writeAsBytes(bytes!.buffer.asUint8List()));
      await repo.createAttachment(
          transactionId: 1,
          fileName: name,
          fileSize: 2048,
          originalName: name,
          width: 40,
          height: 80,
          sortOrder: i);
    }
    // Another transaction shares the first physical file.
    await repo.createAttachment(transactionId: 2, fileName: 'synthetic-0.png');
    rows = await repo.getAttachmentsByTransaction(1);
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      attachmentServiceProvider
          .overrideWith((ref) => service = _Attachments(ref, directory)),
    ]);
    container.read(attachmentServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> open(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: beeTheme(),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute<void>(builder: (_) => page)),
                        child: const Text('打开预览')))))));
    await tester.tap(find.text('打开预览'));
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 30));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('真实附件加载、索引夹取、滑动与缩略图切换，保留缩放', (tester) async {
    await open(
        tester,
        const AttachmentPreviewPage.fromTransaction(
            transactionId: 1, initialIndex: 99));
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('2 KB · 40×80'), findsOneWidget);
    final zoom =
        tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);
    expect(zoom.maxScale, 4);
    await tester.drag(find.byType(PageView), const Offset(650, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('2 / 2 · synthetic-1.png'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(await repo.getAttachmentsByTransaction(1), hasLength(2));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('双指缩放实际改变图片矩阵，不误触关闭或切换并保持原附件', (tester) async {
    await open(
        tester,
        const AttachmentPreviewPage.fromTransaction(
            transactionId: 1, allowDelete: false));
    final viewer = find.byType(InteractiveViewer).first;
    final center = tester.getCenter(viewer);
    final left =
        await tester.startGesture(center - const Offset(40, 0), pointer: 1);
    final right =
        await tester.startGesture(center + const Offset(40, 0), pointer: 2);
    await tester.pump();
    await left.moveTo(center - const Offset(140, 0));
    await right.moveTo(center + const Offset(140, 0));
    await tester.pump(const Duration(milliseconds: 50));
    final transforms = tester.widgetList<Transform>(
        find.descendant(of: viewer, matching: find.byType(Transform)));
    expect(
        transforms.any((t) => t.transform.getMaxScaleOnAxis() > 1.5), isTrue);
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(AttachmentPreviewPage), findsOneWidget);
    expect(await repo.getAttachmentsByTransaction(1), rows);
    expect(pending.every((file) => file.existsSync()), isTrue);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('删除取消不改数据，确认只删当前引用并保留共享图片', (tester) async {
    await open(
        tester, const AttachmentPreviewPage.fromTransaction(transactionId: 1));
    await tester.tap(find.bySemanticsLabel('删除').first);
    await tester.pumpAndSettle();
    expect(find.byType(BeeDialog), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(await repo.getAttachmentsByTransaction(1), hasLength(2));
    await tester.tap(find.bySemanticsLabel('删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BeeButton, '删除'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    expect(await repo.getAttachmentsByTransaction(1), hasLength(1));
    expect(await repo.getAttachmentsByTransaction(2), hasLength(1));
    expect(pending.first.existsSync(), isTrue);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('服务删除失败保留图片与数据库，不能显示删除成功', (tester) async {
    repo.rejectDelete = true;
    await open(
        tester, const AttachmentPreviewPage.fromTransaction(transactionId: 1));
    await tester.tap(find.bySemanticsLabel('删除').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(BeeButton, '删除'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(await repo.getAttachmentsByTransaction(1), hasLength(2));
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('待保存图片删除即时更新父级，系统返回不丢草稿且不删文件', (tester) async {
    List<File>? draft;
    await open(
        tester,
        AttachmentPreviewPage(
            attachments: const [],
            pendingFiles: pending,
            onPendingFilesChanged: (files) => draft = files));
    expect(find.text('待保存'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('删除').first);
    await tester.pumpAndSettle();
    expect(draft?.map((f) => f.path), [pending.last.path]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('打开预览'), findsOneWidget);
    expect(draft?.map((f) => f.path), [pending.last.path]);
    expect(pending.first.existsSync(), isTrue);
    expect(await repo.getAttachmentsByTransaction(1), hasLength(2));
    await close(tester);
  });

  testWidgets('目录失败可重试，只读预览不提供新增与删除', (tester) async {
    service.rejectDirectory = true;
    await open(
        tester, AttachmentPreviewPage(attachments: rows, allowDelete: false));
    expect(find.text('重试'), findsOneWidget);
    expect(find.bySemanticsLabel('删除'), findsNothing);
    service.rejectDirectory = false;
    await tester.tap(find.text('重试'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.bySemanticsLabel('删除'), findsNothing);
    expect(find.bySemanticsLabel('添加图片'), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/data_management_page.dart';
import 'package:beecount/pages/settings/attachments/bindings/attachment_transfer_actions.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/services/attachment_export_import_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConfirmHarness extends ConsumerStatefulWidget {
  const _ConfirmHarness();
  @override
  ConsumerState<_ConfirmHarness> createState() => _ConfirmState();
}

class _ConfirmState extends ConsumerState<_ConfirmHarness>
    with AttachmentTransferActions<_ConfirmHarness> {
  Map<String, dynamic>? result;
  @override
  Widget build(BuildContext context) => Scaffold(
          body: Column(children: [
        TextButton(
            onPressed: () async {
              final value = await showAttachmentImportConfirm(
                  'long_filename_with_attachments_and_icons.tar.gz',
                  AttachmentArchiveInfo(
                      version: 1,
                      count: 5,
                      fileSize: 12000,
                      customIconCount: 2,
                      hasAvatar: true,
                      exportedAt: DateTime(2026, 10, 25)));
              if (mounted) setState(() => result = value);
            },
            child: const Text('选择归档')),
        Text(result?.toString() ?? '未确认')
      ]));
}

void main() {
  late BeeDatabase db;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'数据管理验收','CNY')");
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      repositoryProvider.overrideWithValue(LocalRepository(db))
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t,
      {bool compact = false, Widget child = const DataManagementPage()}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: Locale(compact ? 'en' : 'zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (c, w) => MediaQuery(
                data: MediaQuery.of(c).copyWith(
                    textScaler: TextScaler.linear(compact ? 1.4 : 1),
                    disableAnimations: true),
                child: w!),
            home: child)));
    await t.pumpAndSettle();
  }

  for (final compact in [false, true]) {
    testWidgets(
        '原后台导入就绪/运行/全成功/部分失败，原Provider与真实数据库保留 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(t, compact: compact);
      final l = AppLocalizations.of(t.element(find.byType(DataManagementPage)));
      final task = find.byType(BeeFileTransferStatus).first;
      expect(t.widget<BeeFileTransferStatus>(task).onTap, isNotNull);
      expect(
          t.widget<BeeFileTransferStatus>(task).state, BeeFileTaskState.ready);
      for (final progress in [
        const ImportProgress(running: true, total: 0, done: 0, ok: 0, fail: 0),
        const ImportProgress(running: true, total: 10, done: 4, ok: 3, fail: 1),
        const ImportProgress(
            running: false, total: 10, done: 10, ok: 10, fail: 0),
        const ImportProgress(
            running: false, total: 10, done: 10, ok: 8, fail: 2)
      ]) {
        container.read(importProgressProvider.notifier).state = progress;
        await t.pump(const Duration(milliseconds: 1000));
        final widget = t.widget<BeeFileTransferStatus>(task);
        expect(widget.onTap, isNull);
        expect(
            widget.state,
            progress.running
                ? BeeFileTaskState.running
                : progress.fail == 0
                    ? BeeFileTaskState.success
                    : BeeFileTaskState.partial);
        expect(
            widget.title,
            progress.running
                ? l.mineImportProgressTitle
                : l.mineImportCompleteTitle);
        expect(widget.progress,
            progress.total == 0 ? null : progress.done / progress.total);
        expect(t.takeException(), isNull);
      }
      await t.scrollUntilVisible(find.text(l.attachmentExportTitle), 250,
          scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.text(l.attachmentImportTitle));
      await t.pumpAndSettle();
      expect(find.byType(BeeIconButton), findsOneWidget);
      expect(find.text(l.attachmentPreview), findsOneWidget);
      expect(
          await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
      expect(t.takeException(), isNull);
    });
    testWidgets(
        '原归档确认保持弹窗、跳过默认、覆盖草稿与取消/预览/导入返回 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(t, compact: compact, child: const _ConfirmHarness());
      final l = AppLocalizations.of(t.element(find.byType(_ConfirmHarness)));
      Future<void> open() async {
        await t.tap(find.text('选择归档'));
        await t.pumpAndSettle();
        expect(find.byType(BeeDialog), findsOneWidget);
        expect(
            t
                .widget<BeeArchiveSummary>(find.byType(BeeArchiveSummary))
                .overwrite,
            isFalse);
      }

      await open();
      await t.ensureVisible(find.text(l.attachmentImportConflictOverwrite));
      await t.tap(find.text(l.attachmentImportConflictOverwrite));
      await t.pumpAndSettle();
      expect(
          t.widget<BeeArchiveSummary>(find.byType(BeeArchiveSummary)).overwrite,
          isTrue);
      await t.tap(find.byType(CloseButton));
      await t.pumpAndSettle();
      expect(find.text('未确认'), findsOneWidget);
      await open();
      await t.tap(find.text(l.attachmentPreview));
      await t.pumpAndSettle();
      expect(find.textContaining('preview: true'), findsOneWidget);
      expect(find.textContaining(AttachmentExportImportService.conflictSkip),
          findsOneWidget);
      await open();
      await t.ensureVisible(find.text(l.attachmentImportConflictOverwrite));
      await t.tap(find.text(l.attachmentImportConflictOverwrite));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(l.attachmentStartImport));
      await t.tap(find.text(l.attachmentStartImport));
      await t.pumpAndSettle();
      expect(find.textContaining('preview: false'), findsOneWidget);
      expect(
          find.textContaining(AttachmentExportImportService.conflictOverwrite),
          findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

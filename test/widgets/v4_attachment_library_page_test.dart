import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/attachment_preview_page.dart';
import 'package:beecount/presentation/v4/bindings/attachment_library_data.dart';
import 'package:beecount/services/attachment_export_import_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Uint8List png;
  setUpAll(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xff123456));
    final picture = recorder.endRecording(),
        image = await picture.toImage(40, 120);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    png = Uint8List(2048)
      ..setRange(0, data!.lengthInBytes, data.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester t, ArchivePreviewData data,
      {bool compact = false}) async {
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: Locale(compact ? 'en' : 'zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(compact ? 1.4 : 1),
                    disableAnimations: true),
                child: child!),
            home: AttachmentPreviewPage(title: '导入预览', archiveData: data))));
    await t.pumpAndSettle();
  }

  Future<void> waitInfo(WidgetTester t, String text) async {
    for (var i = 0; i < 50 && find.text(text).evaluate().isEmpty; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(find.text(text), findsWidgets);
  }

  for (final compact in [false, true]) {
    testWidgets(
        '原归档字节、完整长文件名、真实元信息与只读缩放/关闭 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      final name = '${'收据' * 30}-20261025-20261025-20261025.png',
          bytes = Uint8List.fromList(png);
      await mount(
          t,
          ArchivePreviewData(attachments: [
            AttachmentPreviewItem(fileName: name, bytes: bytes)
          ], customIcons: [
            AttachmentPreviewItem(fileName: 'icon.png', bytes: png)
          ]),
          compact: compact);
      await waitInfo(t, '2.00 KB');
      final geometry = jsonDecode(
          File('test/fixtures/v4-attachment-library-geometry.json')
              .readAsStringSync()) as Map<String, dynamic>;
      final grid = t.widget<GridView>(find.byType(GridView).first);
      expect(grid.padding,
          EdgeInsets.all((geometry['pageInset'] as num).toDouble()));
      final tile = find
          .descendant(
              of: find.byType(BeeAttachmentLibrary).first,
              matching: find.byType(InkWell))
          .first;
      expect(t.getSize(tile).width,
          closeTo(geometry[compact ? '320' : '398']['tileWidth'] as num, .01));
      expect(t.getRect(tile).left, geometry['pageInset']);
      await t.tap(find.text('2.00 KB'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(Dialog), matching: find.text('40 × 120')),
          findsOneWidget);
      expect(
          t.widget<InteractiveViewer>(find.byType(InteractiveViewer)).maxScale,
          2.5);
      final center = t.getCenter(find.byType(InteractiveViewer)),
          left = await t.createGesture(pointer: 1),
          right = await t.createGesture(pointer: 2);
      await left.down(center - const Offset(20, 0));
      await right.down(center + const Offset(20, 0));
      await t.pump();
      await left.moveTo(center - const Offset(65, 0));
      await right.moveTo(center + const Offset(65, 0));
      await t.pump();
      await left.up();
      await right.up();
      await t.pumpAndSettle();
      final transforms = t
          .widgetList<Transform>(find.descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(Transform)))
          .map((w) => w.transform.getMaxScaleOnAxis());
      expect(transforms.any((s) => s > 1 && s <= 2.5 + .001), isTrue);
      final close = MaterialLocalizations.of(t.element(find.byType(Dialog)))
          .closeButtonTooltip;
      await t.tap(find.byTooltip(close));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(bytes, png);
      expect(find.byTooltip('删除'), findsNothing);
      expect(t.takeException(), isNull);
    });
    testWidgets('左右滑动保留、空组可切换，小屏选中标签完整可见 ${compact ? '320英文深色140%' : '398中文'}',
        (t) async {
      await mount(
          t,
          ArchivePreviewData(attachments: [], customIcons: [
            AttachmentPreviewItem(fileName: 'icon.png', bytes: png)
          ]),
          compact: compact);
      final context = t.element(find.byType(AttachmentPreviewPage)),
          l = AppLocalizations.of(context);
      expect(find.byType(BeeEmptyState), findsOneWidget);
      await t.fling(find.byType(TabBarView), const Offset(-280, 0), 1000);
      await t.pumpAndSettle();
      await waitInfo(t, '2.00 KB');
      final segment =
          t.widget<BeeSegmented<int>>(find.byType(BeeSegmented<int>));
      expect(segment.value, 1);
      if (compact) {
        expect(segment.scrollController!.hasClients, isTrue);
        expect(segment.scrollController!.offset, greaterThan(0));
        final rect = t.getRect(find.text('${l.v4CustomIcons} (1)'));
        expect(rect.left, greaterThanOrEqualTo(17));
        expect(rect.right, lessThanOrEqualTo(303));
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('全部为空时隐藏无用页签，显示原空态', (t) async {
    await mount(t, ArchivePreviewData(attachments: [], customIcons: []));
    expect(find.byType(BeeSegmented<int>), findsNothing);
    expect(find.byType(BeeEmptyState), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('坏图仍保留真实字节大小，预览失败不修改输入', (t) async {
    final bytes = Uint8List.fromList([0, 1, 2]);
    await mount(
        t,
        ArchivePreviewData(attachments: [
          AttachmentPreviewItem(fileName: 'bad.png', bytes: bytes)
        ], customIcons: []));
    await waitInfo(t, '3 B');
    expect(find.byType(BeeAttachmentLibrary), findsWidgets);
    expect(
        t
            .widgetList<BeeLineIcon>(find.byType(BeeLineIcon))
            .any((w) => w.name == 'ImageOff'),
        isTrue);
    await t.tap(find.text('3 B'));
    await t.pumpAndSettle();
    expect(find.text('bad.png'), findsOneWidget);
    expect(bytes, [0, 1, 2]);
    expect(t.takeException(), isNull);
  });
  test('原文件大小四级格式保留，不因预览改字节数', () {
    expect(AttachmentLibraryData.formatSize(1023), '1023 B');
    expect(AttachmentLibraryData.formatSize(2048), '2.00 KB');
    expect(AttachmentLibraryData.formatSize(1572864), '1.50 MB');
    expect(AttachmentLibraryData.formatSize(1073741824), '1.00 GB');
  });
}

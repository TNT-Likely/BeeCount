import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/attachment_preview_page.dart';
import 'package:beecount/services/attachment_export_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File attachment;
  late File icon;
  late Uint8List attachmentBytes;
  late Uint8List iconBytes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('beecount-preview-');
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xFF123456));
    final picture = recorder.endRecording();
    final image = await picture.toImage(10, 10);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final pngBytes = png!.buffer.asUint8List();
    // PNG trailing padding keeps the image valid and gives known file sizes.
    attachmentBytes = Uint8List(2048)..setRange(0, pngBytes.length, pngBytes);
    iconBytes = Uint8List(1572864)..setRange(0, pngBytes.length, pngBytes);
    attachment = await File('${directory.path}/receipt.png')
        .writeAsBytes(attachmentBytes);
    icon = await File('${directory.path}/icon.png').writeAsBytes(iconBytes);
  });

  tearDown(() async => directory.delete(recursive: true));

  for (final fromArchive in [false, true]) {
    testWidgets(
        '${fromArchive ? 'archive' : 'export'} preview shows actual image sizes in grid and detail',
        (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final page = fromArchive
          ? AttachmentPreviewPage(
              title: '导入预览',
              archiveData: ArchivePreviewData(
                attachments: [
                  AttachmentPreviewItem(
                      fileName: 'receipt.png', bytes: attachmentBytes),
                ],
                customIcons: [
                  AttachmentPreviewItem(fileName: 'icon.png', bytes: iconBytes),
                ],
              ),
            )
          : AttachmentPreviewPage(
              title: '导出预览',
              exportData: ExportPreviewData(
                  attachments: [attachment], customIcons: [icon]),
            );

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: page,
        ),
      ));
      await tester.runAsync(() async {
        await attachment.length();
        await icon.length();
      });
      await tester.pumpAndSettle();

      expect(find.text('2.00 KB'), findsOneWidget);
      await tester.tap(find.text('2.00 KB'));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(Dialog), matching: find.text('2.00 KB')),
          findsOneWidget);
      expect(find.text('receipt.png'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自定义图标 (1)'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async => icon.length());
      await tester.pumpAndSettle();
      expect(find.text('1.50 MB'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/dev/component_gallery/bindings/attachment_library_preview.dart';
import 'package:beecount/dev/component_gallery/bindings/file_workflow_preview.dart';
import 'package:beecount/services/attachment_export_import_service.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late ExportPreviewData data;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('beecount-library-scroll-');
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder)
        .drawPaint(ui.Paint()..color = const ui.Color(0xff123456));
    final picture = recorder.endRecording(),
        image = await picture.toImage(40, 120),
        png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final files = <File>[];
    for (var i = 0; i < 7; i++) {
      files.add(await File('${dir.path}/$i.png')
          .writeAsBytes(png!.buffer.asUint8List()));
    }
    data = ExportPreviewData(
        attachments: files.take(5).toList(),
        customIcons: files.skip(5).toList());
  });
  tearDown(() async => dir.delete(recursive: true));
  testWidgets('从真实文件缩略图开始上滑由外层目录接管，生产入口可达', (t) async {
    t.view.physicalSize = const Size(398, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await t.pumpWidget(ProviderScope(
        overrides: [
          attachmentWorkflowFilesProvider.overrideWith((ref) async => data)
        ],
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SingleChildScrollView(
                    controller: scroll,
                    child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 17),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(height: 270),
                              LiveAttachmentLibraryPreview()
                            ])))))));
    await t.pumpAndSettle();
    await t
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pumpAndSettle();
    final image = find.bySemanticsLabel('1 / 5 · 0.png');
    final center = t.getCenter(image);
    expect(center.dy, lessThan(568));
    await t.dragFrom(center, const Offset(0, -220));
    await t.pumpAndSettle();
    expect(scroll.offset, greaterThan(30));
    final button = t.getRect(find.text('打开真实导出预览'));
    expect(button.bottom, lessThanOrEqualTo(568));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
  });
}

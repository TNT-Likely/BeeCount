import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount/presentation/v4/gallery/transaction_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = [
    for (final path in [
      'assets/v4_gallery/transaction-states.json',
      'assets/v4_gallery/transaction-c3-cases.json',
    ])
      ...(jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>()
  ];
  setUpAll(() async {
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/material_fonts').existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    final roboto = FontLoader('TransactionTest');
    for (final weight in ['Regular', 'Bold']) {
      roboto.addFont(Future.value(ByteData.sublistView(
          await File('${directory.path}/material_fonts/Roboto-$weight.ttf')
              .readAsBytes())));
    }
    await roboto.load();
    // The host CJK font supplies real ideograph metrics for local native review.
    // CI still uses actual Flutter Roboto rather than Ahem, without system assets.
    final cjk = File('/System/Library/Fonts/STHeiti Light.ttc');
    if (cjk.existsSync()) {
      final loader = FontLoader('TransactionCJK');
      loader
          .addFont(Future.value(ByteData.sublistView(await cjk.readAsBytes())));
      await loader.load();
    }
  });
  final captureKey = GlobalKey();
  Future<void> open(WidgetTester tester, Widget child,
      {double width = 398,
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: brightness).copyWith(
            textTheme: beeTheme(brightness: brightness)
                .textTheme
                .apply(fontFamily: 'TransactionTest')
                .copyWith(
                    bodyMedium: beeTheme(brightness: brightness)
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                            fontFamily: 'TransactionTest',
                            fontFamilyFallback: const ['TransactionCJK']))),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: DefaultTextStyle.merge(
                style: const TextStyle(fontFamily: 'TransactionTest', fontFamilyFallback: ['TransactionCJK']),
                child: child!)),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: RepaintBoundary(key: captureKey, child: BeeSurface(padding: EdgeInsets.zero, child: child))))));
    await tester.pump(const Duration(milliseconds: 400));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }

  BeeTransactionRow fixture(Map<String, dynamic> s,
      {VoidCallback? onTap,
      VoidCallback? onCategory,
      ValueChanged<BeeTagData>? onTag,
      VoidCallback? onAttachment,
      VoidCallback? onMenu,
      ValueChanged<bool>? onSelected,
      Future<void> Function()? onDelete}) {
    final f = TransactionRowFixture(s);
    return BeeTransactionRow(
        key: ValueKey(s['id']),
        title: f.title,
        categoryLabel: f.category,
        categoryActionLabel: f.category,
        labels: galleryTransactionLabels,
        note: f.note,
        detailsNote: s['note'] as String?,
        amount: s['amount'] as String,
        converted: s['converted'] as String?,
        accountName: f.account,
        ledgerName: s['ledgerName'] as String?,
        happenedAt: s['happenedAt'] == null
            ? null
            : DateTime.parse(s['happenedAt'] as String),
        showTime: s['showTime'] == true,
        showFullDate: s['showFullDate'] == true,
        selected: s['selected'] as bool?,
        onSelected: onSelected,
        hidden: s['hidden'] == true,
        readOnly: s['readOnly'] == true,
        statusLabels: ((s['status'] as List?) ?? []).cast<String>(),
        attachmentCount: (s['attachments'] as int?) ?? 0,
        kind: BeeTransactionKind.values.byName(s['kind'] as String),
        tags: f.tags,
        icon: BeeCategoryIcon(
            name: s['icon'] as String,
            image:
                s['image'] == null ? null : AssetImage(s['image'] as String)),
        onTap: onTap ?? () {},
        onCategoryTap: onCategory ?? () {},
        onTagTap: onTag,
        onAttachmentTap: onAttachment,
        onMenu: onMenu,
        onDeleteRequested: onDelete);
  }

  void geometry(WidgetTester tester, Map<String, dynamic> s) {
    final row = find.byType(BeeTransactionRow), box = tester.getRect(row);
    expect(box.height, lessThan(160),
        reason: '${s['id']}: bounded host must not stretch the row');
    final lines = [
      for (var i = 1; i <= 3; i++) find.byKey(ValueKey('transaction-line-$i'))
    ].where((f) => f.evaluate().isNotEmpty).toList();
    expect(lines.length, lessThanOrEqualTo(3),
        reason: '${s['id']}: at most3 physical lines');
    for (var i = 1; i < lines.length; i++) {
      expect(tester.getRect(lines[i - 1]).bottom,
          lessThanOrEqualTo(tester.getRect(lines[i]).top),
          reason: '${s['id']}: vertical overlap');
    }
    for (final key in [
      'transaction-amount',
      'transaction-converted',
      'transaction-timestamp',
      for (var i = 0; i < ((s['status'] as List?) ?? []).length; i++)
        'transaction-status-$i'
    ]) {
      final f = find.byKey(ValueKey(key));
      if (f.evaluate().isEmpty) continue;
      final rect = tester.getRect(f);
      expect(rect.left, greaterThanOrEqualTo(box.left - .6),
          reason: '${s['id']}/$key');
      expect(rect.right, lessThanOrEqualTo(box.right + .6),
          reason: '${s['id']}/$key');
      final p = tester.renderObject<RenderParagraph>(f);
      expect(p.didExceedMaxLines, isFalse,
          reason: '${s['id']}/$key: full critical text');
      expect(
          p.text.toPlainText(),
          key == 'transaction-amount'
              ? s['hidden'] == true
                  ? '••••'
                  : s['amount']
              : p.text.toPlainText());
    }
    for (final label in (s['status'] as List?) ?? []) {
      expect(find.text(label as String), findsOneWidget);
    }
    if (s['ledgerName'] != null) {
      final ledger = find.byKey(const ValueKey('transaction-ledger'));
      expect(ledger, findsOneWidget);
      expect(tester.widget<BeeInlineLabel>(ledger).label, s['ledgerName']);
    }
    expect(tester.takeException(), isNull,
        reason: '${s['id']}: actual render overflow');
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final dir = Platform.environment['BEECOUNT_TRANSACTION_CAPTURE_DIR'];
    if (dir == null) return;
    await tester.runAsync(() async {
      final image = await (captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [398.0, 320.0]) {
    for (final scale in [1.0, 1.4]) {
      for (final dark in [false, true]) {
        testWidgets('C3真实渲染60状态：$width $scale ${dark ? '深' : '浅'}',
            (tester) async {
          expect(source.length, 60);
          for (final s in source) {
            await open(tester, fixture(s),
                width: width,
                scale: scale,
                brightness: dark ? Brightness.dark : Brightness.light);
            geometry(tester, s);
            if (s['id'] == 'tags-attachments') {
              expect(find.byKey(const ValueKey('transaction-line-3')),
                  findsNothing,
                  reason: 'S25 must use two lines');
              expect(find.byKey(const ValueKey('transaction-more-fields')),
                  findsNothing);
              expect(find.text('微信'), findsOneWidget);
              expect(find.text('3'), findsOneWidget);
              expect(find.text('餐饮'), findsNothing,
                  reason: 'Do not repeat category below note');
              await capture(tester,
                  'native-s25-${width.toInt()}-${(scale * 100).toInt()}-${dark ? 'dark' : 'light'}');
            }
            if (s['id'] == 'cross-big-all') {
              await capture(tester,
                  'native-worst-${width.toInt()}-${(scale * 100).toInt()}-${dark ? 'dark' : 'light'}');
            }
          }
        });
      }
    }
  }
  testWidgets('本地CJK真实字宽与金额保持原字号', (tester) async {
    final s = source.firstWhere((s) => s['id'] == 'cross-big-all');
    await open(tester, fixture(s), width: 320, scale: 1.4);
    if (File('/System/Library/Fonts/STHeiti Light.ttc').existsSync()) {
      expect(tester.getSize(find.text('不计收支')).width, greaterThanOrEqualTo(53));
    }
    final money = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('transaction-amount')));
    double? digitSize;
    void inspect(InlineSpan span, TextStyle inherited) {
      if (span is! TextSpan) return;
      final effective = inherited.merge(span.style);
      if (span.text?.contains('1,234,567,890.12') == true) {
        digitSize = effective.fontSize;
      }
      for (final child in span.children ?? <InlineSpan>[]) {
        inspect(child, effective);
      }
    }

    inspect(money.text, const TextStyle());
    expect(digitSize, 16);
    expect(money.didExceedMaxLines, isFalse);
  });
  testWidgets('独立分类、编辑、标签、附件与长按保留原回调', (tester) async {
    var category = 0, edit = 0, tag = 0, attachment = 0, menu = 0;
    final s = source.firstWhere((s) => s['id'] == 'tags-attachments');
    await open(
        tester,
        fixture(s,
            onTap: () => edit++,
            onCategory: () => category++,
            onTag: (_) => tag++,
            onAttachment: () => attachment++,
            onMenu: () => menu++));
    await tester.tap(find.byType(BeeCategoryIcon));
    expect(category, 1);
    expect(edit, 0);
    await tester.tap(find.byKey(const ValueKey('transaction-title')));
    expect(edit, 1);
    await tester.tap(find.text('工作日'));
    expect(tag, 1);
    expect(edit, 1);
    await tester.tap(find.text('3'));
    expect(attachment, 1);
    expect(edit, 1);
    await tester.longPress(find.byKey(const ValueKey('transaction-title')));
    expect(menu, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('极端更多项能读全部字段，原币折算和标记未丢，关闭不选择不编辑', (tester) async {
    var selections = 0, edits = 0;
    final s = {
      ...source.firstWhere((s) => s['id'] == 'cross-readonly-batch'),
      'selected': false
    };
    await open(tester,
        fixture(s, onTap: () => edits++, onSelected: (_) => selections++),
        width: 320, scale: 1.4);
    await tester.tap(find.byKey(const ValueKey('transaction-more-fields')));
    await tester.pumpAndSettle();
    expect(find.text('完整账单字段'), findsOneWidget);
    expect(find.text('只读'), findsAtLeastNWidgets(1));
    expect(find.text(s['accountName'] as String), findsOneWidget);
    expect(find.text(s['ledgerName'] as String), findsAtLeastNWidgets(1));
    expect(find.text((s['tags'] as List).join(' · ')), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(selections, 0);
    expect(edits, 0);
    expect(tester.takeException(), isNull);
  });
}

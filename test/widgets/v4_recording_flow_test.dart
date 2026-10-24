import 'dart:async';
import 'dart:convert';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount_ui/beecount_ui.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/transaction/transaction_editor_page.dart';
import 'package:beecount/presentation/v4/bindings/recording_category_section.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/shared_ledger_picker_filter.dart';
import 'package:beecount/widgets/biz/amount_editor_sheet.dart';
import 'package:beecount/widgets/biz/account_selector.dart';
import 'package:beecount/widgets/biz/note_picker_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const captureUi = bool.fromEnvironment('BEECOUNT_CAPTURE_UI');

class RetryRecordingRepository extends LocalRepository {
  RetryRecordingRepository(super.db);
  final started = Completer<void>();
  final release = Completer<void>();
  bool failFirst = true;

  @override
  Future<void> updateTransactionTags(
      {required int transactionId, required List<int> tagIds}) async {
    if (failFirst) {
      started.complete();
      await release.future;
      failFirst = false;
      throw StateError('Synthetic tag write failure');
    }
    await super
        .updateTransactionTags(transactionId: transactionId, tagIds: tagIds);
  }
}

void recordingTest(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late LocalRepository repo;
  late int foodId;
  late int lunchId;
  late int incomeId;
  final boundaryKey = GlobalKey();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'auto_sync': false});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers (id, name, currency) VALUES (1, '日常生活', 'CNY')");
    foodId = await repo.createCategory(
        name: '餐饮', kind: 'expense', icon: 'restaurant', sortOrder: 0);
    lunchId = await repo.createSubCategory(
        parentId: foodId, name: '午餐', kind: 'expense', icon: 'restaurant');
    for (var i = 0; i < 8; i++) {
      await repo.createCategory(
          name: ['饮品', '交通', '购物', '居家', '娱乐', '文教', '医疗', '其他'][i],
          kind: 'expense',
          icon: [
            'coffee',
            'train',
            'shopping_basket',
            'home',
            'movie',
            'menu_book',
            'local_hospital',
            'category'
          ][i],
          sortOrder: i + 1);
    }
    incomeId =
        await repo.createCategory(name: '工资', kind: 'income', icon: 'payments');
  });

  tearDown(() async => db.close());

  Future<void> open(
    WidgetTester tester, {
    TransactionEditorPage page =
        const TransactionEditorPage(initialKind: 'expense', quickAdd: true),
    Size size = const Size(390, 844),
    bool accountsEnabled = false,
    double safeTop = 0,
    double safeBottom = 0,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    String skin = 'none',
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = FakeViewPadding(top: safeTop, bottom: safeBottom);
    tester.view.viewPadding = FakeViewPadding(top: safeTop, bottom: safeBottom);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (captureUi) {
      final noto = File('build/v4-recording-fonts/NotoSansSC-400.ttf');
      final font = noto.existsSync()
          ? noto
          : File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (font.existsSync()) {
        final loader = FontLoader('Preview');
        loader.addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())));
        await tester.runAsync(loader.load);
      }
    }
    if (captureUi) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(Future.value(ByteData.sublistView(
          File('build/unit_test_assets/fonts/MaterialIcons-Regular.otf')
              .readAsBytesSync())));
      await tester.runAsync(loader.load);
    }
    await tester.pumpWidget(ProviderScope(
        overrides: [
          headerSkinProvider.overrideWith((ref) => skin),
          skinAnimationEnabledProvider.overrideWith((ref) => false),
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerProvider.overrideWith(
              (ref) => repo.watchLedger(ref.watch(currentLedgerIdProvider))),
          beecountCloudProviderInstance.overrideWith((ref) async => null),
          accountFeatureEnabledProvider
              .overrideWith((ref) async => accountsEnabled),
          currencyPickerRatesProvider
              .overrideWith((ref, base) async => {'USD': 7.2}),
        ],
        child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  brightness: brightness,
                  fontFamily: captureUi ? 'Preview' : null,
                  colorScheme: ColorScheme.fromSeed(
                          seedColor: const Color(0xfff8cc15),
                          brightness: brightness)
                      .copyWith(
                          primary: const Color(0xfff8cc15),
                          onPrimary: const Color(0xff262829))),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('zh'),
              home: Builder(
                  builder: (context) => Scaffold(
                      body: Center(
                          child: FilledButton(
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => page)),
                              child: const Text('打开记账'))))),
            ))));
    await tester.tap(find.text('打开记账'));
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, String digit) async {
    await tester.ensureVisible(find.byKey(ValueKey('recording-key-$digit')));
    await tester.tap(find.byKey(ValueKey('recording-key-$digit')));
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, String name) async {
    final button = find.byKey(ValueKey(name));
    await tester.ensureVisible(button);
    await tester.tap(button);
  }

  Future<void> category(WidgetTester tester, int id) async {
    final finder = find.byKey(ValueKey('recording-category-$id')).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!captureUi) return;
    await tester.pumpAndSettle();
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/v4-recording/$name.png');
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  final frozenDesign = jsonDecode(
      File('test/fixtures/v4-recording-design-geometry.json')
          .readAsStringSync()) as Map<String, dynamic>;
  for (final entry in frozenDesign['cases'] as List<dynamic>) {
    final id = entry['id'] as String;
    final boxes = entry['geometry'] as Map<String, dynamic>;
    recordingTest('对齐 R8 HTML 已冻结尺寸：$id', (tester) async {
      final size = Size((boxes['phone']['w'] as num).toDouble(),
          (boxes['phone']['h'] as num).toDouble());
      final compact = size.height < 720;
      await open(tester,
          size: size,
          accountsEnabled: true,
          safeTop: compact ? 21 : 37,
          safeBottom: compact ? 1 : 12,
          textScale: id == 'usd-large-text' ? 1.4 : 1,
          page: TransactionEditorPage(
              initialKind: 'expense',
              quickAdd: true,
              initialAmount: id.startsWith('usd') ? 12 : 32,
              initialCurrencyCode: id.startsWith('usd') ? 'USD' : 'CNY',
              initialNativeAmount: id.startsWith('usd') ? 85.2 : 32));
      final finders = {
        'amount': find.byType(RecordingAmountCard),
        'category': find.byKey(const ValueKey('recording-content')),
        'metadata': find.byKey(const ValueKey('recording-details')),
        'keypad': find.byType(RecordingKeypad),
        'save': find.byKey(const ValueKey('recording-save')),
      };
      for (final part in finders.entries) {
        final actual = tester.getRect(part.value);
        final expected = boxes[part.key] as Map<String, dynamic>;
        expect(actual.top, closeTo((expected['y'] as num).toDouble(), .1),
            reason: '$id ${part.key} top');
        expect(actual.height, closeTo((expected['h'] as num).toDouble(), .1),
            reason: '$id ${part.key} height');
      }
      await capture(tester, 'design-contract-$id');
      expect(tester.takeException(), isNull);
    });
  }

  recordingTest('真实录入：二级分类、四则运算、备注、连续保存和正常退出', (tester) async {
    await open(tester);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('recording-save')))
            .onPressed,
        isNull);
    await key(tester, '1');
    await key(tester, '2');
    await key(tester, '+');
    await key(tester, '3');
    await press(tester, 'recording-equals');
    await tester.pump();
    await key(tester, '×');
    await key(tester, '2');
    await category(tester, foodId);
    await category(tester, lunchId);
    final note = find.byKey(const ValueKey('recording-note'));
    await tester.ensureVisible(note);
    await tester.enterText(note, '午间食堂');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // '=' computes without writing, while Save also supports a pending operation.
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final first = await db.select(db.transactions).get();
    expect(first, hasLength(1));
    expect(first.single.amount, 30);
    expect(first.single.nativeAmount, 30);
    expect(first.single.currencyCode, 'CNY');
    expect(first.single.categoryId, lunchId);
    expect(first.single.note, '午间食堂');
    expect(find.text('打开记账'), findsOneWidget);

    await tester.tap(find.text('打开记账'));
    await tester.pumpAndSettle();
    await category(tester, foodId);
    await key(tester, '8');
    await press(tester, 'recording-save-next');
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), hasLength(2));
    expect(find.byKey(const ValueKey('recording-amount')), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '0.00');
    await category(tester, foodId);
    await key(tester, '9');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  recordingTest('备注图标保留历史备注，选择后仍可直接修改并保存', (tester) async {
    await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 8,
        categoryId: foodId,
        happenedAt: DateTime.now(),
        note: '历史午餐');
    await open(tester,
        page: TransactionEditorPage(
          initialCategoryId: foodId,
          initialKind: 'expense',
          quickAdd: true,
        ));
    await tester.tap(find.byKey(const ValueKey('recording-note-history')));
    await tester.pumpAndSettle();
    expect(find.byType(NotePickerDialog), findsOneWidget);
    await tester.tap(find.text('历史午餐 · 1'));
    await tester.pumpAndSettle();
    final note = find.byKey(const ValueKey('recording-note'));
    expect(tester.widget<TextField>(note).controller!.text, '历史午餐');
    await tester.enterText(note, '历史午餐修改');
    await key(tester, '9');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    expect((await db.select(db.transactions).get()).map((t) => t.note),
        containsAll(['历史午餐', '历史午餐修改']));
    expect(tester.takeException(), isNull);
  });

  recordingTest('两行表单：备注直接编辑、附件右上角、间距和顶部标记入口', (tester) async {
    await open(tester, accountsEnabled: true);
    final amount =
        tester.widget<Text>(find.byKey(const ValueKey('recording-amount')));
    expect(amount.data, '0.00');
    expect(amount.style!.fontSize, 33);
    final account = find.byKey(const ValueKey('recording-account'));
    final date = find.byKey(const ValueKey('recording-date'));
    final tags = find.byKey(const ValueKey('recording-tags'));
    expect(tester.getCenter(account).dy, tester.getCenter(date).dy);
    expect(tester.getCenter(tags).dy, tester.getCenter(date).dy);
    final next = find.byKey(const ValueKey('recording-save-next'));
    final equals = find.byKey(const ValueKey('recording-equals'));
    final save = find.byKey(const ValueKey('recording-save'));
    expect(tester.getCenter(next).dy, tester.getCenter(save).dy);
    expect(tester.getCenter(equals).dy, tester.getCenter(save).dy);
    expect(tester.getSize(save).width, greaterThan(tester.getSize(next).width));
    final note = find.byKey(const ValueKey('recording-note'));
    await tester.enterText(note, '直接编辑备注');
    expect(find.byType(Dialog), findsNothing);
    expect(tester.widget<TextField>(note).controller!.text, '直接编辑备注');
    final attachment = find.byKey(const ValueKey('recording-attachments'));
    expect(
        tester.getCenter(attachment).dy, closeTo(tester.getCenter(note).dy, 1));
    expect(tester.getCenter(attachment).dx,
        greaterThan(tester.getCenter(note).dx));
    final form = find.byKey(const ValueKey('recording-details'));
    final key7 = find.byKey(const ValueKey('recording-key-7'));
    expect(
        tester.getRect(key7).top - tester.getRect(form).bottom, closeTo(8, .1));
    expect(find.text('清空金额'), findsNothing);
    await tester.tap(find.byTooltip('更多选项'));
    await tester.pumpAndSettle();
    expect(find.text('账单标记'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  recordingTest('原位备注的首次返回收起键盘，第二次返回才确认放弃草稿', (tester) async {
    await open(tester);
    await key(tester, '3');
    await key(tester, '2');
    await category(tester, foodId);
    await category(tester, lunchId);
    final note = find.byKey(const ValueKey('recording-note'));
    await tester.enterText(note, '保留原位备注');
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次记账？'), findsNothing);
    expect(find.text('保留原位备注'), findsOneWidget);
    expect(find.byKey(const ValueKey('recording-key-7')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('放弃本次记账？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('保留原位备注'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  recordingTest('更多分类返回保留金额；切换收入后保存使用收入分类', (tester) async {
    await open(tester);
    await key(tester, '3');
    await key(tester, '2');
    await tester
        .ensureVisible(find.byKey(const ValueKey('recording-more-categories')));
    await tester.tap(find.byKey(const ValueKey('recording-more-categories')));
    await tester.pumpAndSettle();
    final other = find.descendant(
        of: find.byType(BottomSheet), matching: find.text('其他'));
    expect(other, findsOneWidget);
    await tester.tap(other);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(BottomSheet), matching: find.text('确定')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '32.00');
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    await category(tester, incomeId);
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.type, 'income');
    expect(saved.categoryId, incomeId);
    expect(saved.amount, 32);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    recordingTest('更多分类选中末尾二级后完整露出，表单与键盘保持固定 $size', (tester) async {
      for (var i = 0; i < 6; i++) {
        await repo.createCategory(
            name: '补充分类$i', kind: 'expense', sortOrder: 30 + i);
      }
      final parent = await repo.createCategory(
          name: '末项父类', kind: 'expense', sortOrder: 999);
      final child = await repo.createSubCategory(
          parentId: parent, name: '末项子类', kind: 'expense', icon: 'coffee');
      await open(tester, size: size);
      final details = find.byKey(const ValueKey('recording-details'));
      final save = find.byKey(const ValueKey('recording-save'));
      final detailsRect = tester.getRect(details),
          saveRect = tester.getRect(save);
      await tester.ensureVisible(
          find.byKey(const ValueKey('recording-more-categories')));
      await tester.tap(find.byKey(const ValueKey('recording-more-categories')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.byType(TextField)),
          '末项子类');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(RecordingSubcategoryChip, '末项子类'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.text('确定')));
      await tester.pumpAndSettle();
      final categoryArea =
          tester.getRect(find.byKey(const ValueKey('recording-content')));
      final selected =
          tester.getRect(find.byKey(ValueKey('recording-category-$child')));
      expect(selected.top, greaterThanOrEqualTo(categoryArea.top - .1));
      expect(selected.bottom, lessThanOrEqualTo(categoryArea.bottom + .1));
      expect(tester.getRect(details), detailsRect);
      expect(tester.getRect(save), saveRect);
      expect(tester.takeException(), isNull);
    });
  }

  recordingTest('空白收支切换使用对应默认账户，已有金额草稿保留账户', (tester) async {
    final expenseAccount =
        await repo.createAccount(ledgerId: 1, name: '支出默认', currency: 'CNY');
    final incomeAccount =
        await repo.createAccount(ledgerId: 1, name: '收入默认', currency: 'CNY');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_expense_account_id', expenseAccount);
    await prefs.setInt('default_income_account_id', incomeAccount);
    await open(tester, accountsEnabled: true);
    expect(find.text('支出默认'), findsOneWidget);
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text('收入默认'), findsOneWidget);
    expect(find.byType(BeeDialog), findsNothing);
    await tester.tap(find.text('支出'));
    await tester.pumpAndSettle();
    expect(find.text('支出默认'), findsOneWidget);
    await key(tester, '7');
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text('支出默认'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '7.00');
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  recordingTest('明确选择不设置账户后，空白切换类型也不会补入默认账户', (tester) async {
    final incomeAccount =
        await repo.createAccount(ledgerId: 1, name: '收入默认', currency: 'CNY');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_income_account_id', incomeAccount);
    await open(tester, accountsEnabled: true);
    final l10n =
        AppLocalizations.of(tester.element(find.byType(TransactionEditorPage)));
    await tester.tap(find.text(l10n.accountNone));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.accountNone).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accountNone), findsOneWidget);
    expect(find.text('收入默认'), findsNothing);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  recordingTest('账本切换取消保留草稿，确认后切换本位币并重置后按新账本保存', (tester) async {
    await db.customStatement(
        "INSERT INTO ledgers (id,name,currency) VALUES(2,'美元旅行','USD')");
    await open(tester);
    await category(tester, foodId);
    await category(tester, lunchId);
    await key(tester, '7');
    await tester.tap(find.text('日常生活'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('美元旅行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsWidgets);
    expect(find.text('日常生活'), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    await tester.tap(find.text('日常生活'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('美元旅行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('美元旅行'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '0.00');
    await category(tester, foodId);
    await category(tester, lunchId);
    await key(tester, '9');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.ledgerId, 2);
    expect(saved.currencyCode, 'USD');
    expect(saved.amount, 9);
    expect(saved.nativeAmount, 9);
    expect(saved.categoryId, lunchId);
    expect(tester.takeException(), isNull);
  });

  recordingTest('外币编辑保留原汇率快照；取消返回保留草稿', (tester) async {
    final id = await repo.addTransaction(
        ledgerId: 1,
        type: 'expense',
        amount: 12,
        categoryId: lunchId,
        happenedAt: DateTime(2026, 10, 20),
        note: '原备注',
        currencyCode: 'USD',
        nativeAmount: 86.4);
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'expense',
            quickAdd: true,
            editingTransactionId: id,
            initialCategoryId: lunchId,
            initialAmount: 12,
            initialNote: '原备注',
            initialCurrencyCode: 'USD',
            initialNativeAmount: 86.4,
            initialDate: DateTime(2026, 10, 20)));
    expect(find.textContaining('≈ ¥86.40'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('recording-note')));
    await tester.enterText(find.byKey(const ValueKey('recording-note')), '新备注');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(find.text('放弃本次记账？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('新备注'), findsOneWidget);
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.id, id);
    expect(saved.currencyCode, 'USD');
    expect(saved.nativeAmount, 86.4);
    expect(saved.note, '新备注');
    expect(tester.takeException(), isNull);
  });

  for (final snapshot in [12.0, 85.23456789]) {
    recordingTest('仅编辑备注保留美元历史快照 $snapshot，包括汇率为一的情况', (tester) async {
      final id = await repo.addTransaction(
          ledgerId: 1,
          type: 'expense',
          amount: 12,
          categoryId: lunchId,
          happenedAt: DateTime(2026, 10, 20),
          currencyCode: 'USD',
          nativeAmount: snapshot);
      await open(tester,
          page: TransactionEditorPage(
              initialKind: 'expense',
              editingTransactionId: id,
              initialCategoryId: lunchId,
              initialAmount: 12,
              initialCurrencyCode: 'USD',
              initialNativeAmount: snapshot,
              initialDate: DateTime(2026, 10, 20)));
      await tester.enterText(
          find.byKey(const ValueKey('recording-note')), '只改备注');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await press(tester, 'recording-save');
      await tester.pumpAndSettle();
      final row = (await db.select(db.transactions).get()).single;
      expect(row.id, id);
      expect(row.amount, 12);
      expect(row.nativeAmount, closeTo(snapshot, .00000000001));
      expect(row.note, '只改备注');
      expect(tester.takeException(), isNull);
    });
  }

  recordingTest('共享账本分类使用 Owner 镜像和二级图标，不混入个人分类', (tester) async {
    await db.customStatement(
        "UPDATE ledgers SET is_shared = 1, my_role = 'editor', sync_id = 'shared-1' WHERE id = 1");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories (ledger_sync_id, sync_id, name, kind, icon, level, sort_order, updated_at) VALUES ('shared-1', 'parent', '共享餐饮', 'expense', 'restaurant', 1, 0, 1792713600)");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories (ledger_sync_id, sync_id, name, kind, icon, level, parent_sync_id, sort_order, updated_at) VALUES ('shared-1', 'child', '共享午餐', 'expense', 'restaurant', 2, 'parent', 1, 1792713600)");
    await open(tester);
    expect(find.text('餐饮'), findsNothing);
    await category(tester, syntheticIdForSyncId('parent'));
    expect(find.text('共享午餐'), findsOneWidget);
    await category(tester, syntheticIdForSyncId('child'));
    await key(tester, '5');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.categoryId, isNull);
    expect(saved.categorySyncIdOverride, 'child');
    expect(tester.takeException(), isNull);
  });

  recordingTest('币种弹窗联动账户，横排标签多选与折算真实保存', (tester) async {
    final cnyAccount =
        await repo.createAccount(ledgerId: 1, name: '人民币现金', currency: 'CNY');
    final usdAccount =
        await repo.createAccount(ledgerId: 1, name: '美元现金', currency: 'USD');
    final work = await repo.createTag(name: '工作日', color: '#C99A12');
    final travel = await repo.createTag(name: '旅行', color: '#20A1A1');
    await repo.setOverride(base: 'CNY', quote: 'USD', rate: '7.2');
    await open(tester,
        accountsEnabled: true,
        page: TransactionEditorPage(
            initialKind: 'expense',
            quickAdd: true,
            initialAccountId: cnyAccount));
    await key(tester, '1');
    await key(tester, '0');
    await tester.tap(find.text('CNY'));
    await tester.pumpAndSettle();
    final search = find.descendant(
        of: find.byType(BottomSheet), matching: find.byType(TextField));
    await tester.enterText(search, 'USD');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('(USD)'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('recording-account')));
    await tester.tap(find.byKey(const ValueKey('recording-account')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<AccountSelector>(find.byType(AccountSelector))
            .selectedAccountId,
        isNull);
    expect(
        tester
            .widget<AccountSelector>(find.byType(AccountSelector))
            .filterCurrency,
        'USD');
    expect(find.textContaining('≈ ¥72.00'), findsOneWidget);
    await tester.ensureVisible(find.text('美元现金'));
    await tester.tap(find.text('美元现金'));
    await tester.pumpAndSettle();
    await category(tester, foodId);
    await tester.ensureVisible(find.text('选择标签'));
    await tester.tap(find.text('选择标签'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作日'));
    await tester.tap(find.text('旅行'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await category(tester, foodId);
    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await capture(tester, 'foreign-currency-tags');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.currencyCode, 'USD');
    expect(saved.nativeAmount, 72);
    expect(saved.accountId, usdAccount);
    expect((await repo.getTagsForTransaction(saved.id)).map((tag) => tag.id),
        unorderedEquals([work, travel]));
    expect(tester.takeException(), isNull);
  });

  recordingTest('保存期间防连点，后续写入失败可重试且不重复创建账单', (tester) async {
    final failing = RetryRecordingRepository(db);
    repo = failing;
    final tagId = await repo.createTag(name: '工作日');
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'expense', quickAdd: true, initialTagIds: [tagId]));
    await category(tester, foodId);
    await key(tester, '8');
    await press(tester, 'recording-save');
    for (var i = 0; i < 30 && !failing.started.isCompleted; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(failing.started.isCompleted, isTrue);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('recording-save')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('recording-save')),
        warnIfMissed: false);
    failing.release.complete();
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.byType(AmountEditorSheet), findsOneWidget);
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final transactions = await db.select(db.transactions).get();
    expect(transactions, hasLength(1));
    expect((await repo.getTagsForTransaction(transactions.single.id)).single.id,
        tagId);
    expect(find.text('打开记账'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  recordingTest('减法、除法和清空不丢分类选择', (tester) async {
    await open(tester);
    await category(tester, foodId);
    for (final digit in ['2', '0', '-', '5']) {
      await key(tester, digit);
    }
    await press(tester, 'recording-equals');
    await tester.pump();
    await key(tester, '÷');
    await key(tester, '3');
    await press(tester, 'recording-equals');
    await tester.pump();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '5.00');
    await tester.longPress(find.byKey(const ValueKey('recording-key-⌫')));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('recording-amount')))
            .data,
        '0.00');
    await key(tester, '0');
    await key(tester, '.');
    await key(tester, '1');
    await key(tester, '+');
    await key(tester, '0');
    await key(tester, '.');
    await key(tester, '2');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    expect((await db.select(db.transactions).get()).single.amount, .3);
    expect(tester.takeException(), isNull);
  });

  recordingTest('二级分类自定义图片使用真实图片，缺失图片可回退', (tester) async {
    final temporary = Directory.systemTemp.createTempSync('beecount-v4-icon-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => temporary.path);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      if (temporary.existsSync()) temporary.deleteSync(recursive: true);
    });
    final icons = Directory('${temporary.path}/custom_icons')..createSync();
    File('assets/logo2.png').copySync('${icons.path}/lunch.png');
    await db.customStatement(
        "UPDATE categories SET icon_type = 'custom', custom_icon_path = 'custom_icons/lunch.png' WHERE id = ?",
        [lunchId]);
    await open(tester);
    await category(tester, foodId);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final tile = find.byKey(ValueKey('recording-category-$lunchId'));
    expect(find.descendant(of: tile, matching: find.byType(Image)),
        findsOneWidget);
    final raw = find.descendant(of: tile, matching: find.byType(RawImage));
    for (var frame = 0;
        frame < 20 &&
            (raw.evaluate().isEmpty ||
                tester.widget<RawImage>(raw).image == null);
        frame++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump();
    }
    expect(tester.widget<RawImage>(raw).image, isNotNull);
    await category(tester, lunchId);
    await capture(tester, 'custom-category-image');
    await db.customStatement(
        "UPDATE categories SET custom_icon_path = 'custom_icons/missing.png' WHERE id = ?",
        [lunchId]);
    ProviderScope.containerOf(tester.element(find.byType(AmountEditorSheet)))
        .invalidate(
            recordingCategoriesProvider((ledgerId: 1, kind: 'expense')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final fallback = find.descendant(
        of: tile,
        matching: find
            .byWidgetPredicate((w) => w is BeeLineIcon && w.name == 'Shapes'));
    for (var frame = 0; frame < 10 && fallback.evaluate().isEmpty; frame++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      });
      await tester.pump();
    }
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(398, 844), const Size(320, 568)]) {
    for (final scale in [1.0, 1.4]) {
      recordingTest('折算金额与箭头固定右侧 $size 字号$scale', (tester) async {
        await open(tester,
            size: size,
            textScale: scale,
            page: TransactionEditorPage(
                initialKind: 'expense',
                quickAdd: true,
                initialCategoryId: foodId,
                initialAmount: 12,
                initialCurrencyCode: 'USD',
                initialNativeAmount: 85.2));
        final summary = find.byKey(const ValueKey('recording-conversion'));
        final value = find.byKey(const ValueKey('recording-conversion-value'));
        final arrow =
            find.byKey(const ValueKey('recording-conversion-chevron'));
        void aligned() {
          expect(tester.getRect(arrow).right,
              closeTo(tester.getRect(summary).right, .1));
          expect(tester.getRect(value).right,
              closeTo(tester.getRect(arrow).left - 4, .1));
        }

        aligned();
        expect(find.text('≈ ¥85.20'), findsOneWidget);
        await tester.tap(summary);
        await tester.pumpAndSettle();
        final rate = find.descendant(
            of: find.byType(BeeDialog), matching: find.byType(TextField));
        await tester.enterText(rate, '71000');
        await tester.pump();
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
        expect(find.text('≈ ¥852000.00'), findsOneWidget);
        aligned();
        expect(tester.takeException(), isNull);
      });
    }
  }

  recordingTest('缺失汇率阻止写入，可在弹窗补汇率继续保存', (tester) async {
    await open(tester,
        page: TransactionEditorPage(
            initialKind: 'expense',
            quickAdd: true,
            initialCategoryId: foodId,
            initialAmount: 10,
            initialCurrencyCode: 'USD',
            initialNativeAmount: 0));
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    final hint = find.text('请手动填写本笔汇率后保存').first;
    await tester.ensureVisible(hint);
    await tester.tap(hint);
    await tester.pumpAndSettle();
    final rate = find.descendant(
        of: find.byType(BeeDialog), matching: find.byType(TextField));
    for (final invalid in ['0', '-1', 'NaN', 'Infinity']) {
      await tester.enterText(rate, invalid);
      await tester.pump();
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '确定'))
              .onPressed,
          isNull);
      expect(find.text('请输入大于 0 的有效汇率'), findsOneWidget);
      expect(await db.select(db.transactions).get(), isEmpty);
    }
    await tester.enterText(rate, '7.2');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('≈ ¥72.00'), findsOneWidget);
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.amount, 10);
    expect(saved.nativeAmount, 72);
    expect(saved.currencyCode, 'USD');
    expect(tester.takeException(), isNull);
  });

  recordingTest('原有默认入口直接进入新版完整记账并保存二级分类', (tester) async {
    await open(tester,
        page: const TransactionEditorPage(initialKind: 'expense'));
    expect(find.byKey(const ValueKey('recording-amount')), findsOneWidget);
    await category(tester, foodId);
    await category(tester, lunchId);
    await key(tester, '8');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.amount, 8);
    expect(saved.categoryId, lunchId);
    expect(find.text('打开记账'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  recordingTest('大量二级分类限制两行，内部滚动可选末项且保存区不移动', (tester) async {
    var lastId = lunchId;
    for (var i = 0; i < 16; i++) {
      lastId = await repo.createSubCategory(
          parentId: foodId, name: '子类$i', kind: 'expense', icon: 'restaurant');
    }
    await open(tester);
    final save = find.byKey(const ValueKey('recording-save'));
    final bottom = tester.getBottomRight(save).dy;
    await category(tester, foodId);
    final scroll = find.byKey(const ValueKey('recording-subcategories-scroll'));
    expect(tester.getSize(scroll).height, 92);
    await tester.drag(scroll, const Offset(0, -500));
    await tester.pumpAndSettle();
    final last = find.byKey(ValueKey('recording-category-$lastId'));
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(tester.getBottomRight(save).dy, bottom);
    await key(tester, '1');
    await press(tester, 'recording-save');
    await tester.pumpAndSettle();
    final saved = (await db.select(db.transactions).get()).single;
    expect(saved.categoryId, lastId);
    expect(tester.takeException(), isNull);
  });

  for (final skin in ['none', 'anniversary', 'anniv_cake']) {
    recordingTest('整页皮肤 $skin 可以透过键盘间隙，固定保存区仍可操作', (tester) async {
      await open(tester, skin: skin);
      final dock = find.byKey(const ValueKey('recording-dock'));
      final material = tester.widget<Material>(
          find.ancestor(of: dock, matching: find.byType(Material)).first);
      expect(material.color, Colors.transparent, reason: '不再用实色画布遮住整页动态背景');
      final save = find.byKey(const ValueKey('recording-save'));
      final before = tester.getRect(save);
      await category(tester, foodId);
      await key(tester, '1');
      expect(tester.getRect(save), before);
      await press(tester, 'recording-save');
      await tester.pumpAndSettle();
      expect((await repo.getTransactionsByLedger(1)).single.amount, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    recordingTest('键盘与保存固定底部，分类展开和滚动不移动 $size', (tester) async {
      await open(tester, size: size);
      final save = find.byKey(const ValueKey('recording-save'));
      final keypad = find.byKey(const ValueKey('recording-key-7'));
      final bottom = tester.getBottomRight(save).dy;
      final keypadY = tester.getCenter(keypad).dy;
      expect(bottom, closeTo(size.height - 12, .01));
      await category(tester, foodId);
      await tester.drag(find.byKey(const ValueKey('recording-content')),
          const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(save).dy, bottom);
      expect(tester.getCenter(keypad).dy, keypadY);
      final note = find.byKey(ValueKey(
          size.height < 720 ? 'recording-note-compact' : 'recording-note'));
      await tester.ensureVisible(note);
      await tester.tap(note);
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 1);
      await tester.pumpAndSettle();
      expect(keypad, findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(keypad, findsNothing);
      expect(
          tester.getBottomRight(save).dy, closeTo(size.height - 250 - 12, .01));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(keypad, findsOneWidget);
      expect(tester.getBottomRight(save).dy, bottom);
      expect(tester.takeException(), isNull);
    });
  }

  for (final profile in [
    (size: const Size(375, 667), scale: 1.0),
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(375, 667), scale: 1.4),
    (size: const Size(320, 568), scale: 1.4)
  ]) {
    final size = profile.size;
    recordingTest('短屏含安全区 $size 字号${profile.scale}：金额常驻及快捷入口可达',
        (tester) async {
      await open(tester,
          size: size,
          safeTop: 20,
          accountsEnabled: true,
          textScale: profile.scale);
      await key(tester, '3');
      await key(tester, '2');
      await category(tester, foodId);
      final amount = find.byKey(const ValueKey('recording-amount'));
      final amountRect = tester.getRect(amount);
      final area = find.byKey(const ValueKey('recording-content'));
      await tester.drag(area, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(tester.getRect(amount), amountRect);
      expect(amountRect.top, greaterThanOrEqualTo(64));
      expect(amountRect.bottom, lessThan(tester.getRect(area).top));
      await capture(tester,
          'short-${size.width.toInt()}x${size.height.toInt()}-${profile.scale}-initial');
      final save = find.byKey(const ValueKey('recording-save'));
      final bottom = tester.getBottomRight(save).dy;
      final date = find.byKey(const ValueKey('recording-date'));
      await tester.ensureVisible(date);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(save).dy, bottom);
      await capture(tester,
          'short-${size.width.toInt()}x${size.height.toInt()}-${profile.scale}-metadata');
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  for (final config in [
    (name: 'light', size: const Size(390, 844), brightness: Brightness.light),
    (name: 'dark', size: const Size(390, 844), brightness: Brightness.dark),
    (name: 'compact', size: const Size(320, 568), brightness: Brightness.light),
  ]) {
    recordingTest('布局与滚轮日期 ${config.name}', (tester) async {
      await open(tester, size: config.size, brightness: config.brightness);
      await key(tester, '3');
      await key(tester, '2');
      await capture(tester, '${config.name}-unselected');
      await category(tester, foodId);
      await capture(tester, '${config.name}-subcategory');
      await category(tester, foodId);
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      await capture(tester, config.name);
      final date = find.byKey(const ValueKey('recording-date'));
      await tester.ensureVisible(date);
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.byType(ListWheelScrollView), findsWidgets);
      await capture(tester, '${config.name}-date');
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:beecount/cloud/sync_service.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/data/repositories/transaction_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/data/import_page.dart';
import 'package:beecount/pages/data/import_confirm_page.dart';
import 'package:beecount/pages/data/import/bindings/import_confirm_controls.dart';
import 'package:beecount/dev/component_gallery/bindings/import_context_preview.dart';
import 'package:beecount/dev/component_gallery/import_flow_sample.dart';
import 'package:beecount/providers.dart';
import 'package:beecount_business_ui/transaction_import.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Picker extends FilePicker {
  FilePickerResult? result;
  Exception? error;
  List<String>? extensions;
  bool? requestedData;
  int calls = 0;
  @override
  Future<bool?> clearTemporaryFiles() async => true;
  @override
  Future<FilePickerResult?> pickFiles(
      {String? dialogTitle,
      String? initialDirectory,
      FileType type = FileType.any,
      List<String>? allowedExtensions,
      Function(FilePickerStatus)? onFileLoading,
      bool allowCompression = true,
      int compressionQuality = 30,
      bool allowMultiple = false,
      bool withData = false,
      bool withReadStream = false,
      bool lockParentWindow = false,
      bool readSequential = false}) async {
    calls++;
    extensions = allowedExtensions;
    requestedData = withData;
    if (error != null) throw error!;
    return result;
  }
}

class _Repository extends LocalRepository {
  _Repository(super.db);
  Completer<void>? writeGate;
  bool writeStarted = false;
  bool failWrite = false;
  @override
  Future<List<int>> insertTransactionsBatchWithRelations({
    required List<TransactionsCompanion> transactions,
    Map<int, List<int>> tagIdsByIndex = const {},
    Map<int, List<BatchAttachmentData>> attachmentsByIndex = const {},
    bool recordChanges = true,
  }) async {
    writeStarted = true;
    if (failWrite) throw StateError('QA import batch write failed');
    if (writeGate != null) await writeGate!.future;
    return super.insertTransactionsBatchWithRelations(
        transactions: transactions,
        tagIdsByIndex: tagIdsByIndex,
        attachmentsByIndex: attachmentsByIndex,
        recordChanges: recordChanges);
  }
}

const _header = '日期,类型,金额,币种,分类,二级分类,账户,转出账户,转入账户,备注,标签,附件';
const _row =
    '2026-10-20,支出,32.50,CNY,QA 餐饮,QA 午餐,QA 现金,,,QA 备注,QA 标签,receipt.jpg';
const _csv = '$_header\n$_row';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BeeDatabase db;
  late _Repository repo;
  late _Picker picker;
  final l = AppLocalizationsEn();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    picker = _Picker();
    FilePicker.platform = picker;
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = _Repository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA import','CNY')");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind) VALUES(9,'QA 餐饮','expense'),(10,'QA 工资','income')");
  });
  tearDown(() async => db.close());

  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      try {
        await body(t);
      } finally {
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pump(const Duration(seconds: 6));
      }
    });
  }

  Widget host(Widget child, {Brightness brightness = Brightness.light}) =>
      ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            databaseProvider.overrideWithValue(db),
            currentLedgerIdProvider.overrideWith((ref) => 1),
            syncServiceProvider.overrideWithValue(LocalOnlySyncService())
          ],
          child: MaterialApp(
              theme: beeTheme(brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: child));
  Widget confirm(String csv,
          {BillSourceType source = BillSourceType.generic,
          bool header = true}) =>
      ImportConfirmPage(csvText: csv, hasHeader: header, billType: source);
  Future<void> waitParsing(WidgetTester t) async {
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await t.pump(const Duration(milliseconds: 30));
      if (find.byType(BeeImportMappingField<int>).evaluate().isNotEmpty) return;
    }
    fail('CSV isolate did not finish');
  }

  Future<void> flush(WidgetTester t, {int cycles = 10}) async {
    for (var i = 0; i < cycles; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> next(WidgetTester t) async {
    await t.tap(find.text(l.importNextStep));
    await flush(t, cycles: 3);
  }

  Future<void> chooseAndConfirm(WidgetTester t, {String csv = _csv}) async {
    picker.result = FilePickerResult([
      PlatformFile(
          name: 'qa.csv',
          size: utf8.encode(csv).length,
          bytes: Uint8List.fromList(utf8.encode(csv)))
    ]);
    await t.pumpWidget(host(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => const ImportPage())),
                child: const Text('Open import'))))));
    await t.tap(find.text('Open import'));
    await t.pumpAndSettle();
    await t.tap(find.text(l.importChooseFile).last);
    await flush(t);
    await waitParsing(t);
    await next(t);
  }

  for (final brightness in Brightness.values) {
    scenario('纯导入组件320与1.4字号长文本无溢出 $brightness', (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: brightness),
          home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(17),
                      child: Column(children: [
                        const BeeImportSteps(
                            labels: ['选择文件及来源', '确认全部字段映射', '检查分类映射'],
                            current: 1),
                        const SizedBox(height: 12),
                        BeeImportSection(
                            child: BeeImportFileChoice(
                                fileName:
                                    'very-long-wechat-bill-name-2026-10-20.csv',
                                description: 'CSV · TSV · TXT · XLSX',
                                chooseLabel: '选择一个账单文件',
                                onChoose: () {})),
                        const SizedBox(height: 12),
                        BeeImportSection(
                            child: BeeImportMappingField<int>(
                                label: 'A long source category name',
                                value: 0,
                                options: const [
                                  BeeImportOption(0,
                                      'A very long destination category with parent')
                                ],
                                onChanged: (_) {})),
                        const SizedBox(height: 12),
                        const BeeImportSection(
                            child: BeeImportPreviewTable(rows: [
                          ['Date', 'Type', 'Amount'],
                          ['2026-10-20', 'Expense', '32.50']
                        ])),
                      ]))))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  scenario('画廊受控示例选择文件、字段及分类不调用平台', (t) async {
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: ImportFlowSample()))));
    await t.tap(find.text(l.importChooseFile).last);
    await t.pumpAndSettle();
    expect(find.text('example.csv'),
        findsNothing); // field stage replaces file slot
    expect(find.byType(BeeImportMappingField<int>), findsOneWidget);
    await t.ensureVisible(find.text(l.importNextStep));
    await t.tap(find.text(l.importNextStep));
    await t.pumpAndSettle();
    expect(find.byType(BeeImportMappingField<int?>), findsOneWidget);
    expect(picker.calls, 0);
  });

  scenario('画廊真实绑定读取当前账本和账户但不导入', (t) async {
    await repo.createAccount(
        ledgerId: 1, name: 'QA USD account', type: 'cash', currency: 'USD');
    await t.pumpWidget(host(const Scaffold(
        body: SingleChildScrollView(child: LiveImportContextPreview()))));
    await flush(t);
    expect(find.text('QA import'), findsOneWidget);
    expect(find.text('QA USD account · USD'), findsOneWidget);
    expect(picker.calls, 0);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('默认通用CSV及原四种后缀、取消文件选择不导航', (t) async {
    await t.pumpWidget(host(const ImportPage()));
    final chips = t.widgetList<ChoiceChip>(find.byType(ChoiceChip)).toList();
    expect(chips.length, 3);
    expect(chips.first.selected, isTrue);
    await t.tap(find.text(l.importBillTypeWechat));
    await t.pump();
    await t.tap(find.text(l.importChooseFile).last);
    await t.pumpAndSettle();
    expect(picker.extensions, ['csv', 'tsv', 'txt', 'xlsx']);
    expect(picker.requestedData, isTrue);
    expect(find.byType(ImportConfirmControls), findsNothing);
    expect(t.widgetList<ChoiceChip>(find.byType(ChoiceChip)).last.selected,
        isTrue);
  });

  scenario('文件选择异常保留来源与错误流程', (t) async {
    picker.error = Exception('QA picker failure');
    await t.pumpWidget(host(const ImportPage()));
    await t.tap(find.text(l.importBillTypeAlipay));
    await t.pump();
    await t.tap(find.text(l.importChooseFile).last);
    await t.pump();
    expect(find.textContaining('QA picker failure'), findsOneWidget);
    expect(find.byType(ImportConfirmControls), findsNothing);
  });

  scenario('系统适配器的内存文件进入真实确认页，12字段均自动映射', (t) async {
    await chooseAndConfirm(t);
    await t.tap(find.text(l.importPreviousStep));
    await t.pump();
    final fields = t
        .widgetList<BeeImportMappingField<int>>(
            find.byType(BeeImportMappingField<int>))
        .toList();
    expect(fields.length, 12);
    expect(fields.map((f) => f.value).toList(), List.generate(12, (i) => i));
    expect(find.byType(ImportConfirmPage), findsOneWidget);
    expect((await db.select(db.transactions).get()), isEmpty);
  });

  scenario('空CSV保留原空数据提示且不再访问不存在的预览表头', (t) async {
    await t.pumpWidget(host(confirm('')));
    await waitParsing(t);
    expect(find.text(l.importNoDataParsed), findsOneWidget);
    expect(
        t
            .widget<BeeImportPreviewTable>(find.byType(BeeImportPreviewTable))
            .rows,
        isEmpty);
    expect(t.takeException(), isNull);
  });

  scenario('原始预览上限10行，含表头、长文件不全量渲染', (t) async {
    await t.pumpWidget(
        host(confirm('$_header\n${List.filled(25, _row).join('\n')}')));
    await waitParsing(t);
    final preview =
        t.widget<BeeImportPreviewTable>(find.byType(BeeImportPreviewTable));
    expect(preview.rows.length, 10);
    expect(preview.rows.first.first, '日期');
    expect(preview.rows.last[9], 'QA 备注');
    expect(find.text(l.importPreviewLimit(10, 26)), findsOneWidget);
  });

  for (final source in [BillSourceType.alipay, BillSourceType.wechat]) {
    scenario('专用解析器保留前言表头识别 $source', (t) async {
      final name = source == BillSourceType.alipay ? '商品说明' : '交易类型';
      final csv = 'QA导出说明\n交易时间,$name,金额,收支\n2026-10-20,QA餐饮,12,支出';
      await t.pumpWidget(host(confirm(csv, source: source)));
      await waitParsing(t);
      final preview =
          t.widget<BeeImportPreviewTable>(find.byType(BeeImportPreviewTable));
      expect(preview.rows.first.first, '交易时间');
      expect(preview.rows.length, 2);
      final date = t.widget<BeeImportMappingField<int>>(
          find.byKey(const ValueKey('import-field-date')));
      expect(date.value, 0);
    });
  }

  scenario('公开无表头入口仍可手动映射', (t) async {
    await t.pumpWidget(host(confirm(_row, header: false)));
    await waitParsing(t);
    final fields = t.widgetList<BeeImportMappingField<int>>(
        find.byType(BeeImportMappingField<int>));
    expect(fields.every((f) => f.value == null), isTrue);
    expect(fields.first.options.first.label, l.importColumnNumber(1));
    expect(
        t
            .widget<BeeImportPreviewTable>(find.byType(BeeImportPreviewTable))
            .hasHeader,
        isFalse);
  });

  scenario('缺少分类及转账字段时沿用下一步校验且不写入', (t) async {
    await t.pumpWidget(host(confirm('日期,类型,金额\n2026-10-20,支出,10')));
    await waitParsing(t);
    await next(t);
    expect(find.text(l.importSelectCategoryFirst), findsOneWidget);
    expect(find.byType(BeeImportMappingField<int?>), findsNothing);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('分类自动匹配现有ID，上一页保留字段映射', (t) async {
    await t.pumpWidget(host(confirm(_csv)));
    await waitParsing(t);
    await next(t);
    final field = t.widget<BeeImportMappingField<int?>>(
        find.byType(BeeImportMappingField<int?>));
    expect(field.label, 'QA 餐饮');
    expect(field.value, 9);
    expect(
        field.options
            .any((o) => o.value == null && o.label == l.importKeepOriginalName),
        isTrue);
    await t.tap(find.text(l.importPreviousStep));
    await t.pump();
    expect(
        t
            .widget<BeeImportMappingField<int>>(
                find.byKey(const ValueKey('import-field-currency')))
            .value,
        3);
  });

  scenario('账户币种预检取消不创建数据，保留映射页重试', (t) async {
    await t.pumpWidget(host(confirm(_csv)));
    await waitParsing(t);
    await next(t);
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    expect(find.text(l.importAccountCurrencyPreview), findsOneWidget);
    expect(find.text('QA 现金 · CNY'), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await repo.getAllAccounts(), isEmpty);
    expect(
        t
            .widget<BeeButton>(
                find.widgetWithText(BeeButton, l.importStartImport))
            .onPressed,
        isNotNull);
  });

  scenario('币种正则校验错误在写入前拒绝且可回退', (t) async {
    await t.pumpWidget(
        host(confirm(_csv.replaceFirst('32.50,CNY', '32.50,?bad'))));
    await waitParsing(t);
    await next(t);
    await t.tap(find.text(l.importStartImport));
    await flush(t, cycles: 3);
    expect(find.textContaining(l.importCurrencyInvalid), findsOneWidget);
    expect(find.text(l.importAccountCurrencyPreview), findsNothing);
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('仅转账无分类列直接进入账户币种预检', (t) async {
    await t.pumpWidget(
        host(confirm('日期,类型,金额,转出账户,转入账户\n2026-10-20,转账,50,QA A,QA B')));
    await waitParsing(t);
    await next(t);
    expect(find.text(l.importAccountCurrencyPreview), findsOneWidget);
    expect(find.text('QA A · CNY'), findsOneWidget);
    expect(find.text('QA B · CNY'), findsOneWidget);
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
  });

  scenario('真实本地服务写入金额、币种、子分类、账户、备注、标签及附件名', (t) async {
    await chooseAndConfirm(t);
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.importStartImport).last);
    await flush(t, cycles: 20);
    await t.pump(const Duration(seconds: 6));
    final txs = await db.select(db.transactions).get();
    expect(txs.length, 1);
    final tx = txs.single;
    expect(tx.type, 'expense');
    expect(tx.amount, 32.5);
    expect(tx.currencyCode, 'CNY');
    expect(tx.note, 'QA 备注');
    expect(tx.ledgerId, 1);
    final child = (await repo.getSubCategories(9)).single;
    expect(child.name, 'QA 午餐');
    expect(tx.categoryId, child.id);
    expect(tx.accountId, (await repo.getAllAccounts()).single.id);
    expect((await repo.getAllTags()).single.name, 'QA 标签');
    expect((await db.select(db.transactionTags).get()).single.transactionId,
        tx.id);
    expect((await db.select(db.transactionAttachments).get()).single.fileName,
        'receipt.jpg');
    expect(find.text('Open import'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  scenario('未知类型跳过后显示详细结果并等待确认', (t) async {
    await chooseAndConfirm(t,
        csv: '$_csv\n2026-10-21,不计收支,10,CNY,QA 餐饮,,QA 现金,,,跳过,,');
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.importStartImport).last);
    await flush(t, cycles: 20);
    expect(find.text(l.importCompleteTitle), findsOneWidget);
    expect(find.textContaining(l.importSkippedNonTransactionTypes(1)),
        findsOneWidget);
    expect((await db.select(db.transactions).get()).length, 1);
    await t.tap(find.text(l.commonConfirm));
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
  });

  scenario('真实服务批次失败显示失败数，保留账户等原有分阶段写入语义', (t) async {
    repo.failWrite = true;
    await chooseAndConfirm(t);
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.importStartImport).last);
    await flush(t, cycles: 20);
    expect(find.text(l.importCompleteTitle), findsOneWidget);
    expect(find.text(l.importCompleted('', 1, 0)), findsOneWidget);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect((await repo.getAllAccounts()).length, 1);
    await t.tap(find.text(l.commonConfirm));
    await t.pump(const Duration(seconds: 6));
    await t.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
  });

  scenario('后台导入退出两级页面后真实服务继续完成并更新全局进度', (t) async {
    repo.writeGate = Completer<void>();
    await chooseAndConfirm(t);
    final container = ProviderScope.containerOf(
        t.element(find.byType(ImportConfirmControls)));
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.importStartImport).last);
    await flush(t);
    expect(repo.writeStarted, isTrue);
    await t.tap(find.text(l.importBackgroundImport));
    await t.pumpAndSettle();
    expect(find.text('Open import'), findsOneWidget);
    expect(container.read(importProgressProvider).running, isTrue);
    repo.writeGate!.complete();
    await flush(t, cycles: 20);
    expect((await db.select(db.transactions).get()).length, 1);
    expect(container.read(importProgressProvider).running, isFalse);
    expect(container.read(importProgressProvider).ok, 1);
    await t.pump(const Duration(seconds: 6));
    expect(t.takeException(), isNull);
  });

  scenario('原取消仅关闭进度，执行中的真实本地批次仍可能继续写入', (t) async {
    repo.writeGate = Completer<void>();
    await chooseAndConfirm(t);
    await t.tap(find.text(l.importStartImport));
    await flush(t);
    await t.tap(find.widgetWithText(FilledButton, l.importStartImport).last);
    await flush(t);
    expect(repo.writeStarted, isTrue);
    expect(find.text(l.importCancelImport), findsOneWidget);
    await t.tap(find.text(l.importCancelImport));
    await t.pumpAndSettle();
    expect(await db.select(db.transactions).get(), isEmpty);
    repo.writeGate!.complete();
    await flush(t, cycles: 20);
    expect((await db.select(db.transactions).get()).length, 1);
    expect(find.text('Open import'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

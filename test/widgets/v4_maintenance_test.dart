import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/pages/settings/log_center_page.dart';
import 'package:beecount/pages/settings/storage_management_page.dart';
import 'package:beecount/pages/settings/widget_management_page.dart';
import 'package:beecount/pages/maintenance/orphan_cleanup_page.dart';
import 'package:beecount/presentation/v4/bindings/maintenance_access.dart';
import 'package:beecount/presentation/v4/bindings/maintenance_preview.dart';
import 'package:beecount/presentation/v4/gallery/maintenance_sample.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/maintenance_providers.dart';
import 'package:beecount/services/maintenance/orphan_scanner.dart';
import 'package:beecount/services/maintenance/orphan_cleaner.dart';
import 'package:beecount/services/maintenance/orphan_record.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:beecount_business_ui/maintenance.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Scanner extends OrphanScanner {
  _Scanner(
      {required super.db,
      required super.attachmentsDirOverride,
      required super.iconsDirOverride,
      required super.l10n});
  bool fail = false;
  int scans = 0;
  Completer<void>? gate;
  @override
  Future<OrphanScanReport> scanAll() async {
    scans++;
    await gate?.future;
    if (fail) throw StateError('Owned scan failed');
    return super.scanAll();
  }
}

class _Cleaner extends OrphanCleaner {
  _Cleaner({required super.db});
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<OrphanCleanResult> clean(List<OrphanRecord> records) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('Owned clean failed');
    return super.clean(records);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsEn();
  late BeeDatabase db;
  late LocalRepository repo;
  late Directory owned, docs, external, attachments, icons;
  late _Scanner scanner;
  late _Cleaner cleaner;
  late LoggerService source;
  late SharedPreferences prefs;
  late List<LogEntry> logs;
  bool scanError = false, deleteFailure = false, noExternal = false;
  int deletes = 0;
  Completer<void>? deleteGate;
  setUp(() async {
    logs = [
      for (var i = 0; i < 12; i++)
        LogEntry(
            timestamp:
                DateTime.now().subtract(Duration(minutes: 2, seconds: 12 - i)),
            level: LogLevel.values[i % 4],
            platform: LogPlatform.values[i ~/ 4],
            tag: 'CaseTag$i',
            message: 'Owned message $i',
            error: i == 3 ? 'Owned error detail' : null,
            stackTrace:
                i == 3 ? StackTrace.fromString('owned stack line') : null)
    ];
    SharedPreferences.setMockInitialValues({
      'app_logs': jsonEncode(logs.map((x) => x.toJson()).toList()),
      'unrelated': 'keep'
    });
    prefs = await SharedPreferences.getInstance();
    source =
        LoggerService.forTesting(getPreferences: () => Future.value(prefs));
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    owned =
        await Directory.systemTemp.createTemp('beecount-r103-widget-owned-');
    docs = await Directory('${owned.path}/docs').create();
    external = await Directory('${owned.path}/external').create();
    attachments = await Directory('${docs.path}/attachments').create();
    icons = await Directory('${docs.path}/custom_icons').create();
    final models = await Directory('${docs.path}/ai_models').create();
    for (final entry
        in {'one.tflite': 4, 'two.tflite': 6, 'unrelated.bin': 3}.entries) {
      await File('${models.path}/${entry.key}')
          .writeAsBytes(List.filled(entry.value, 1));
    }
    await Directory('${models.path}/nested').create();
    await File('${models.path}/nested/nested.tflite').writeAsBytes([8]);
    await File('${external.path}/BeeCount_owned.apk').writeAsBytes([1, 2, 3]);
    await File('${external.path}/other.apk').writeAsBytes([4]);
    await File('${external.path}/BeeCount_upper.APK').writeAsBytes([5]);
    for (final entry
        in {'keep.jpg': 4, 'dangling.jpg': 5, 'orphan.jpg': 7}.entries) {
      await File('${attachments.path}/${entry.key}')
          .writeAsBytes(List.filled(entry.value, 2));
    }
    for (final entry in {
      'keep_icon.png': 2,
      'orphan_icon.png': 3,
      'shared_used.png': 2,
      'shared_unused.png': 4
    }.entries) {
      await File('${icons.path}/${entry.key}')
          .writeAsBytes(List.filled(entry.value, 3));
    }
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'Owned book','CNY'),(2,'Other owned book','USD')");
    await db.customStatement(
        "INSERT INTO accounts(id,ledger_id,name,currency,initial_balance) VALUES(1,0,'Owned account','USD',100)");
    await db.customStatement(
        "INSERT INTO categories(id,name,kind,icon_type,custom_icon_path,level,parent_id) VALUES(1,'Owned category','expense','custom','custom_icons/keep_icon.png',1,NULL),(2,'Missing parent','expense','material',NULL,2,999)");
    await db.customStatement("INSERT INTO tags(id,name) VALUES(1,'Owned tag')");
    await db.customStatement(
        "INSERT INTO transactions(id,ledger_id,type,amount,happened_at,sync_id,account_id,category_id,currency_code,native_amount,note,exclude_from_stats,exclude_from_budget) VALUES(1,1,'expense',12,1792454400,'tx1',1,1,'USD',86.4,'keep private one',1,1),(2,2,'income',25,1792454400,'tx2',1,1,'USD',25,'keep private two',0,0),(3,1,'expense',47,1792454400,'tx3',999,999,'CNY',47,'keep broken foreign keys',0,1)");
    await db.customStatement(
        "INSERT INTO transaction_attachments(id,transaction_id,file_name) VALUES(1,1,'keep.jpg'),(2,2,'keep.jpg'),(3,999,'dangling.jpg')");
    await db.customStatement(
        "INSERT INTO transaction_tags(transaction_id,tag_id) VALUES(1,1),(2,1),(999,1),(1,999)");
    await db.customStatement(
        "INSERT INTO budgets(id,ledger_id,type,amount,category_id) VALUES(1,999,'total',10,NULL),(2,1,'category',20,999),(3,2,'total',30,NULL)");
    await db.customStatement(
        "INSERT INTO shared_ledger_categories(ledger_sync_id,sync_id,name,kind,level,parent_sync_id,icon_cloud_sha256,updated_at) VALUES('shared','used','Used shared','expense',1,NULL,'used',1792454400),('shared','missing-parent','Missing shared parent','expense',2,'gone',NULL,1792454400)");
    await db.customStatement(
        "INSERT INTO transaction_tag_overrides(transaction_sync_id,tag_sync_id,created_at) VALUES('gone-tx','orphan-tag',1792454400),('tx1','keep-shared-tag',1792454400)");
    await db.customStatement(
        "INSERT INTO local_changes(id,entity_type,entity_id,entity_sync_id,ledger_id,action) VALUES(10,'transaction',999,'gone-sync',1,'update')");
    scanner = _Scanner(
        db: db,
        attachmentsDirOverride: attachments.path,
        iconsDirOverride: icons.path,
        l10n: () => l);
    cleaner = _Cleaner(db: db);
    scanError = false;
    noExternal = false;
    deleteFailure = false;
    deletes = 0;
    deleteGate = null;
  });
  tearDown(() async {
    source.disposeForTesting();
    await db.close();
    await owned.delete(recursive: true);
  });
  void scenario(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (t) async {
      source =
          LoggerService.forTesting(getPreferences: () => Future.value(prefs));
      try {
        await body(t);
      } finally {
        for (final gate in [scanner.gate, cleaner.gate, deleteGate]) {
          if (gate != null && !gate.isCompleted) gate.complete();
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
        await t.pumpAndSettle();
        await t.pump(const Duration(seconds: 6));
        await source.waitForPendingWorkForTesting();
      }
    });
  }

  Widget host(Widget page,
          {TargetPlatform platform = TargetPlatform.android,
          Brightness brightness = Brightness.light,
          double scale = 1}) =>
      ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            repositoryProvider.overrideWithValue(repo),
            orphanScannerProvider.overrideWithValue(scanner),
            orphanCleanerProvider.overrideWithValue(cleaner),
            maintenancePlatformProvider.overrideWithValue(platform),
            maintenanceLoggerProvider.overrideWithValue(source),
            maintenanceStorageAccessProvider
                .overrideWithValue(MaintenanceStorageAccess(
                    documents: () async {
                      if (scanError) throw StateError('Owned scan failed');
                      return docs;
                    },
                    external: () async => noExternal ? null : external,
                    deleteFile: (file) async {
                      expect(file.path, startsWith(owned.path));
                      deletes++;
                      await deleteGate?.future;
                      if (deleteFailure && deletes == 2) {
                        throw FileSystemException(
                            'Owned delete failed', file.path);
                      }
                      await file.delete();
                    }))
          ],
          child: MaterialApp(
              theme: beeTheme(brightness: brightness),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: page));
  Future<void> flush(WidgetTester t, {int cycles = 24}) async {
    for (var i = 0; i < cycles; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await t.pump(const Duration(milliseconds: 40));
    }
  }

  Future<void> show(WidgetTester t, Widget page,
      {TargetPlatform platform = TargetPlatform.android}) async {
    await t.pumpWidget(host(page, platform: platform));
    await flush(t);
  }

  Future<void> reveal(WidgetTester t, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await t.scrollUntilVisible(finder, 260,
          scrollable: find.byType(Scrollable).first);
    } else {
      await t.ensureVisible(finder);
    }
    await flush(t);
  }

  Future<void> tap(WidgetTester t, String text) async {
    final base = find.text(text);
    if (base.evaluate().isEmpty) await reveal(t, base);
    final f = base.last;
    await reveal(t, f);
    await t.tap(f);
    await flush(t);
  }

  Future<void> action(WidgetTester t, String tooltip) async {
    final f = find.byTooltip(tooltip).last;
    await reveal(t, f);
    await t.tap(f);
    await flush(t);
  }

  Future<Map<String, Object?>> snapshot() async {
    final out = <String, Object?>{};
    for (final table in [
      'ledgers',
      'transactions',
      'accounts',
      'categories',
      'tags',
      'budgets',
      'transaction_tags',
      'transaction_attachments',
      'transaction_tag_overrides',
      'shared_ledger_categories',
      'local_changes'
    ]) {
      out[table] =
          (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
              .map((x) => x.data)
              .toList();
    }
    for (final f in await owned
        .list(recursive: true, followLinks: false)
        .where((e) => e is File)
        .cast<File>()
        .toList()) {
      out[f.path] = await f.readAsBytes();
    }
    return out;
  }

  Future<void> selectAll(WidgetTester t) async {
    await t.tap(find.widgetWithText(BeeButton, l.maintenanceOrphanSelectAll));
    await flush(t);
  }

  Future<T> io<T extends Object>(
          WidgetTester t, Future<T> Function() operation) async =>
      (await t.runAsync(operation))!;
  scenario('日志四级别三来源均保留，最新在前并响应真实日志监听', (t) async {
    await show(t, const LogCenterPage(), platform: TargetPlatform.macOS);
    expect(find.byType(BeeChoiceChip), findsNWidgets(7));
    expect(find.text('${l.logCenterFiltered}: 12'), findsOneWidget);
    source.info('new-owned', 'New owned log');
    await flush(t);
    expect(find.text('${l.logCenterFiltered}: 13'), findsOneWidget);
    expect(
        t
            .widgetList<BeeMaintenanceLogCard>(
                find.byType(BeeMaintenanceLogCard))
            .first
            .message,
        'New owned log');
    expect(
        t
            .widgetList<BeeMaintenanceLogCard>(
                find.byType(BeeMaintenanceLogCard))
            .first
            .levelColor,
        Colors.blue);
  });
  scenario('日志级别及来源多选允许清空并按交集过滤', (t) async {
    await show(t, const LogCenterPage(), platform: TargetPlatform.macOS);
    for (final level in LogLevel.values) {
      await t.tap(find.byKey(ValueKey('maintenance-level-${level.name}')));
      await flush(t);
    }
    expect(find.text(l.logCenterEmpty), findsOneWidget);
    for (final level in [LogLevel.debug, LogLevel.warning]) {
      await t.tap(find.byKey(ValueKey('maintenance-level-${level.name}')));
      await flush(t);
    }
    expect(find.text('${l.logCenterFiltered}: 6'), findsOneWidget);
    for (final platform in [LogPlatform.android, LogPlatform.ios]) {
      await t.tap(find.byKey(ValueKey('maintenance-source-${platform.name}')));
      await flush(t);
    }
    expect(find.text('${l.logCenterFiltered}: 2'), findsOneWidget);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    scenario('日志${platform.name}仅隐藏对方平台筛选入口仍保留原默认所有来源', (t) async {
      await show(t, const LogCenterPage(), platform: platform);
      expect(find.byType(BeeChoiceChip), findsNWidgets(6));
      expect(
          find.byKey(ValueKey(
              'maintenance-source-${platform == TargetPlatform.android ? 'ios' : 'android'}')),
          findsNothing);
      expect(find.text('${l.logCenterFiltered}: 12'), findsOneWidget);
    });
  }
  for (final brightness in Brightness.values) {
    for (final accent in [const Color(0xfffacb16), const Color(0xff219670)]) {
      scenario('日志compact标签跟随主题${brightness.name} ${accent.hashCode}',
          (t) async {
        await t.pumpWidget(MaterialApp(
            theme: beeTheme(brightness: brightness, accent: accent),
            home: Scaffold(
                body: BeeMaintenanceLogFilters(
                    levelLabel: 'Level',
                    sourceLabel: 'Source',
                    levels: [
                  BeeMaintenanceFilterChoice(
                      key: const ValueKey('compact-on'),
                      label: 'DEBUG',
                      selected: true,
                      onSelected: (_) {}),
                  BeeMaintenanceFilterChoice(
                      key: const ValueKey('compact-off'),
                      label: 'INFO',
                      selected: false,
                      onSelected: (_) {})
                ],
                    sources: const []))));
        await t.pumpAndSettle();
        Material visual(Key key) => t.widget<Material>(find.descendant(
            of: find.byKey(key),
            matching: find.byKey(const ValueKey('bee-choice-chip-visual'))));
        expect(visual(const ValueKey('compact-on')).color,
            accent.withValues(alpha: .14));
        expect(
            (visual(const ValueKey('compact-on')).shape!
                    as RoundedRectangleBorder)
                .side
                .color,
            accent);
        expect(visual(const ValueKey('compact-off')).color,
            BeeCardTheme.fromBrightness(brightness).soft);
        for (final chip
            in t.widgetList<BeeChoiceChip>(find.byType(BeeChoiceChip))) {
          expect(chip.compact, isTrue);
        }
      });
    }
  }
  scenario('日志compact多选受控回调允许零选并保留checked语义', (t) async {
    final semantics = t.ensureSemantics();
    try {
      final levels = <String>{'DEBUG', 'INFO', 'WARN', 'ERROR'},
          sources = <String>{'Flutter', 'Android'};
      final events = <String>[];
      var acceptChanges = false;
      await t.pumpWidget(MaterialApp(
          theme: beeTheme(),
          home: Scaffold(body: StatefulBuilder(builder: (context, update) {
            List<BeeMaintenanceFilterChoice> choices(
                    List<String> labels, Set<String> selected) =>
                labels
                    .map((label) => BeeMaintenanceFilterChoice(
                        key: ValueKey('controlled-$label'),
                        label: label,
                        selected: selected.contains(label),
                        onSelected: (value) {
                          events.add('$label=$value');
                          if (acceptChanges) {
                            update(() => value
                                ? selected.add(label)
                                : selected.remove(label));
                          }
                        }))
                    .toList();
            return BeeMaintenanceLogFilters(
                levelLabel: 'Level',
                sourceLabel: 'Source',
                levels: choices(['DEBUG', 'INFO', 'WARN', 'ERROR'], levels),
                sources: choices(['Flutter', 'Android'], sources));
          }))));
      await t.pumpAndSettle();
      final debug = find.byKey(const ValueKey('controlled-DEBUG'));
      expect(t.getSemantics(debug).hasFlag(ui.SemanticsFlag.isChecked), isTrue);
      expect(
          t.getSemantics(debug).hasFlag(ui.SemanticsFlag.isSelected), isFalse);
      await t.tap(debug);
      await t.pump();
      expect(events, ['DEBUG=false']);
      expect(t.widget<BeeChoiceChip>(debug).selected, isTrue);
      acceptChanges = true;
      for (final label in [
        'DEBUG',
        'INFO',
        'WARN',
        'ERROR',
        'Flutter',
        'Android'
      ]) {
        await t.tap(find.byKey(ValueKey('controlled-$label')));
        await t.pump();
      }
      expect(levels, isEmpty);
      expect(sources, isEmpty);
      expect(t.getSemantics(debug).hasFlag(ui.SemanticsFlag.hasCheckedState),
          isTrue);
      expect(
          t.getSemantics(debug).hasFlag(ui.SemanticsFlag.isChecked), isFalse);
      await t.tap(find.byKey(const ValueKey('controlled-INFO')));
      await t.pump();
      expect(levels, {'INFO'});
      expect(sources, isEmpty);
      expect(events.last, 'INFO=true');
    } finally {
      semantics.dispose();
    }
  });
  scenario('日志compact四级别普通字号同排，34视觉44触控与11字体', (t) async {
    var directory = File(Platform.resolvedExecutable).parent;
    while (!Directory('${directory.path}/material_fonts').existsSync() &&
        directory.parent.path != directory.path) {
      directory = directory.parent;
    }
    final loader = FontLoader('MaintenanceCompactRoboto');
    for (final weight in ['Regular', 'Bold']) {
      final bytes = await t.runAsync(() =>
          File('${directory.path}/material_fonts/Roboto-$weight.ttf')
              .readAsBytes());
      loader.addFont(Future.value(ByteData.sublistView(bytes!)));
    }
    await t.runAsync(loader.load);
    t.view.devicePixelRatio = 3;
    t.view.physicalSize = const Size(406 * 3, 900 * 3);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    final theme = beeTheme();
    await t.pumpWidget(MaterialApp(
        theme: theme.copyWith(
            textTheme:
                theme.textTheme.apply(fontFamily: 'MaintenanceCompactRoboto')),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: BeeMaintenanceLogFilters(
                    levelLabel: 'Level',
                    sourceLabel: 'Source',
                    levels: [
                      for (final level in ['DEBUG', 'INFO', 'WARN', 'ERROR'])
                        BeeMaintenanceFilterChoice(
                            key: ValueKey('metrics-$level'),
                            label: level,
                            selected: true,
                            onSelected: (_) {})
                    ],
                    sources: const [])))));
    await t.pumpAndSettle();
    final tops = <double>[];
    for (final level in ['DEBUG', 'INFO', 'WARN', 'ERROR']) {
      final chip = find.byKey(ValueKey('metrics-$level'));
      tops.add(t.getTopLeft(chip).dy);
      expect(t.getSize(chip).height, greaterThanOrEqualTo(44));
      expect(
          t
              .getSize(find.descendant(
                  of: chip,
                  matching:
                      find.byKey(const ValueKey('bee-choice-chip-visual'))))
              .height,
          34);
      final label =
          t.widget<Text>(find.descendant(of: chip, matching: find.text(level)));
      expect(label.style!.fontSize, 11);
      expect(label.style!.height, 1.5);
    }
    expect(tops.toSet(), hasLength(1));
    expect(t.takeException(), isNull);
  });
  scenario('日志搜索图标和边框沿用基础搜索规范，避免前缀被输入框撑大', (t) async {
    await show(t, const LogCenterPage());
    final field = find.byKey(const ValueKey('maintenance-log-search'));
    final icon = find.descendant(
        of: field,
        matching: find.byWidgetPredicate(
            (widget) => widget is BeeLineIcon && widget.name == 'Search'));
    expect(t.getSize(icon), const Size(20, 20));
    final input = t.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)));
    final border = input.decoration!.enabledBorder! as OutlineInputBorder;
    expect(border.borderSide, BorderSide.none);
    expect(border.borderRadius, BorderRadius.circular(13));
  });
  scenario('日志搜索大小写不敏感匹配message或tag，清除不改多选', (t) async {
    await show(t, const LogCenterPage(), platform: TargetPlatform.macOS);
    await t.enterText(
        find.byKey(const ValueKey('maintenance-log-search')), 'cAsEtAg5');
    await flush(t);
    expect(find.text('${l.logCenterFiltered}: 1'), findsOneWidget);
    await action(t, l.searchClearFilter);
    expect(find.text('${l.logCenterFiltered}: 12'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('maintenance-log-search')),
        'OWNED MESSAGE 1');
    await flush(t);
    expect(find.text('${l.logCenterFiltered}: 3'), findsOneWidget);
  });
  scenario('日志详情保留时间级别来源错误堆栈，复制完整原格式', (t) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await show(t, const LogCenterPage());
    final target = find.text('[CaseTag3]');
    await reveal(t, target);
    await t.tap(target);
    await flush(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('时间:'), findsOneWidget);
    expect(find.text('级别:'), findsOneWidget);
    expect(find.text('平台:'), findsOneWidget);
    expect(find.textContaining('owned stack line'), findsOneWidget);
    await tap(t, '复制');
    expect(copied, logs[3].toFormattedString());
    await tap(t, '关闭');
    expect(find.byType(AlertDialog), findsNothing);
  });
  scenario('长按日志保留直接复制', (t) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await show(t, const LogCenterPage());
    final target = find.text('[CaseTag11]');
    await reveal(t, target);
    await t.longPress(target);
    await flush(t);
    expect(copied, logs[11].toFormattedString());
  });
  scenario('导出保留全部日志而非仅过滤结果且保留subject', (t) async {
    Map? payload;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      payload = call.arguments as Map;
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await show(t, const LogCenterPage());
    await t.enterText(
        find.byKey(const ValueKey('maintenance-log-search')), 'CaseTag5');
    await flush(t);
    await action(t, l.logCenterExport);
    expect(payload!['subject'], 'BeeCount 日志导出');
    expect(payload!['text'], contains('CaseTag0'));
    expect(payload!['text'], contains('CaseTag11'));
    expect(payload!['text'], contains('日志数量: 12'));
  });
  scenario('导出故障沿原失败提示且可重试', (t) async {
    var fail = true;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (fail) throw PlatformException(code: 'owned');
      return 'dev.fluttercommunity.plus/share/success';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    await show(t, const LogCenterPage());
    await action(t, l.logCenterExport);
    expect(find.text(l.logCenterExportFailed), findsOneWidget);
    fail = false;
    await action(t, l.logCenterExport);
  });
  scenario('日志清空取消无写入，确认清全部并持久化', (t) async {
    await show(t, const LogCenterPage());
    await action(t, l.logCenterClear);
    await tap(t, l.commonCancel);
    expect(source.logs, hasLength(12));
    await action(t, l.logCenterClear);
    await tap(t, l.commonConfirm);
    await source.waitForPendingWorkForTesting();
    expect(source.logs, isEmpty);
    await prefs.reload();
    expect(jsonDecode(prefs.getString('app_logs')!), isEmpty);
    expect(
        (await SharedPreferences.getInstance()).getString('unrelated'), 'keep');
  });
  scenario('存储扫描仅顶层tflite与Android BeeCount_apk，原文件关系不变', (t) async {
    final before = await io(t, snapshot);
    await show(t, const StorageManagementPage());
    expect(find.text('10 B'), findsOneWidget);
    expect(find.text('3 B'), findsOneWidget);
    expect(find.text(l.storageAPKFiles), findsOneWidget);
    expect(await io(t, snapshot), before);
  });
  scenario('iOS存储不扫描或显示APK', (t) async {
    await show(t, const StorageManagementPage(), platform: TargetPlatform.iOS);
    expect(find.text(l.storageAPKFiles), findsNothing);
    expect(find.text('10 B'), findsOneWidget);
  });
  scenario('Android外部目录不可用保持原空态而不清理其他位置', (t) async {
    noExternal = true;
    await show(t, const StorageManagementPage());
    final card = t.widget<BeeMaintenanceAction>(
        find.byKey(const ValueKey('maintenance-clear-apks')));
    expect(card.onTap, isNull);
    expect(card.value, '0 B');
    expect(
        await io(t, () => File('${external.path}/BeeCount_owned.apk').exists()),
        true);
    expect(deletes, 0);
  });
  scenario('模型目录不存在保持原空态和禁用清理', (t) async {
    await io(
        t,
        () => Directory('${docs.path}/ai_models')
            .rename('${docs.path}/owned-unused-models'));
    await show(t, const StorageManagementPage());
    final card = t.widget<BeeMaintenanceAction>(
        find.byKey(const ValueKey('maintenance-clear-models')));
    expect(card.onTap, isNull);
    expect(card.value, '0 B');
    expect(deletes, 0);
  });
  scenario('模型清理取消保留所有owned文件和SQLite', (t) async {
    final before = await io(t, snapshot);
    await show(t, const StorageManagementPage());
    await tap(t, l.storageAIModels);
    await tap(t, l.commonCancel);
    expect(deletes, 0);
    expect(await io(t, snapshot), before);
  });
  scenario('模型清理只删已扫顶层tflite，保留嵌套文件APK和附件', (t) async {
    await show(t, const StorageManagementPage());
    await tap(t, l.storageAIModels);
    await tap(t, l.commonConfirm);
    expect(deletes, 2);
    expect(
        await io(t, () => File('${docs.path}/ai_models/one.tflite').exists()),
        false);
    expect(
        await io(t,
            () => File('${docs.path}/ai_models/nested/nested.tflite').exists()),
        true);
    expect(
        await io(
            t, () => File('${docs.path}/ai_models/unrelated.bin').exists()),
        true);
    expect(
        await io(t, () => File('${external.path}/BeeCount_owned.apk').exists()),
        true);
    expect(
        await io(t, () => File('${attachments.path}/keep.jpg').exists()), true);
    expect(await db.select(db.transactionAttachments).get(), hasLength(3));
  });
  scenario('APK清理仅命中原匹配项不碰其他包和数据', (t) async {
    await show(t, const StorageManagementPage());
    await tap(t, l.storageAPKFiles);
    await tap(t, l.commonConfirm);
    expect(deletes, 1);
    expect(
        await io(t, () => File('${external.path}/BeeCount_owned.apk').exists()),
        false);
    expect(
        await io(t, () => File('${external.path}/other.apk').exists()), true);
    expect(
        await io(t, () => File('${external.path}/BeeCount_upper.APK').exists()),
        true);
    expect(
        await io(t, () => File('${docs.path}/ai_models/one.tflite').exists()),
        true);
  });
  scenario('存储扫描异常显示重试，恢复后重新显示实际大小', (t) async {
    scanError = true;
    await show(t, const StorageManagementPage());
    expect(find.textContaining('Owned scan failed'), findsOneWidget);
    scanError = false;
    await tap(t, l.v4RecordingRetry);
    expect(find.text('10 B'), findsOneWidget);
  });
  scenario('文件删除部分故障如实失败并重扫，不声称物理文件回滚', (t) async {
    deleteFailure = true;
    await show(t, const StorageManagementPage());
    await tap(t, l.storageAIModels);
    await tap(t, l.commonConfirm);
    expect(deletes, 2);
    expect(find.textContaining('Owned delete failed'), findsOneWidget);
    final existing = await io(
        t,
        () => Directory('${docs.path}/ai_models')
            .list()
            .where((f) => f is File && f.path.endsWith('.tflite'))
            .toList());
    expect(existing, hasLength(1));
    expect(
        await io(t, () => File('${attachments.path}/keep.jpg').exists()), true);
  });
  scenario('清理执行防重且退页不继续访问ref或损坏其他文件', (t) async {
    deleteGate = Completer();
    await show(t, const StorageManagementPage());
    await tap(t, l.storageAIModels);
    await tap(t, l.commonConfirm);
    expect(deletes, 1);
    expect(
        t
            .widget<BeeMaintenanceAction>(
                find.byKey(const ValueKey('maintenance-clear-models')))
            .busy,
        true);
    await t.pumpWidget(const SizedBox.shrink());
    deleteGate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
    expect(deletes, 2);
    expect(
        await io(t, () => File('${attachments.path}/keep.jpg').exists()), true);
  });
  scenario('真实孤儿扫描覆盖全部14种原类型', (t) async {
    final report = await io(t, scanner.scanAll);
    expect(report.all.map((x) => x.type).toSet(), OrphanType.values.toSet());
    await show(t, const OrphanCleanupPage());
    expect(find.text(l.maintenanceOrphanSummary(14)), findsOneWidget);
    expect(cleaner.calls, 0);
  });
  scenario('孤儿组选择与总选择保留多选和重扫状态', (t) async {
    await show(t, const OrphanCleanupPage());
    await t.tap(
        find.widgetWithText(TextButton, l.maintenanceOrphanSelectAll).first);
    await flush(t);
    expect(find.text(l.maintenanceOrphanSelectedHint(10)), findsOneWidget);
    await t.tap(find.widgetWithText(BeeButton, l.maintenanceOrphanDeselectAll));
    await flush(t);
    expect(find.text(l.maintenanceOrphanSelectedHint(0)), findsOneWidget);
    await selectAll(t);
    expect(find.text(l.maintenanceOrphanSelectedHint(14)), findsOneWidget);
    await action(t, l.maintenanceOrphanRescan);
    expect(find.text(l.maintenanceOrphanSelectedHint(14)), findsOneWidget);
  });
  scenario('孤儿批量确认取消严格保留全库和全部owned文件', (t) async {
    final before = await io(t, snapshot);
    await show(t, const OrphanCleanupPage());
    await selectAll(t);
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonCancel);
    expect(cleaner.calls, 0);
    expect(await io(t, snapshot), before);
  });
  scenario('孤儿单条删除取消无变更，确认仅处理该项', (t) async {
    final report = await io(t, scanner.scanAll);
    final record = report.dbOrphans
        .singleWhere((x) => x.type == OrphanType.budgetMissingLedger);
    await show(t, const OrphanCleanupPage());
    final row = find.byKey(ValueKey('maintenance-orphan-${record.uniqueKey}'));
    await reveal(t, row);
    await t.tap(find.descendant(of: row, matching: find.byType(BeeIconButton)));
    await flush(t);
    await tap(t, l.commonCancel);
    expect(cleaner.calls, 0);
    await t.tap(find.descendant(of: row, matching: find.byType(BeeIconButton)));
    await flush(t);
    await tap(t, l.commonOk);
    expect(cleaner.calls, 1);
    expect((await db.select(db.budgets).get()).map((x) => x.id), [2, 3]);
    expect(
        await io(t, () => File('${attachments.path}/keep.jpg').exists()), true);
  });
  scenario('孤儿清理保留两本真实交易标签附件与外币隐私字段', (t) async {
    final txBefore = (await db.select(db.transactions).get())
        .where((x) => x.id != 3)
        .toList();
    await show(t, const OrphanCleanupPage());
    await selectAll(t);
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonOk);
    expect(cleaner.calls, 1);
    final tx = await db.select(db.transactions).get();
    expect(tx, hasLength(3));
    expect(tx.where((x) => x.id != 3).toList(), txBefore);
    final broken = tx.singleWhere((x) => x.id == 3);
    expect(broken.accountId, isNull);
    expect(broken.categoryId, isNull);
    expect(broken.amount, 47);
    expect(broken.note, 'keep broken foreign keys');
    expect((await db.select(db.transactionAttachments).get()).map((x) => x.id),
        [1, 2]);
    expect(
        (await db.select(db.transactionTags).get()).map((x) => x.transactionId),
        [1, 2]);
    expect(
        (await db.select(db.transactionTagOverrides).get())
            .single
            .transactionSyncId,
        'tx1');
    expect(
        await io(t, () => File('${attachments.path}/keep.jpg').readAsBytes()),
        [2, 2, 2, 2]);
    expect(await io(t, () => File('${attachments.path}/dangling.jpg').exists()),
        true,
        reason: '原附件孤儿DB行清理不同时删除原文件，需重扫后再明确选择');
    expect(await io(t, () => File('${attachments.path}/orphan.jpg').exists()),
        false);
    expect(
        await io(t, () => File('${icons.path}/keep_icon.png').exists()), true);
    expect(await io(t, () => File('${icons.path}/shared_used.png').exists()),
        true);
    expect(await io(t, () => File('${icons.path}/orphan_icon.png').exists()),
        false);
    expect(await io(t, () => File('${icons.path}/shared_unused.png').exists()),
        false);
  });
  scenario('孤儿普通部分失败保留失败勾选并可重试', (t) async {
    await db.customStatement(
        "CREATE TRIGGER owned_reject BEFORE DELETE ON budgets WHEN OLD.id=1 BEGIN SELECT RAISE(ABORT,'owned reject'); END");
    await show(t, const OrphanCleanupPage());
    await selectAll(t);
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonOk);
    expect(find.text(l.maintenanceOrphanCleanPartial(13, 1)), findsOneWidget);
    expect(find.text(l.maintenanceOrphanSelectedHint(1)), findsOneWidget);
    await db.customStatement('DROP TRIGGER owned_reject');
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonOk);
    expect(cleaner.calls, 2);
    expect((await db.select(db.budgets).get()).map((x) => x.id), [3]);
  });
  scenario('孤儿扫描故障可重试，清理抛错不报告成功或清选择', (t) async {
    scanner.fail = true;
    await show(t, const OrphanCleanupPage());
    expect(find.textContaining('Owned scan failed'), findsOneWidget);
    scanner.fail = false;
    await tap(t, l.v4RecordingRetry);
    await selectAll(t);
    cleaner.fail = true;
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonOk);
    expect(find.textContaining('Owned clean failed'), findsOneWidget);
    expect(find.text(l.maintenanceOrphanSelectedHint(14)), findsOneWidget);
    expect(await db.select(db.transactionAttachments).get(), hasLength(3));
  });
  scenario('孤儿执行忙碌防重且退页后不触碰已销毁ref', (t) async {
    cleaner.gate = Completer();
    await show(t, const OrphanCleanupPage());
    await selectAll(t);
    await tap(t, l.maintenanceOrphanCleanSelected);
    await tap(t, l.commonOk);
    expect(cleaner.calls, 1);
    expect(
        t
            .widget<BeeButton>(find.widgetWithText(
                BeeButton, l.maintenanceOrphanCleanSelected))
            .onPressed,
        isNull);
    await t.pumpWidget(const SizedBox.shrink());
    cleaner.gate!.complete();
    await flush(t);
    expect(t.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    scenario('组件${platform.name}全部9张真实预览与原尺寸和平台四步引导', (t) async {
      await show(t, const WidgetManagementPage(), platform: platform);
      final cards = <String, Size>{};
      final viewTypes = <String>{};
      for (var step = 0; step < 14; step++) {
        for (final card in t.widgetList<BeeMaintenanceWidgetCard>(
            find.byType(BeeMaintenanceWidgetCard))) {
          cards['${card.title}|${card.sizeLabel}'] = card.previewSize;
          viewTypes.add(card.preview.runtimeType.toString());
        }
        await t.drag(find.byType(ListView), const Offset(0, -500));
        await flush(t, cycles: 2);
      }
      expect(cards, hasLength(9));
      expect(
          viewTypes,
          containsAll([
            'GlanceView',
            'NetWorthView',
            'QuickAddView',
            'BudgetView',
            'RecentView',
            'DashboardView',
            'ConsumptionRhythmView',
            'BeeTrailView'
          ]));
      expect(
          cards.values,
          containsAll([
            const Size(155, 155),
            const Size(364, 169),
            const Size(364, 382)
          ]));
      expect(
          find.text(platform == TargetPlatform.iOS
              ? l.iosWidgetStep4
              : l.androidWidgetStep4),
          findsOneWidget);
      expect(find.text(l.widgetQuickEntryDesc), findsOneWidget);
      expect(find.text(l.widgetDescription), findsOneWidget);
      expect(await db.select(db.transactions).get(), hasLength(3));
    });
  }
  scenario('真实只读preview不扫描文件或调用清理，样例本地受控', (t) async {
    await show(t, const Scaffold(body: MaintenancePreview()));
    expect(find.text('${l.logCenterTotal}: 12'), findsOneWidget);
    expect(find.textContaining(l.maintenanceOrphanSummary(10)), findsOneWidget);
    expect(scanner.scans, 0);
    expect(cleaner.calls, 0);
    expect(deletes, 0);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(
            body: SingleChildScrollView(child: MaintenanceSample()))));
    await t.pumpAndSettle();
    expect(find.byType(BeeMaintenanceLogFilters), findsOneWidget);
    expect(cleaner.calls, 0);
  });
  for (final brightness in Brightness.values) {
    for (final page in [
      const LogCenterPage(),
      const StorageManagementPage(),
      const OrphanCleanupPage(),
      const WidgetManagementPage()
    ]) {
      scenario('360px短屏大字体${brightness.name}${page.runtimeType}', (t) async {
        t.view.physicalSize = const Size(360, 640);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(host(page, brightness: brightness, scale: 1.5));
        await flush(t);
        final scroll = find.byType(Scrollable).first;
        await t.drag(scroll, const Offset(0, -600));
        await flush(t);
        expect(t.takeException(), isNull);
      });
    }
  }
}

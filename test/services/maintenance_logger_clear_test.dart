import 'dart:async';
import 'dart:convert';
import 'package:beecount/services/system/logger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Keep the real preference cache with an owned, controllable synthetic disk.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Disk extends InMemorySharedPreferencesStore {
  _Disk(super.values) : super.withData();
  Completer<void>? firstWrite;
  int writes = 0;
  final written = <String>[];
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    writes++;
    if (writes == 1) await firstWrite?.future;
    written.add(value as String);
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Disk disk;
  late SharedPreferences prefs;
  final instances = <LoggerService>[];
  String serialized(String text) => jsonEncode([
        LogEntry(
                timestamp: DateTime.now(),
                level: LogLevel.info,
                platform: LogPlatform.flutter,
                tag: 'owned',
                message: text)
            .toJson()
      ]);
  LoggerService create({Future<SharedPreferences> Function()? get}) {
    final instance = LoggerService.forTesting(
        getPreferences: get ?? () => Future.value(prefs));
    instances.add(instance);
    return instance;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    disk = _Disk({'flutter.app_logs': serialized('old persisted')});
    SharedPreferencesStorePlatform.instance = disk;
    prefs = await SharedPreferences.getInstance();
    instances.clear();
  });
  tearDown(() {
    for (final instance in instances) {
      instance.disposeForTesting();
    }
  });
  Future<void> micro(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  Future<List<String>> restart() async {
    await prefs.reload();
    final next = create();
    next.logs;
    await next.waitForPendingWorkForTesting();
    return next.logs.map((x) => x.message).toList();
  }

  testWidgets('clear已加载持久化日志后逻辑重启不回填', (t) async {
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    expect(instance.logs.single.message, 'old persisted');
    instance.clear();
    await instance.waitForPendingWorkForTesting();
    expect(instance.logs, isEmpty);
    expect(await restart(), isEmpty);
    expect(jsonDecode((await disk.getAll())['flutter.app_logs'] as String),
        isEmpty);
  });
  testWidgets('clear在首次读取前也持久化空快照', (t) async {
    final instance = create();
    instance.clear();
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), isEmpty);
  });
  testWidgets('首次异步load未完成时clear阻止旧快照回填', (t) async {
    final load = Completer<SharedPreferences>(),
        write = Completer<SharedPreferences>();
    var calls = 0;
    final instance = create(get: () {
      calls++;
      return calls == 1 ? load.future : write.future;
    });
    instance.logs;
    instance.clear();
    await micro(t);
    load.complete(prefs);
    await micro(t);
    expect(instance.logs, isEmpty);
    write.complete(prefs);
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), isEmpty);
  });
  testWidgets('旧节流保存尚未触发时clear取消它且保留后续新日志', (t) async {
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    instance.info('owned', 'before clear');
    instance.clear();
    instance.info('owned', 'after clear');
    await t.pump(const Duration(seconds: 3));
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), ['after clear']);
  });
  testWidgets('已发出的旧磁盘保存不会在clear之后覆盖空快照', (t) async {
    disk.firstWrite = Completer();
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    instance.info('owned', 'pending old save');
    await t.pump(const Duration(seconds: 3));
    await micro(t);
    expect(disk.writes, 1);
    instance.clear();
    disk.firstWrite!.complete();
    await micro(t);
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), isEmpty);
    expect(jsonDecode(disk.written.last), isEmpty);
  });
  testWidgets('旧保存与clear和新日志交错最终只保留新日志', (t) async {
    disk.firstWrite = Completer();
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    instance.info('owned', 'old save');
    await t.pump(const Duration(seconds: 3));
    await micro(t);
    instance.clear();
    instance.warning('owned', 'new warning');
    await t.pump(const Duration(seconds: 3));
    disk.firstWrite!.complete();
    await micro(t);
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), ['new warning']);
  });
  testWidgets('连续clear淘汰旧代数且最后clear后的日志可保存', (t) async {
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    instance.clear();
    instance.info('owned', 'between clears');
    instance.clear();
    instance.error('owned', 'last error');
    await t.pump(const Duration(seconds: 3));
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), ['last error']);
  });
  testWidgets('加载保留原48小时过滤不会恢复已过期日志', (t) async {
    final expired = LogEntry(
        timestamp: DateTime.now().subtract(const Duration(hours: 49)),
        level: LogLevel.error,
        platform: LogPlatform.ios,
        tag: 'owned-expired',
        message: 'expired');
    await prefs.setString(
        'app_logs',
        jsonEncode(
            [...(jsonDecode(serialized('recent')) as List), expired.toJson()]));
    final instance = create();
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    expect(instance.logs.map((x) => x.message), ['recent']);
  });
  testWidgets('首读未完成clear再记新日志不会混回旧历史', (t) async {
    final load = Completer<SharedPreferences>();
    var reads = 0;
    final instance = create(get: () {
      reads++;
      return reads == 1 ? load.future : Future.value(prefs);
    });
    instance.logs;
    instance.clear();
    instance.info('owned', 'new during load');
    await t.pump(const Duration(seconds: 3));
    load.complete(prefs);
    await micro(t);
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), ['new during load']);
  });
  testWidgets('加载完成通知UI且保留原级别平台格式与48小时窗口', (t) async {
    final instance = create();
    var notices = 0;
    instance.addListener(() => notices++);
    instance.logs;
    await instance.waitForPendingWorkForTesting();
    expect(notices, 1);
    instance.debug('owned', 'debug');
    instance.warning('owned', 'warning');
    instance.error('owned', 'error');
    expect(instance.logs.map((x) => x.level), containsAll(LogLevel.values));
    expect(instance.exportAsText(), contains('=== BeeCount 日志导出 ==='));
    expect(instance.exportAsText(), contains('[Flutter] [owned]'));
    await t.pump(const Duration(seconds: 3));
    await instance.waitForPendingWorkForTesting();
    expect(await restart(), ['old persisted', 'debug', 'warning', 'error']);
  });
}

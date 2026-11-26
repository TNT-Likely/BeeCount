import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beecount/services/system/log_export_service.dart';
import 'package:beecount/services/system/logger_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

Map<String, dynamic> _entry(
  DateTime time,
  String message, {
  String tag = 'App',
  LogLevel level = LogLevel.info,
  LogPlatform platform = LogPlatform.flutter,
  Object? error,
  String? stack,
}) =>
    LogEntry(
      timestamp: time,
      level: level,
      platform: platform,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stack == null ? null : StackTrace.fromString(stack),
    ).toJson();

class _SavePicker extends FilePicker {
  String? result;
  String? name;
  String? title;
  Uint8List? data;
  List<String>? extensions;
  FileType? fileType;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    name = fileName;
    title = dialogTitle;
    data = bytes;
    extensions = allowedExtensions;
    fileType = type;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  LoggerService logger({Future<SharedPreferences> Function()? get}) {
    final service = LoggerService.forTesting(
      getPreferences: get ?? () async => prefs,
    );
    addTearDown(service.disposeForTesting);
    return service;
  }

  test(
      'cold capture joins the pending read, keeps the newest 2000 valid entries and freezes the file',
      () async {
    final now = DateTime.now();
    final previousDay = DateTime(now.year, now.month, now.day - 1, 12);
    final history = [
      _entry(previousDay.subtract(const Duration(days: 2)), 'expired'),
      for (var i = 0; i < 2000; i++)
        _entry(previousDay.add(Duration(milliseconds: i)), 'record ($i)'),
    ];
    history.insert(1000, {'timestamp': 'damaged'});
    await prefs.setString('app_logs', jsonEncode(history.reversed.toList()));

    final gate = Completer<SharedPreferences>();
    var reads = 0;
    final service = logger(get: () {
      reads++;
      return gate.future;
    });
    service.info('App', 'startup event');
    final capture = LogExportSnapshot.capture(service);
    var complete = false;
    capture.then((_) => complete = true);
    await Future<void>.delayed(Duration.zero);
    expect(complete, isFalse);
    expect(reads, 1);

    gate.complete(prefs);
    final snapshot = await capture;
    final file = snapshot.file;
    expect(snapshot.count, 2000);
    expect(service.logs.first.message, 'record (1)');
    expect(service.logs.last.message, 'startup event');
    expect(file.text, isNot(contains('record (0)')));
    expect(file.text, isNot(contains('expired')));
    final date1 = previousDay.toIso8601String().split('T').first;
    final date2 =
        service.logs.last.timestamp.toIso8601String().split('T').first;
    final first = file.text.indexOf('--- $date1 ---');
    final second = file.text.indexOf('--- $date2 ---');
    expect(first, greaterThanOrEqualTo(0));
    expect(second, greaterThan(first));
    expect(utf8.decode(file.bytes), file.text);
    expect(() => file.bytes[0] = 0, throwsUnsupportedError);
    expect(file.fileName, startsWith('BeeCount-logs-'));
    expect(file.fileName, endsWith('.txt'));
    expect(file.fileName, isNot(contains(':')));
    service.warning('App', 'after snapshot');
    expect(service.logs.length, 2000);
    expect(service.logs.first.message, 'record (2)');
    expect(snapshot.file, same(file));
    expect(file.text, isNot(contains('after snapshot')));
  });

  testWidgets(
      'an unreadable history is preserved on autosave and can be reopened on retry',
      (tester) async {
    await prefs.setString('app_logs', '{broken');
    final service = logger();
    service.error('App', 'live after bad history');
    await expectLater(LogExportSnapshot.capture(service), throwsStateError);
    await tester.pump(const Duration(seconds: 3));
    await service.waitForPendingWorkForTesting();
    expect(prefs.getString('app_logs'), '{broken');
    final before = DateTime.now().subtract(const Duration(minutes: 1));
    await prefs.setString('app_logs', jsonEncode([_entry(before, 'restored')]));
    final snapshot = await LogExportSnapshot.capture(service);
    expect(snapshot.count, 2);
    expect(service.logs.map((log) => log.message),
        ['restored', 'live after bad history']);
    expect((await LogExportSnapshot.capture(service)).count, 2);
  });

  test(
      'export preserves complete messages, custom tags, exception details and stack paths',
      () async {
    const message = '同步失败 账号 owned@example.invalid\n金额 12345.67 🐝';
    const errorDetail = 'FormatException: https://owned.invalid/?q=账单';
    const stack = '#0      customSymbol (file:///owned/测试.dart:12:8)\n'
        '#1      SyncEngine.sync (package:beecount/cloud/sync/sync_engine.dart:621:18)';
    final time = DateTime.now().subtract(const Duration(minutes: 1));
    final history = _entry(time, message,
        tag: 'custom/module',
        level: LogLevel.error,
        platform: LogPlatform.ios,
        error: errorDetail,
        stack: stack);
    await prefs.setString('app_logs', jsonEncode([history]));
    final service = logger();
    final error = Exception('自由格式异常说明 ($message)');
    const liveStack = 'Native stack: frame with spaces [附件.txt:7]';
    service.error('App', '启动时的异常', error, StackTrace.fromString(liveStack));
    final snapshot = await LogExportSnapshot.capture(service);
    final text = utf8.decode(snapshot.file.bytes);
    expect(snapshot.count, 2);
    expect(text, contains('[ERROR] [iOS] [custom/module] $message\n'));
    expect(text, contains('  Error: $errorDetail\n'));
    expect(text, contains(stack.replaceAll('\n', '\n  ')));
    expect(text, contains('  Error: $error\n'));
    expect(text, contains('  $liveStack\n'));
    expect(text, snapshot.file.text);
  });

  test(
      'large attachments and saved copies use preview bytes across failure, retry and cancellation',
      () async {
    final time = DateTime.now();
    final message = '合成测试🐝' * 80000;
    await prefs.setString('app_logs', jsonEncode([_entry(time, message)]));
    final snapshot = await LogExportSnapshot.capture(logger());
    final file = snapshot.file;
    expect(file.bytes.length, greaterThan(1024 * 1024));

    final cache =
        await Directory.systemTemp.createTemp('beecount-export-test-');
    addTearDown(() => cache.delete(recursive: true));
    final platform = LogExportPlatform(temporaryDirectory: () async => cache);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const anchor = Rect.fromLTWH(40, 50, 80, 32);
    const subject = '日志分享';
    final filesRead = <String>[];
    const outcomes = [
      null,
      '',
      'dev.fluttercommunity.plus/share/unavailable',
      'target'
    ];
    messenger.setMockMethodCallHandler(_shareChannel, (call) async {
      expect(call.method, 'share');
      final args = call.arguments as Map<Object?, Object?>;
      expect(args['subject'], subject);
      expect(args['originX'], anchor.left);
      expect(args['originY'], anchor.top);
      expect(args['originWidth'], anchor.width);
      expect(args['originHeight'], anchor.height);
      expect(args.containsKey('text'), isFalse);
      expect(args['mimeTypes'], ['text/plain']);
      final path = (args['paths'] as List).single as String;
      expect(p.basename(path), file.fileName);
      final bytes = await File(path).readAsBytes();
      expect(listEquals(bytes, file.bytes), isTrue);
      final outcome = outcomes[filesRead.length];
      filesRead.add(path);
      if (outcome == null) throw PlatformException(code: 'test_failure');
      return outcome;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(_shareChannel, null));

    for (final bad in [
      Rect.zero,
      const Rect.fromLTWH(-1, 0, 8, 8),
      const Rect.fromLTWH(double.nan, 0, 8, 8)
    ]) {
      await expectLater(platform.share(file, origin: bad, subject: subject),
          throwsArgumentError);
    }
    expect(filesRead, isEmpty);
    Future<ShareResultStatus> share() =>
        platform.share(file, origin: anchor, subject: subject);
    await expectLater(share(), throwsA(isA<PlatformException>()));
    expect(await share(), ShareResultStatus.dismissed);
    expect(await share(), ShareResultStatus.unavailable);
    expect(await share(), ShareResultStatus.success);
    expect(filesRead.toSet(), hasLength(4));
    expect(await cache.list().toList(), isEmpty);

    final picker = _SavePicker();
    FilePicker.platform = picker;
    expect(await platform.save(file, dialogTitle: subject), isFalse);
    expect(picker.name, file.fileName);
    expect(picker.data, same(file.bytes));
    picker.result = '/owned/saved.txt';
    expect(await platform.save(file, dialogTitle: subject), isTrue);
    expect(picker.name, file.fileName);
    expect(picker.data, same(file.bytes));
    expect(utf8.decode(picker.data!), file.text);
    expect(picker.title, subject);
    expect(picker.fileType, FileType.custom);
    expect(picker.extensions, ['txt']);
  });
}

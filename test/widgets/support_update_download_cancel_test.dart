import 'dart:async';
import 'dart:io';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_en.dart';
import 'package:beecount/services/update/update_downloader.dart';
import 'package:beecount/services/update/update_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LocalHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'original updater makes owned local HTTP request and cancellation never installs',
      (t) async {
    t.view.physicalSize = const Size(320, 568);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(
        {'github_mirror_selected': 'direct'});
    final directory = await t.runAsync(
        () => Directory.systemTemp.createTemp('beecount-r102-update-unit-'));
    final server = (await t
        .runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    final received = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => directory!.path);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async => call.method == 'initialize' ||
                call.method == 'requestNotificationsPermission'
            ? false
            : null);
    await t.runAsync(() async {
      server.listen((request) async {
        expect(request.uri.path, '/qa-synthetic-update');
        if (!received.isCompleted) received.complete();
        request.response.contentLength = 1024 * 1024;
        try {
          for (var i = 0; i < 512; i++) {
            request.response.add(List.filled(2048, 81));
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
        } catch (_) {
        } finally {
          await request.response.close().catchError((_) {});
        }
      });
    });
    UpdateResult? result;
    final progress = <(double, String)>[];
    try {
      await t.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, body) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(1.4)),
              child: body!),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () {
                        HttpOverrides.runWithHttpOverrides(() async {
                          result = await UpdateDownloader.downloadApk(
                              context,
                              'http://127.0.0.1:${server.port}/qa-synthetic-update',
                              'r102-unit',
                              onProgress: (p, s) => progress.add((p, s)));
                        }, _LocalHttp());
                      },
                      child: const Text('QA download'))))));
      await t.tap(find.text('QA download'));
      await t.pump();
      for (var i = 0;
          i < 100 &&
              (!received.isCompleted || !progress.any((event) => event.$1 > 0));
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(received.isCompleted, isTrue);
      expect(progress.any((event) => event.$1 > 0 && event.$1 < 1), isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text(AppLocalizationsEn().updateCancelButton));
      await t.pump();
      for (var i = 0; i < 100 && result == null; i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(result?.type, UpdateResultType.userCancelled);
      await t.pumpAndSettle();
      expect(progress.last, (0.0, ''));
      expect(find.byType(AlertDialog), findsNothing);
      final files = await t.runAsync(() => directory!.list().toList());
      expect(
          files!
              .whereType<File>()
              .every((f) => f.parent.path == directory!.path),
          isTrue);
    } finally {
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      await t.runAsync(() => server.close(force: true));
      messenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'), null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null);
      await t.runAsync(() => directory!.delete(recursive: true));
    }
  });
}

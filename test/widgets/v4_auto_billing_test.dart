import 'dart:async';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/automation/auto_billing_settings_page.dart';
import 'package:beecount/pages/automation/ios_auto_billing_page.dart';
import 'package:beecount/presentation/v4/bindings/auto_billing_actions.dart';
import 'package:beecount/presentation/v4/bindings/ios_auto_billing_actions.dart';
import 'package:beecount_business_ui/auto_billing.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

class FakeAndroidActions implements AutoBillingAndroidActions {
  bool enabled = false, granted = true;
  int reads = 0,
      permissionRequests = 0,
      enables = 0,
      disables = 0,
      batteryReads = 0,
      batteryRequests = 0,
      disposals = 0;
  Object? loadError, enableError, disableError, batteryError;
  Completer<bool>? pendingRead, pendingPermission;
  Completer<void>? pendingEnable;
  Map<String, dynamic> info = {
    'isIgnoring': false,
    'canRequest': true,
    'manufacturer': 'QA maker',
    'model': 'QA device',
    'androidVersion': 'QA 17'
  };
  @override
  Future<bool> isEnabled() async {
    reads++;
    if (pendingRead != null) return pendingRead!.future;
    if (loadError != null) throw loadError!;
    return enabled;
  }

  @override
  Future<Map<String, dynamic>> batteryInfo() async {
    batteryReads++;
    if (batteryError != null) throw batteryError!;
    return info;
  }

  @override
  Future<bool> requestScreenshotPermission() async {
    permissionRequests++;
    return pendingPermission?.future ?? Future.value(granted);
  }

  @override
  Future<void> enable() async {
    enables++;
    if (pendingEnable != null) await pendingEnable!.future;
    if (enableError != null) throw enableError!;
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disables++;
    if (disableError != null) throw disableError!;
    enabled = false;
  }

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async {
    batteryRequests++;
    info = {...info, 'isIgnoring': true};
    return true;
  }

  @override
  void dispose() {
    disposals++;
  }
}

class FakeIOSActions extends IOSAutoBillingActions {
  int imports = 0, tutorials = 0;
  bool result = true;
  Object? error;
  Completer<bool>? pending;
  @override
  Future<bool> openShortcut() async {
    imports++;
    if (error != null) throw error!;
    return pending?.future ?? Future.value(result);
  }

  @override
  Future<bool> openTutorial() async {
    tutorials++;
    if (error != null) throw error!;
    return pending?.future ?? Future.value(result);
  }
}

Widget host(
        {Widget page = const AndroidAutoBillingPage(),
        FakeAndroidActions? android,
        FakeIOSActions? ios,
        bool supports = true,
        AutoBillingPlatform platform = AutoBillingPlatform.android}) =>
    ProviderScope(
        overrides: [
          autoBillingPlatformProvider.overrideWithValue(platform),
          autoBillingAndroidActionsFactoryProvider
              .overrideWithValue((_) => android ?? FakeAndroidActions()),
          iosAutoBillingActionsProvider
              .overrideWithValue(ios ?? FakeIOSActions()),
          iosAutoBillingSupportsAppIntentsProvider.overrideWithValue(supports)
        ],
        child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: page));
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(finder, 180, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Finder get monitor => find.descendant(
    of: find.byType(BeeAutoBillingMonitorCard), matching: find.byType(Switch));
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

void main() {
  for (final scenario in [
    'photos-granted',
    'photos-denied-storage-granted',
    'restricted-storage',
    'permanent-storage',
    'all-denied',
    'limited-storage'
  ]) {
    test('permission fallback $scenario opens only the expected adapter',
        () async {
      final calls = <String>[];
      final result = await requestAutoBillingScreenshotPermission(
          photosRestricted: () async {
        calls.add('restricted');
        return scenario == 'restricted-storage';
      }, photosPermanentlyDenied: () async {
        calls.add('permanent');
        return scenario == 'permanent-storage';
      }, requestPhotos: () async {
        calls.add('photos');
        return scenario == 'photos-granted'
            ? PermissionStatus.granted
            : scenario == 'limited-storage'
                ? PermissionStatus.limited
                : PermissionStatus.denied;
      }, requestStorage: () async {
        calls.add('storage');
        return scenario == 'all-denied'
            ? PermissionStatus.denied
            : PermissionStatus.granted;
      });
      expect(result, scenario != 'all-denied');
      if (scenario == 'photos-granted') {
        expect(calls, ['restricted', 'permanent', 'photos']);
      } else if (scenario == 'restricted-storage') {
        expect(calls, ['restricted', 'storage']);
      } else if (scenario == 'permanent-storage') {
        expect(calls, ['restricted', 'permanent', 'storage']);
      } else {
        expect(calls, ['restricted', 'permanent', 'photos', 'storage']);
      }
    });
  }
  test(
      'iOS production adapter preserves URLs and external application launch mode',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      calls.add(call);
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'), null));
    final actions = IOSAutoBillingActions();
    expect(await actions.openShortcut(), isTrue);
    expect(await actions.openTutorial(), isTrue);
    final launches = calls.where((call) => call.method == 'launch').toList();
    expect(launches, hasLength(2));
    expect((launches[0].arguments as Map)['url'],
        IOSAutoBillingActions.shortcutUri.toString());
    expect((launches[1].arguments as Map)['url'],
        IOSAutoBillingActions.tutorialUri.toString());
    for (final call in launches) {
      expect((call.arguments as Map)['useSafariVC'], isFalse);
      expect((call.arguments as Map)['useWebView'], isFalse);
    }
  });
  testWidgets(
      'Android reads state without permission or writes; explicit toggle enables and disables',
      (tester) async {
    final actions = FakeAndroidActions();
    await tester.pumpWidget(host(android: actions));
    await tester.pumpAndSettle();
    expect(actions.reads, 1);
    expect(actions.permissionRequests, 0);
    expect(actions.enables, 0);
    await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
    await tester.tap(monitor);
    await tester.pumpAndSettle();
    expect(actions.permissionRequests, 1);
    expect(actions.enables, 1);
    expect(tester.widget<Switch>(monitor).value, isTrue);
    await tester.tap(monitor);
    await tester.pumpAndSettle();
    expect(actions.disables, 1);
    expect(tester.widget<Switch>(monitor).value, isFalse);
    await finish(tester);
    expect(actions.disposals, 1);
  });
  testWidgets('permission denial preserves disabled value and allows retry',
      (tester) async {
    final actions = FakeAndroidActions()..granted = false;
    await tester.pumpWidget(host(android: actions));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
    await tester.tap(monitor);
    await tester.pumpAndSettle();
    expect(actions.enables, 0);
    expect(tester.widget<Switch>(monitor).value, isFalse);
    expect(tester.widget<Switch>(monitor).onChanged, isNotNull);
    final l = AppLocalizations.of(
        tester.element(find.byType(AndroidAutoBillingPage)));
    expect(find.text(l.photosPermissionRequired), findsOneWidget);
    actions.granted = true;
    await tester.tap(monitor);
    await tester.pumpAndSettle();
    expect(actions.enables, 1);
    await finish(tester);
  });
  for (final startingEnabled in [false, true]) {
    testWidgets(
        '${startingEnabled ? 'disable' : 'enable'} failure retains stored value',
        (tester) async {
      final actions = FakeAndroidActions()..enabled = startingEnabled;
      if (startingEnabled) {
        actions.disableError = StateError('QA failure');
      } else {
        actions.enableError = StateError('QA failure');
      }
      await tester.pumpWidget(host(android: actions));
      await tester.pumpAndSettle();
      await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
      await tester.tap(monitor);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(monitor).value, startingEnabled);
      expect(tester.widget<Switch>(monitor).onChanged, isNotNull);
      expect(find.textContaining('QA failure'), findsOneWidget);
      await finish(tester);
    });
  }
  testWidgets('pending enable disables repeated toggles until completion',
      (tester) async {
    final actions = FakeAndroidActions()..pendingEnable = Completer<void>();
    await tester.pumpWidget(host(android: actions));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
    await tester.tap(monitor);
    await tester.pump();
    expect(actions.enables, 1);
    expect(tester.widget<Switch>(monitor).value, isFalse);
    expect(tester.widget<Switch>(monitor).onChanged, isNull);
    actions.pendingEnable!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(monitor).value, isTrue);
    expect(actions.enables, 1);
    await finish(tester);
  });
  testWidgets(
      'status error can retry and resumed state reloads without requesting permission',
      (tester) async {
    final actions = FakeAndroidActions()..loadError = StateError('QA load');
    await tester.pumpWidget(host(android: actions));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('auto-billing-retry')));
    actions.loadError = null;
    await tester.tap(find.byKey(const ValueKey('auto-billing-retry')));
    await tester.pumpAndSettle();
    expect(actions.reads, 2);
    actions.enabled = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
    expect(tester.widget<Switch>(monitor).value, isTrue);
    expect(actions.permissionRequests, 0);
    expect(actions.enables, 0);
    await finish(tester);
  });
  testWidgets('closing during pending permission does not enable later',
      (tester) async {
    final actions = FakeAndroidActions()..pendingPermission = Completer<bool>();
    await tester.pumpWidget(host(android: actions));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(BeeAutoBillingMonitorCard));
    await tester.tap(monitor);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    actions.pendingPermission!.complete(true);
    await tester.pumpAndSettle();
    expect(actions.enables, 0);
    expect(actions.disposals, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing while loading ignores late results', (tester) async {
    final actions = FakeAndroidActions()..pendingRead = Completer<bool>();
    await tester.pumpWidget(host(android: actions));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    actions.pendingRead!.complete(true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(actions.disposals, 1);
  });
  for (final canRequest in [true, false]) {
    testWidgets(
        'battery dialog canRequest=$canRequest preserves confirm and settings decisions',
        (tester) async {
      final actions = FakeAndroidActions();
      actions.info['canRequest'] = canRequest;
      await tester.pumpWidget(host(android: actions));
      await tester.pumpAndSettle();
      final check = find.byKey(const ValueKey('auto-billing-check-battery'));
      await reveal(tester, check);
      await tester.tap(check);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(BeeAutoBillingBatteryDialog), findsOneWidget);
      expect(find.textContaining('QA maker'), findsOneWidget);
      expect(find.textContaining('QA device'), findsOneWidget);
      final settings =
          find.byKey(const ValueKey('auto-billing-battery-settings'));
      expect(settings, canRequest ? findsOneWidget : findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('auto-billing-battery-confirm')));
      await tester.pumpAndSettle();
      expect(actions.batteryRequests, 0);
      if (canRequest) {
        await tester.tap(check);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(settings);
        await tester.pumpAndSettle();
        expect(actions.batteryRequests, 1);
        await reveal(tester, find.byType(BeeAutoBillingBatteryCard));
        expect(
            tester
                .widget<BeeAutoBillingBatteryCard>(
                    find.byType(BeeAutoBillingBatteryCard))
                .healthy,
            isTrue);
      }
      await finish(tester);
    });
  }
  testWidgets(
      'iOS route has no Android switch and manual six steps start collapsed',
      (tester) async {
    final android = FakeAndroidActions(), ios = FakeIOSActions();
    await tester.pumpWidget(host(
        page: const AutoBillingSettingsPage(),
        android: android,
        ios: ios,
        platform: AutoBillingPlatform.ios));
    await tester.pumpAndSettle();
    expect(find.byType(IOSAutoBillingPage), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(android.reads, 0);
    expect(ios.imports, 0);
    await reveal(tester, find.byType(BeeAutoBillingManualGuide));
    final l =
        AppLocalizations.of(tester.element(find.byType(IOSAutoBillingPage)));
    expect(find.text(l.iosAutoShortcutStep1), findsNothing);
    await tester.tap(find.text(l.iosAutoManualConfigTitle));
    await tester.pumpAndSettle();
    expect(find.text(l.iosAutoShortcutStep1), findsOneWidget);
    expect(
        tester
            .widget<BeeAutoBillingManualGuide>(
                find.byType(BeeAutoBillingManualGuide))
            .steps,
        hasLength(6));
    await finish(tester);
  });
  testWidgets(
      'older iOS warning retains import action; declined import restores controls',
      (tester) async {
    final actions = FakeIOSActions()..result = false;
    await tester.pumpWidget(
        host(page: const IOSAutoBillingPage(), ios: actions, supports: false));
    await tester.pumpAndSettle();
    expect(find.byType(BeeAutoBillingVersionNotice), findsOneWidget);
    final button = find.byKey(const ValueKey('auto-billing-import-shortcut'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(actions.imports, 1);
    expect(tester.widget<BeeButton>(button).onPressed, isNotNull);
    final l =
        AppLocalizations.of(tester.element(find.byType(IOSAutoBillingPage)));
    expect(find.text(l.iosAutoImportFailed), findsOneWidget);
    await finish(tester);
  });
  testWidgets(
      'iOS import errors restore actions and tutorial opens only its own adapter',
      (tester) async {
    final actions = FakeIOSActions()..error = StateError('QA URL');
    await tester
        .pumpWidget(host(page: const IOSAutoBillingPage(), ios: actions));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('auto-billing-import-shortcut'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(tester.widget<BeeButton>(button).onPressed, isNotNull);
    actions.error = null;
    final tutorial = find.byKey(const ValueKey('auto-billing-tutorial'));
    await reveal(tester, tutorial);
    await tester.tap(tutorial);
    await tester.pumpAndSettle();
    expect(actions.imports, 1);
    expect(actions.tutorials, 1);
    await finish(tester);
  });
  testWidgets(
      'iOS pending import prevents duplicate external launches and tolerates disposal',
      (tester) async {
    final actions = FakeIOSActions()..pending = Completer<bool>();
    await tester
        .pumpWidget(host(page: const IOSAutoBillingPage(), ios: actions));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('auto-billing-import-shortcut'));
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pump();
    expect(actions.imports, 1);
    expect(tester.widget<BeeButton>(button).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    actions.pending!.complete(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('pure cards support 320px English text at 1.4 scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.4)),
                child: Scaffold(
                    body: SingleChildScrollView(
                        child: Column(children: [
                  BeeAutoBillingMonitorCard(
                      title: 'A long screenshot automation title',
                      status:
                          'Background permission is required for this feature',
                      enabled: false,
                      onChanged: (_) {}),
                  const SizedBox(height: 12),
                  BeeAutoBillingActionCard(
                      title: 'Get the preconfigured screenshot shortcut',
                      description:
                          'A detailed configuration guide with long English text and explanatory details.',
                      actionLabel: 'Get preconfigured shortcut',
                      onAction: () {}),
                  const BeeAutoBillingVersionNotice(
                      title: 'Requires iOS 16.0 or later',
                      description:
                          'This platform-specific notice does not claim availability on Android.')
                ])))))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

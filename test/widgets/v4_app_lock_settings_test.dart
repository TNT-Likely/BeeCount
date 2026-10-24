import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/pin_setup_page.dart';
import 'package:beecount/pages/settings/app_lock_settings_page.dart';
import 'package:beecount/presentation/v4/bindings/pin_verification.dart';
import 'package:beecount/providers/security_providers.dart';
import 'package:beecount/services/security/app_lock_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  bool supported = false, authenticated = false;
  int authentications = 0;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    supported = false;
    authenticated = false;
    authentications = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), (call) async {
      if (call.method == 'getAvailableBiometrics') {
        return supported ? ['fingerprint'] : <String>[];
      }
      if (call.method == 'authenticate') {
        authentications++;
        return authenticated;
      }
      return supported;
    });
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null);
  });
  Future<void> open(WidgetTester t,
      {bool enabled = false, bool compact = false, int timeout = 0}) async {
    if (enabled) await AppLockService.setPin('7391');
    await AppLockService.setTimeoutSeconds(timeout);
    await container.read(securityInitProvider.future);
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: Locale(compact ? 'en' : 'zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                child: child!),
            home: const AppLockSettingsPage())));
    await t.pumpAndSettle();
  }

  AppLocalizations texts(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AppLockSettingsPage)));
  Future<void> digits(WidgetTester t, String value) async {
    for (final digit in value.split('')) {
      final key = find.descendant(
          of: find.byType(BeePinPad), matching: find.text(digit));
      await t.ensureVisible(key);
      await t.tap(key);
      await t.pump();
    }
    await t.pump();
  }

  Future<void> back(WidgetTester t) async {
    await t.tap(find.byType(BeeSheet).evaluate().isNotEmpty
        ? find.byType(CloseButton)
        : find.byType(BackButton));
    await t.pumpAndSettle();
  }

  Future<void> row(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text));
    await t.pumpAndSettle();
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  Future<void> disposePage(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump(const Duration(seconds: 2));
  }

  testWidgets('未启用仅展示开关；设置取消不保存密码或打开其他选项', (t) async {
    await open(t);
    final l = texts(t);
    expect(find.byType(BeeToggleRow), findsOneWidget);
    expect(find.text(l.appLockChangePin), findsNothing);
    expect(find.text(l.appLockTimeout), findsNothing);
    await row(t, l.appLockEnable);
    expect(find.byType(PinSetupPage), findsOneWidget);
    await digits(t, '73');
    await back(t);
    expect(await AppLockService.hasPin(), isFalse);
    expect(await AppLockService.isEnabled(), isFalse);
    expect(container.read(appLockEnabledProvider), isFalse);
    expect(t.takeException(), isNull);
    await disposePage(t);
  });
  testWidgets('开启沿用原创建确认；修改入口要求旧密码并支持取消', (t) async {
    await open(t);
    final l = texts(t);
    await row(t, l.appLockEnable);
    await digits(t, '7391');
    await digits(t, '7391');
    await t.pumpAndSettle();
    expect(await AppLockService.verifyPin('7391'), isTrue);
    expect(container.read(appLockEnabledProvider), isTrue);
    await row(t, l.appLockChangePin);
    expect(t.widget<PinSetupPage>(find.byType(PinSetupPage)).mode,
        PinSetupMode.change);
    expect(find.text(l.appLockVerifyCurrentPin), findsOneWidget);
    await back(t);
    expect(await AppLockService.verifyPin('7391'), isTrue);
    expect(find.text(l.appLockTimeout), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposePage(t);
  });
  testWidgets('关闭必须验证；错误恢复和返回均保留原哈希，正确后清除密码与生物识别', (t) async {
    await open(t, enabled: true);
    await AppLockService.setBiometricEnabled(true);
    container.read(appLockBiometricEnabledProvider.notifier).state = true;
    final l = texts(t);
    await row(t, l.appLockEnable);
    expect(find.byType(PinVerificationPage), findsOneWidget);
    await digits(t, '9999');
    expect(t.widget<BeePinPad>(find.byType(BeePinPad)).invalid, isTrue);
    expect(await AppLockService.verifyPin('7391'), isTrue);
    expect(await AppLockService.isEnabled(), isTrue);
    await t.pump(const Duration(milliseconds: 600));
    await digits(t, '73');
    await back(t);
    expect(await AppLockService.verifyPin('7391'), isTrue);
    await row(t, l.appLockEnable);
    await digits(t, '7391');
    await t.pumpAndSettle();
    expect(await AppLockService.hasPin(), isFalse);
    expect(await AppLockService.isEnabled(), isFalse);
    expect(await AppLockService.isBiometricEnabled(), isFalse);
    expect(container.read(appLockEnabledProvider), isFalse);
    expect(container.read(appLockBiometricEnabledProvider), isFalse);
    expect(find.text(l.appLockChangePin), findsNothing);
    expect(t.takeException(), isNull);
    await disposePage(t);
  });
  testWidgets('原四档超时即时保存与回显，取消不改当前选择', (t) async {
    await open(t, enabled: true);
    final l = texts(t);
    for (final option in [
      (0, l.appLockTimeoutImmediate),
      (60, l.appLockTimeout1Min),
      (300, l.appLockTimeout5Min),
      (900, l.appLockTimeout15Min)
    ]) {
      await row(t, l.appLockTimeout);
      expect(find.byType(BeeSheet), findsOneWidget);
      final choices = find.descendant(
          of: find.byType(BeeSheet), matching: find.byType(BeeMenuRow));
      expect(choices, findsNWidgets(4));
      final target = find.descendant(
          of: find.byType(BeeSheet), matching: find.text(option.$2));
      await t.ensureVisible(target);
      await t.pumpAndSettle();
      await t.tap(target);
      await t.pumpAndSettle();
      expect(await AppLockService.getTimeoutSeconds(), option.$1);
      expect(container.read(appLockTimeoutProvider), option.$1);
      expect(find.text(option.$2), findsOneWidget);
    }
    await row(t, l.appLockTimeout);
    await back(t);
    expect(await AppLockService.getTimeoutSeconds(), 900);
    expect(t.takeException(), isNull);
    await disposePage(t);
  });
  testWidgets('历史非预设秒数原样显示；不支持生物识别时隐藏，关闭不改超时', (t) async {
    await open(t, enabled: true, timeout: 42);
    final l = texts(t);
    expect(find.text('42s'), findsOneWidget);
    expect(find.text(l.appLockBiometric), findsNothing);
    await row(t, l.appLockTimeout);
    expect(
        t
            .widgetList<BeeMenuRow>(find.descendant(
                of: find.byType(BeeSheet), matching: find.byType(BeeMenuRow)))
            .any((w) => w.selected),
        isFalse);
    await back(t);
    expect(await AppLockService.getTimeoutSeconds(), 42);
    await disposePage(t);
  });
  testWidgets('生物识别必须通过系统结果，失败不启用；关闭不重复请求认证', (t) async {
    supported = true;
    await open(t, enabled: true);
    final l = texts(t);
    expect(find.text(l.appLockBiometric), findsOneWidget);
    await row(t, l.appLockBiometric);
    expect(authentications, 1);
    expect(await AppLockService.isBiometricEnabled(), isFalse);
    authenticated = true;
    await row(t, l.appLockBiometric);
    expect(authentications, 2);
    expect(await AppLockService.isBiometricEnabled(), isTrue);
    expect(container.read(appLockBiometricEnabledProvider), isTrue);
    await row(t, l.appLockBiometric);
    expect(authentications, 2);
    expect(await AppLockService.isBiometricEnabled(), isFalse);
    expect(t.takeException(), isNull);
    await disposePage(t);
  });
  testWidgets('320英文深色140%开关与四档选择可达，密码验证复用紧凑键盘', (t) async {
    supported = true;
    await open(t, enabled: true, compact: true);
    final l = texts(t);
    await row(t, l.appLockTimeout);
    final target = find.descendant(
        of: find.byType(BeeSheet), matching: find.text(l.appLockTimeout15Min));
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
    expect(await AppLockService.getTimeoutSeconds(), 900);
    await row(t, l.appLockEnable);
    await digits(t, '73');
    expect(t.widget<BeePinPad>(find.byType(BeePinPad)).filled, 2);
    expect(t.takeException(), isNull);
    await back(t);
    expect(await AppLockService.verifyPin('7391'), isTrue);
    await disposePage(t);
  });
}

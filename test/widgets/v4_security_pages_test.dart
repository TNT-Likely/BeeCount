import 'dart:convert';
import 'dart:io';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/auth/app_lock_screen.dart';
import 'package:beecount/pages/auth/pin_setup_page.dart';
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'),
            (call) async =>
                call.method == 'getAvailableBiometrics' ? <String>[] : false);
  });
  tearDown(() {
    container.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/local_auth'), null);
  });
  Future<void> open(WidgetTester tester, Widget page,
      {Size size = const Size(398, 844),
      double scale = 1,
      Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(brightness: brightness),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => page)),
                        child: const Text('打开')))))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  Future<void> digits(WidgetTester tester, String value) async {
    for (final digit in value.split('')) {
      final key = find.descendant(
          of: find.byType(BeePinPad), matching: find.text(digit));
      await tester.ensureVisible(key);
      await tester.tap(key);
      await tester.pump();
    }
    await tester.pump();
  }

  Future<void> disposePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('四位新密码确认后沿用原哈希服务并启用应用锁，不保存明文', (tester) async {
    await open(tester, const PinSetupPage());
    expect(tester.widget<BeePinPad>(find.byType(BeePinPad)).length, 4);
    await digits(tester, '1234');
    expect(find.text('请再次输入密码'), findsOneWidget);
    expect(await AppLockService.hasPin(), isFalse);
    await digits(tester, '1234');
    await tester.pumpAndSettle();
    expect(find.byType(PinSetupPage), findsNothing);
    expect(await AppLockService.verifyPin('1234'), isTrue);
    expect(await AppLockService.isEnabled(), isTrue);
    expect(container.read(appLockEnabledProvider), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString('app_lock_pin_hash'), AppLockService.hashPin('1234'));
    expect(prefs.getKeys().any((k) => prefs.get(k) == '1234'), isFalse);
    await disposePage(tester);
  });
  testWidgets('确认不一致只显示错误，半秒后回到新密码，不写入偏好', (tester) async {
    await open(tester, const PinSetupPage());
    await digits(tester, '1111');
    await digits(tester, '2222');
    expect(tester.widget<BeePinPad>(find.byType(BeePinPad)).invalid, isTrue);
    expect(await AppLockService.hasPin(), isFalse);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('请设置新密码'), findsOneWidget);
    expect(tester.widget<BeePinPad>(find.byType(BeePinPad)).filled, 0);
    await digits(tester, '12');
    final pad = tester.widget<BeePinPad>(find.byType(BeePinPad));
    expect(pad.filled, 2);
    await tester.tap(find.bySemanticsLabel('删除').first);
    await tester.pump();
    expect(tester.widget<BeePinPad>(find.byType(BeePinPad)).filled, 1);
    await disposePage(tester);
    expect(await AppLockService.hasPin(), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets('修改必须验证旧密码，错误与中途返回均保留旧哈希', (tester) async {
    await AppLockService.setPin('1234');
    await open(tester, const PinSetupPage(mode: PinSetupMode.change));
    await digits(tester, '9999');
    expect(tester.widget<BeePinPad>(find.byType(BeePinPad)).invalid, isTrue);
    expect(await AppLockService.verifyPin('1234'), isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('请输入当前密码'), findsOneWidget);
    await digits(tester, '1234');
    expect(find.text('请设置新密码'), findsOneWidget);
    await digits(tester, '5678');
    expect(find.text('请再次输入密码'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('返回').first);
    await tester.pumpAndSettle();
    expect(await AppLockService.verifyPin('1234'), isTrue);
    expect(await AppLockService.verifyPin('5678'), isFalse);
    await disposePage(tester);
  });
  testWidgets('修改确认后只接受新密码，锁屏错误恢复后才解锁', (tester) async {
    await AppLockService.setPin('1234');
    await open(tester, const PinSetupPage(mode: PinSetupMode.change));
    for (final value in ['1234', '5678', '5678']) {
      await digits(tester, value);
    }
    await tester.pumpAndSettle();
    expect(await AppLockService.verifyPin('1234'), isFalse);
    expect(await AppLockService.verifyPin('5678'), isTrue);
    await disposePage(tester);
    container.read(isAppLockedProvider.notifier).state = true;
    await open(tester, const AppLockScreen());
    await digits(tester, '9999');
    expect(container.read(isAppLockedProvider), isTrue);
    await tester.pump(const Duration(milliseconds: 600));
    await digits(tester, '5678');
    expect(container.read(isAppLockedProvider), isFalse);
    expect(await AppLockService.verifyPin('5678'), isTrue);
    await disposePage(tester);
    expect(tester.takeException(), isNull);
  });
  final geometry = jsonDecode(
          File('test/fixtures/v4-security-geometry.json').readAsStringSync())
      as Map<String, dynamic>;
  for (final expected in geometry['geometry'] as List) {
    testWidgets('安全键盘尺寸对齐冻结 HTML ${expected['viewport']}', (tester) async {
      final dimensions = (expected['viewport'] as String)
          .split('x')
          .map(double.parse)
          .toList();
      await open(tester, const PinSetupPage(),
          size: Size(dimensions[0], dimensions[1]));
      Finder key(String number) => find.ancestor(
          of: find.descendant(
              of: find.byType(BeePinPad), matching: find.text(number)),
          matching: find.byType(FilledButton));
      final one = tester.getRect(key('1')), two = tester.getRect(key('2'));
      expect(one.width, closeTo((expected['width'] as num).toDouble(), 1));
      expect(one.height, closeTo((expected['height'] as num).toDouble(), 1));
      expect(two.left - one.right, expected['gridGap']);
      final style = tester.widget<FilledButton>(key('1')).style!;
      final shape = style.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius,
          BorderRadius.circular((expected['radius'] as num).toDouble()));
      expect(tester.widget<Text>(find.text('1')).style!.fontSize,
          expected['font']);
      await disposePage(tester);
    });
  }
  for (final brightness in Brightness.values) {
    for (final size in [const Size(398, 844), const Size(320, 568)]) {
      testWidgets('安全输入无裁切且数字可达 $brightness $size 140%', (tester) async {
        await open(tester, const PinSetupPage(),
            size: size, scale: 1.4, brightness: brightness);
        expect(find.byType(BeeSecurityPanel), findsOneWidget);
        await digits(tester, '1234');
        expect(find.text('请再次输入密码'), findsOneWidget);
        final zero = find.descendant(
            of: find.byType(BeePinPad), matching: find.text('0'));
        await tester.ensureVisible(zero);
        await tester.pumpAndSettle();
        expect(tester.getBottomRight(zero).dy, lessThanOrEqualTo(size.height));
        final deleteIcon = tester
            .widgetList<BeeLineIcon>(find.byType(BeeLineIcon))
            .singleWhere((icon) => icon.name == 'Delete');
        final context = tester.element(find.byType(BeePinPad));
        expect(deleteIcon.color, Theme.of(context).colorScheme.onSurface,
            reason: '数字按钮的图标不能继承导航页的黑色 IconTheme');
        expect(tester.takeException(), isNull);
        await disposePage(tester);
      });
    }
  }
}

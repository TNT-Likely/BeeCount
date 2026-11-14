import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final calls = <Map<Object?, Object?>>[];
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        calls.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    });
    calls.clear();
    // Invalidate SystemChrome's process-wide cache before each rendered scene.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.pink,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark));
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('真实 Theme 动画切换更新平台状态栏，保留表单状态且不写导航栏', (t) async {
    final mode = ValueNotifier(ThemeMode.light);
    addTearDown(mode.dispose);
    await t.pumpWidget(ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (_, selected, __) => MaterialApp(
            theme: beeTheme(),
            darkTheme: beeTheme(brightness: Brightness.dark),
            themeMode: selected,
            builder: (_, child) => BeeSystemBars(child: child!),
            home: const Scaffold(body: TextField()))));
    await t.pump();
    expect(calls, isNotEmpty);
    expect(calls.last['statusBarIconBrightness'], 'Brightness.dark');
    expect(calls.last['statusBarBrightness'], 'Brightness.light');
    expect(calls.last['statusBarColor'], 0);
    await t.enterText(find.byType(TextField), '保留未提交备注');
    mode.value = ThemeMode.dark;
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(calls.last['statusBarIconBrightness'], 'Brightness.light');
    expect(calls.last['statusBarBrightness'], 'Brightness.dark');
    expect(find.text('保留未提交备注'), findsOneWidget);
    for (final name in [
      'systemNavigationBarColor',
      'systemNavigationBarDividerColor',
      'systemNavigationBarIconBrightness',
      'systemNavigationBarContrastEnforced',
      'systemStatusBarContrastEnforced'
    ]) {
      expect(calls.last[name], isNull, reason: '$name 不应被全局包装重设');
    }
    mode.value = ThemeMode.light;
    await t.pump();
    await t.pump(const Duration(milliseconds: 250));
    expect(calls.last['statusBarIconBrightness'], 'Brightness.dark');
    expect(find.text('保留未提交备注'), findsOneWidget);
  });

  testWidgets('内层 header annotation 继续覆写状态栏，移除后恢复主题默认', (t) async {
    final override = ValueNotifier(true);
    addTearDown(override.dispose);
    await t.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        builder: (_, child) => BeeSystemBars(child: child!),
        home: Scaffold(
            body: ValueListenableBuilder<bool>(
                valueListenable: override,
                builder: (_, enabled, __) => Column(children: [
                      if (enabled)
                        const AnnotatedRegion<SystemUiOverlayStyle>(
                            value: SystemUiOverlayStyle(
                                statusBarColor: Colors.blue,
                                statusBarIconBrightness: Brightness.dark,
                                statusBarBrightness: Brightness.light),
                            child:
                                SizedBox(height: 100, width: double.infinity)),
                      const Expanded(child: SizedBox.expand())
                    ])))));
    await t.pump();
    expect(calls.last['statusBarColor'], 0xff2196f3);
    expect(calls.last['statusBarIconBrightness'], 'Brightness.dark');
    override.value = false;
    await t.pump();
    expect(calls.last['statusBarColor'], 0);
    expect(calls.last['statusBarIconBrightness'], 'Brightness.light');
    expect(t.takeException(), isNull);
  });
}

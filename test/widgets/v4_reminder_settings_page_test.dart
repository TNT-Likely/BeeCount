import 'dart:async';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/reminder_settings_page.dart';
import 'package:beecount/pages/settings/reminders/bindings/reminder_diagnostics.dart';
import 'package:beecount/dev/component_gallery/bindings/reminder_preview.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/app_localizations_resolver.dart';
import 'package:beecount/utils/notification_util.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Capture only OS calls. The page, notifier, preferences, localization and DB
// remain real. These records never claim that a notification was delivered.
class _Notifications implements NotificationUtil {
  final schedules =
      <({int id, int hour, int minute, String title, String body})>[];
  final canceled = <int>[], shown = <({int id, String title, String body})>[];
  bool failShow = false;
  Completer<void>? pending;
  @override
  Future<void> scheduleDailyReminder(
      {required int id,
      required String title,
      required String body,
      required int hour,
      required int minute}) async {
    schedules
        .add((id: id, hour: hour, minute: minute, title: title, body: body));
  }

  @override
  Future<void> cancelNotification(int id) async {
    canceled.add(id);
  }

  @override
  Future<void> showNotification(
      {required int id, required String title, required String body}) async {
    shown.add((id: id, title: title, body: body));
    if (failShow) throw StateError('合成OS失败');
    await pending?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Diagnostics implements ReminderDiagnostics {
  Map<String, dynamic> battery = {
    'manufacturer': 'QA',
    'model': 'Synthetic',
    'androidVersion': '15',
    'isIgnoring': false,
    'canRequest': true
  };
  Map<String, dynamic> channel = {
    'isEnabled': false,
    'importance': 'low',
    'sound': false,
    'vibration': false,
    'bypassDnd': false
  };
  int requests = 0, channelOpens = 0, appOpens = 0;
  @override
  Future<Map<String, dynamic>> batteryInfo() async => battery;
  @override
  Future<Map<String, dynamic>> channelInfo() async => channel;
  @override
  Future<void> requestBatteryExemption() async {
    requests++;
  }

  @override
  Future<void> openChannelSettings() async {
    channelOpens++;
  }

  @override
  Future<void> openAppSettings() async {
    appOpens++;
  }
}

void main() {
  late BeeDatabase db;
  late ProviderContainer container;
  late _Notifications os;
  late _Diagnostics diagnostics;
  ProviderContainer makeContainer(
          {ReminderHostPlatform platform = ReminderHostPlatform.android}) =>
      ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        repositoryProvider.overrideWithValue(LocalRepository(db)),
        reminderNotificationsProvider.overrideWithValue(os),
        reminderDiagnosticsProvider.overrideWithValue(diagnostics),
        reminderHostPlatformProvider.overrideWithValue(platform),
      ]);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'auto_sync': false,
      'selected_language': 'zh',
      'reminder_enabled': false,
      'reminder_hour': 21,
      'reminder_minute': 0
    });
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'提醒验收','CNY')");
    os = _Notifications();
    diagnostics = _Diagnostics();
    container = makeContainer();
    await container
        .read(languageProvider.notifier)
        .setLanguage(const Locale('zh'));
  });
  tearDown(() async {
    container.dispose();
    setAppLocaleOverride(null);
    await db.close();
  });
  Future<void> open(WidgetTester t,
      {bool compact = false, bool english = false}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = compact ? const Size(320, 568) : const Size(398, 844);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(
                brightness: compact ? Brightness.dark : Brightness.light),
            locale: Locale(english ? 'en' : 'zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(compact ? 1.4 : 1)),
                child: child!),
            home: const ReminderSettingsPage())));
    await t.pumpAndSettle();
  }

  AppLocalizations strings(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(ReminderSettingsPage)));
  Future<void> click(WidgetTester t, String text) async {
    final scroll = find.byType(Scrollable).first;
    t.state<ScrollableState>(scroll).position.jumpTo(0);
    await t.pump();
    await t.scrollUntilVisible(find.text(text), 160, scrollable: scroll);
    await t.ensureVisible(find.text(text));
    await t.tap(find.text(text));
    await t.pumpAndSettle();
  }

  Future<TimeOfDay> changeMinute(WidgetTester t) async {
    await t.drag(find.byType(BeeWheel<int>).last, const Offset(0, -44));
    await t.pumpAndSettle();
    final value = t.widget<BeeTimeWheels>(find.byType(BeeTimeWheels)).value;
    expect(value.minute, greaterThan(0));
    return value;
  }

  Future<void> finish(WidgetTester t) async {
    await t.pump(const Duration(seconds: 3));
    await t.pumpWidget(const SizedBox.shrink());
    await t.pump();
    expect(t.takeException(), isNull);
  }

  testWidgets('原真实偏好启停、取消与确认时间、原ID与通知文案、重新载入', (t) async {
    await open(t);
    final l = strings(t);
    await t.tap(find.byType(BeeToggleRow));
    await t.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reminder_enabled'), true);
    expect(os.schedules.single.id, 1001);
    expect(os.schedules.single.title, l.reminderTitle);
    expect(os.schedules.single.body, l.reminderDailyBody);
    await click(t, l.reminderTimeTitle);
    await changeMinute(t);
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    expect(prefs.getInt('reminder_minute'), 0);
    expect(os.schedules, hasLength(1));
    await click(t, l.reminderTimeTitle);
    expect(t.widget<BeeTimeWheels>(find.byType(BeeTimeWheels)).value,
        const TimeOfDay(hour: 21, minute: 0));
    final value = await changeMinute(t);
    await t.tap(find.text(l.commonOk));
    await t.pumpAndSettle();
    expect(prefs.getInt('reminder_hour'), value.hour);
    expect(prefs.getInt('reminder_minute'), value.minute);
    expect(os.schedules.last.minute, value.minute);
    await t.pumpWidget(const SizedBox.shrink());
    container.dispose();
    container = makeContainer();
    await open(t);
    expect(container.read(reminderSettingsProvider).minute, value.minute);
    expect(
        t
            .widget<BeeReminderPreferences>(find.byType(BeeReminderPreferences))
            .enabled,
        true);
    await t.tap(find.byType(BeeToggleRow));
    await t.pumpAndSettle();
    expect(prefs.getBool('reminder_enabled'), false);
    expect(os.canceled, [1001]);
    expect(await db.customSelect('SELECT * FROM transactions').get(), isEmpty);
    expect(await db.customSelect('SELECT * FROM ledgers').get(), hasLength(1));
    await finish(t);
  });
  testWidgets('关闭状态仍可改时间，取消关闭弹层不保存；测试通知失败反馈与原ID', (t) async {
    await open(t);
    final l = strings(t);
    await click(t, l.reminderTimeTitle);
    await changeMinute(t);
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(container.read(reminderSettingsProvider).minute, 0);
    expect(os.schedules, isEmpty);
    await click(t, l.reminderTimeTitle);
    final time = await changeMinute(t);
    await t.tap(find.text(l.commonOk));
    await t.pumpAndSettle();
    expect(container.read(reminderSettingsProvider).minute, time.minute);
    expect(os.schedules, isEmpty);
    await click(t, l.reminderTestNotification);
    expect(os.shown.single.id, 9999);
    expect(os.shown.single.title, l.reminderTestTitle);
    expect(find.byType(BeeToast), findsOneWidget);
    os.failShow = true;
    await click(t, l.reminderTestNotification);
    expect(t.widget<BeeToast>(find.byType(BeeToast)).tone, BeeTone.error);
    expect(find.text(l.commonError), findsOneWidget);
    await finish(t);
  });
  testWidgets('320深色大字保留电池/渠道全部字段和原设置分支，关闭后滚动位置稳定', (t) async {
    await open(t, compact: true);
    final l = strings(t);
    await click(t, l.reminderCheckBattery);
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(find.text(l.reminderManufacturer('QA')), findsOneWidget);
    expect(find.text(l.reminderModel('Synthetic')), findsOneWidget);
    expect(find.text(l.reminderAndroidVersion('15')), findsOneWidget);
    await t.tap(find.text(l.commonSettings));
    await t.pumpAndSettle();
    expect(diagnostics.requests, 1);
    diagnostics.battery['isIgnoring'] = true;
    await click(t, l.reminderCheckBattery);
    expect(find.text(l.commonSettings), findsNothing);
    await t.tap(find.text(l.commonConfirm));
    await t.pumpAndSettle();
    final pageScroll =
        t.state<ScrollableState>(find.byType(Scrollable).first).position;
    await click(t, l.reminderCheckChannel);
    final position = pageScroll.pixels;
    for (final label in [
      l.reminderChannelDisabled,
      l.reminderChannelImportance('low'),
      l.reminderChannelSoundOff,
      l.reminderChannelVibrationOff,
      l.reminderChannelDndNoBypass,
      l.reminderChannelAdviceImportance,
      l.reminderChannelAdviceSound,
      l.reminderChannelAdviceBanner,
      l.reminderChannelAdviceXiaomi
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await t.tap(find.byType(CloseButton));
    await t.pumpAndSettle();
    expect(pageScroll.pixels, closeTo(position, 1));
    expect(diagnostics.channelOpens, 0);
    diagnostics.channel = {
      'isEnabled': true,
      'importance': 'high',
      'sound': true,
      'vibration': true
    };
    await click(t, l.reminderCheckChannel);
    expect(find.text(l.reminderChannelGood), findsOneWidget);
    await t.tap(find.text(l.commonSettings));
    await t.pumpAndSettle();
    expect(diagnostics.channelOpens, 1);
    await click(t, l.reminderOpenAppSettings);
    expect(diagnostics.appOpens, 1);
    await finish(t);
  });
  testWidgets('iOS英文320隐藏Android专属诊断，保留说明和两小时分钟滚轮', (t) async {
    container.dispose();
    container = makeContainer(platform: ReminderHostPlatform.ios);
    await open(t, compact: true, english: true);
    final l = strings(t);
    expect(find.text(l.reminderCheckBattery), findsNothing);
    expect(find.text(l.reminderCheckChannel), findsNothing);
    expect(find.text(l.reminderOpenAppSettings), findsNothing);
    await click(t, l.reminderTimeTitle);
    expect(find.byType(BeeWheel<int>), findsNWidgets(2));
    await t.tap(find.text(l.commonCancel));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text(l.reminderIOSInstructions), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(l.reminderIOSInstructions), findsOneWidget);
    await finish(t);
  });
  testWidgets('真实偏好预览只读，明确进入生产页后修改并回流同一Provider', (t) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', true);
    await prefs.setInt('reminder_hour', 19);
    await prefs.setInt('reminder_minute', 8);
    await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: LiveReminderPreview()))));
    await t.pumpAndSettle();
    final preview =
        t.widget<BeeReminderPreferences>(find.byType(BeeReminderPreferences));
    expect(preview.enabled, true);
    expect(preview.time, '19:08');
    expect(preview.onEnabled, isNull);
    expect(os.schedules, isEmpty);
    await t.tap(find.text('打开真实记账提醒设置'));
    await t.pumpAndSettle();
    expect(find.byType(ReminderSettingsPage), findsOneWidget);
    await t.tap(find.byType(BeeToggleRow));
    await t.pumpAndSettle();
    expect(prefs.getBool('reminder_enabled'), false);
    expect(os.canceled, [1001]);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(
        t
            .widget<BeeReminderPreferences>(find.byType(BeeReminderPreferences))
            .enabled,
        false);
    await finish(t);
  });
  testWidgets('通知处理中禁重复，退页后完成不访问失效context', (t) async {
    await open(t);
    final l = strings(t);
    os.pending = Completer<void>();
    await t.tap(find.text(l.reminderTestNotification));
    await t.pump();
    expect(os.shown, hasLength(1));
    final button = t.widget<BeeButton>(
        find.widgetWithText(BeeButton, l.reminderTestNotification));
    expect(button.onPressed, isNull);
    await t.pumpWidget(const SizedBox.shrink());
    os.pending!.complete();
    await t.pump();
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });
}

import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/smart_billing_page.dart';
import 'package:beecount/presentation/v4/bindings/smart_billing_entries.dart';
import 'package:beecount/providers/attachment_settings_providers.dart';
import 'package:beecount/providers/smart_billing_providers.dart';
import 'package:beecount/providers/voice_billing_providers.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer c;
  late SharedPreferences prefs;
  var configChanges = 0;
  ProviderContainer container(SmartBillingAvailability p) => ProviderContainer(
      overrides: [smartBillingAvailabilityProvider.overrideWithValue(p)]);
  Future<void> initialize() async {
    await c.read(smartBillingAutoTagsInitProvider.future);
    await c.read(smartBillingAutoAttachmentInitProvider.future);
    await c.read(attachmentKeepOriginalProvider.future);
    await c.read(voiceBillingSettingsProvider.notifier).ensureLoaded();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'smartBillingAutoTags': true,
      'smartBillingAutoAttachment': false,
      'attachmentKeepOriginal': false,
      AIConstants.keyVoiceTriggerMode: 'auto',
      AIConstants.keyVoiceSilenceTimeoutMs: 1500
    });
    prefs = await SharedPreferences.getInstance();
    configChanges = 0;
    AIProviderManager.onConfigChanged = () => configChanges++;
    c = container(
        const SmartBillingAvailability(android: true, googlePlay: false));
    await initialize();
  });
  tearDown(() {
    c.dispose();
    AIProviderManager.onConfigChanged = null;
  });
  Future<void> open(WidgetTester t,
      {bool narrow = false, SmartBillingAvailability? policy}) async {
    if (policy != null) {
      c.updateOverrides(
          [smartBillingAvailabilityProvider.overrideWithValue(policy)]);
    }
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: narrow ? const Locale('en') : const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: const SmartBillingPage())));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(SmartBillingPage)));
  Future<void> tapVisible(WidgetTester t, Finder target) async {
    await t.ensureVisible(target);
    await t.pumpAndSettle();
    await t.tap(target);
    await t.pumpAndSettle();
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
  }

  testWidgets('三个原设置真实持久化并在新容器恢复', (t) async {
    await open(t);
    final x = l(t);
    for (final title in [
      x.smartBillingAutoTags,
      x.smartBillingAutoAttachment,
      x.attachmentKeepOriginal
    ]) {
      await tapVisible(t, find.widgetWithText(BeeToggleRow, title));
    }
    expect(prefs.getBool('smartBillingAutoTags'), false);
    expect(prefs.getBool('smartBillingAutoAttachment'), true);
    expect(prefs.getBool('attachmentKeepOriginal'), true);
    await close(t);
    c.dispose();
    c = container(
        const SmartBillingAvailability(android: true, googlePlay: false));
    await initialize();
    expect(c.read(smartBillingAutoTagsProvider), false);
    expect(c.read(smartBillingAutoAttachmentProvider), true);
    expect(c.read(attachmentKeepOriginalProvider).valueOrNull, true);
  });
  testWidgets('四种引导保持弹窗，完整原描述/AI要求/操作提示，不改变滚动位置', (t) async {
    await open(t);
    final x = l(t);
    for (final (title, desc, req, hint) in [
      (
        x.smartBillingImageBilling,
        x.smartBillingImageBillingGuide,
        x.smartBillingVisionAIRequired,
        x.smartBillingGuideHint
      ),
      (
        x.smartBillingCameraBilling,
        x.smartBillingCameraBillingGuide,
        x.smartBillingVisionAIRequired,
        x.smartBillingGuideHint
      ),
      (
        x.smartBillingVoiceBilling,
        x.smartBillingVoiceBillingGuide,
        x.smartBillingAIRequired,
        x.smartBillingGuideHint
      ),
      (
        x.shareBilling,
        x.shareBillingGuide,
        x.smartBillingVisionAIRequired,
        x.shareBillingActionHint
      )
    ]) {
      final row = find.widgetWithText(BeeMenuRow, title);
      await t.ensureVisible(row);
      await t.pumpAndSettle();
      final scroll = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .pixels;
      await t.tap(row);
      await t.pumpAndSettle();
      expect(find.byType(BeeDialog), findsOneWidget);
      final guide = t.widget<BeeBillingGuide>(find.byType(BeeBillingGuide));
      expect(guide.description, desc);
      expect(guide.requirement, req);
      expect(guide.actionHint, hint);
      await t.tap(find.text(x.commonKnow));
      await t.pumpAndSettle();
      expect(
          t
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .pixels,
          scroll);
    }
    expect(configChanges, 0);
    await close(t);
  });
  for (final policy in [
    const SmartBillingAvailability(android: true, googlePlay: false),
    const SmartBillingAvailability(android: true, googlePlay: true),
    const SmartBillingAvailability(android: false, googlePlay: false)
  ]) {
    testWidgets('平台/渠道原入口规则 android=${policy.android} GP=${policy.googlePlay}',
        (t) async {
      await open(t, policy: policy);
      final x = l(t);
      expect(find.widgetWithText(BeeMenuRow, x.shareBilling),
          policy.share ? findsOneWidget : findsNothing);
      final title = policy.android
          ? x.autoScreenshotBilling
          : x.autoScreenshotBillingIosTitle;
      expect(find.widgetWithText(BeeMenuRow, title),
          policy.screenshot ? findsOneWidget : findsNothing);
      expect(find.widgetWithText(BeeMenuRow, x.shortcutsGuide), findsOneWidget);
      expect(
          find.widgetWithText(BeeMenuRow, x.aiSettingsTitle), findsOneWidget);
      await close(t);
    });
  }
  testWidgets('滑杆拖动只预览，松手才保存并通知配置；触发方式选择即保存/取消保持', (t) async {
    await open(t);
    final x = l(t), slider = find.byType(Slider);
    await t.ensureVisible(slider);
    await t.pumpAndSettle();
    final bounds = t.getRect(slider),
        gesture = await t.startGesture(bounds.center);
    await gesture.moveTo(Offset(bounds.right - 1, bounds.center.dy));
    await t.pump();
    expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 1500);
    expect(c.read(voiceBillingSettingsProvider).silenceTimeoutMs, 1500);
    expect(configChanges, 0);
    await gesture.up();
    await t.pumpAndSettle();
    expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 4000);
    expect(configChanges, 1);
    await tapVisible(
        t, find.widgetWithText(BeeMenuRow, x.smartBillingVoiceTrigger));
    expect(find.byType(BeeDialog), findsOneWidget);
    await t.tap(find.text(x.voiceTriggerModeHold));
    await t.pumpAndSettle();
    expect(prefs.getString(AIConstants.keyVoiceTriggerMode), 'hold_to_talk');
    expect(find.byType(Slider), findsNothing);
    await tapVisible(
        t, find.widgetWithText(BeeMenuRow, x.smartBillingVoiceTrigger));
    await t.tap(find.text(x.commonCancel));
    await t.pumpAndSettle();
    expect(prefs.getString(AIConstants.keyVoiceTriggerMode), 'hold_to_talk');
    await tapVisible(
        t, find.widgetWithText(BeeMenuRow, x.smartBillingVoiceTrigger));
    await t.tap(find.text(x.voiceTriggerModeAuto));
    await t.pumpAndSettle();
    expect(c.read(voiceBillingSettingsProvider).silenceTimeoutMs, 4000);
    expect(find.byType(Slider), findsOneWidget);
    await close(t);
  });
  testWidgets('320英文深色140%和长说明弹窗无溢出', (t) async {
    await open(t, narrow: true);
    final x = l(t);
    await tapVisible(
        t, find.widgetWithText(BeeMenuRow, x.smartBillingImageBilling));
    expect(find.byType(BeeDialog), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text(x.commonKnow));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(Slider));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await close(t);
  });
}

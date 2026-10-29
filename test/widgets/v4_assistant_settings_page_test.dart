import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:beecount/agent/runtime/agent_execution_settings.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/agent_assistant_settings_page.dart';
import 'package:beecount/pages/ai/agent_activity_page.dart';
import 'package:beecount/pages/ai/agent_memory_page.dart';
import 'package:beecount/pages/ai/agent_permissions_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Store implements AgentExecutionSettingsStore {
  int value = 4, writes = 0;
  bool failRead = false, failWrite = false;
  Completer<void>? gate;
  @override
  Future<AgentExecutionSettings> read() async {
    if (failRead) throw StateError('synthetic read');
    return AgentExecutionSettings(maximumModelTurns: value);
  }

  @override
  Future<void> setMaximumModelTurns(int n) async {
    writes++;
    if (gate != null) await gate!.future;
    if (failWrite) throw StateError('synthetic write');
    value = n;
  }
}

class _Observer extends NavigatorObserver {
  Route<dynamic>? last;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    last = route;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> open(WidgetTester t,
      {_Store? store,
      bool narrow = false,
      _Observer? observer,
      int revision = 0}) async {
    t.view.physicalSize = narrow ? const Size(320, 568) : const Size(398, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(ProviderScope(
        overrides: [
          if (store != null)
            agentExecutionSettingsStoreProvider.overrideWithValue(store)
        ],
        child: MaterialApp(
            navigatorObservers: [if (observer != null) observer],
            theme: beeTheme(
                brightness: narrow ? Brightness.dark : Brightness.light),
            locale: Locale(narrow ? 'en' : 'zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (ctx, child) => MediaQuery(
                data: MediaQuery.of(ctx)
                    .copyWith(textScaler: TextScaler.linear(narrow ? 1.4 : 1)),
                child: child!),
            home: AgentAssistantSettingsPage(
                key: ValueKey(revision), ledgerId: 7))));
    await t.pumpAndSettle();
  }

  AppLocalizations l(WidgetTester t) =>
      AppLocalizations.of(t.element(find.byType(AgentAssistantSettingsPage)));
  Future<void> tap(WidgetTester t, Finder f) async {
    if (f.evaluate().isEmpty) {
      await t.scrollUntilVisible(f, 160,
          scrollable: find.byType(Scrollable).first);
    }
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  test('HTML四档顺序及原运行时范围一致，工具边界仍由运行时派生', () {
    final x = jsonDecode(File('tool/design/contracts/assistant-execution.json')
        .readAsStringSync()) as List;
    expect(x.map((v) => v['turns']).toList(), [
      AgentExecutionSettings.minimumTurns,
      AgentExecutionSettings.standardTurns,
      6,
      AgentExecutionSettings.maximumTurns
    ]);
    expect(AgentExecutionSettings(maximumModelTurns: 4).maximumToolCalls, 6);
  });
  testWidgets('四档真实偏好保存与重开，取消不写，历史中间值不强制替换', (t) async {
    SharedPreferences.setMockInitialValues({'agent_execution_depth_v1': 3});
    await open(t);
    var s = l(t);
    final prefs = await SharedPreferences.getInstance();
    expect(find.text(s.agentExecutionDepthSelected(3)), findsOneWidget);
    await tap(t, find.text(s.agentExecutionDepthEntry));
    expect(find.byType(BeeSheet), findsOneWidget);
    await tap(t, find.byType(CloseButton));
    expect(prefs.getInt('agent_execution_depth_v1'), 3);
    var i = 1;
    for (final n in [2, 4, 6, 8]) {
      await tap(t, find.text(s.agentExecutionDepthEntry));
      final label = {
        2: s.agentExecutionDepthQuick,
        4: s.agentExecutionDepthStandard,
        6: s.agentExecutionDepthDeep,
        8: s.agentExecutionDepthCustom
      }[n]!;
      await tap(t, find.text(label));
      expect(prefs.getInt('agent_execution_depth_v1'), n);
      await open(t, revision: i++);
      s = l(t);
      expect(find.text(s.agentExecutionDepthSelected(n)), findsOneWidget);
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('写失败保持原值并显示错误，加载重试不会伪保存选择', (t) async {
    final store = _Store()..failWrite = true;
    await open(t, store: store);
    final s = l(t);
    await tap(t, find.text(s.agentExecutionDepthEntry));
    await tap(t, find.text(s.agentExecutionDepthDeep));
    expect(store.value, 4);
    expect(store.writes, 1);
    expect(find.text(s.agentExecutionDepthSelected(4)), findsOneWidget);
    expect(find.textContaining('synthetic write'), findsOneWidget);
    store.failWrite = false;
    await tap(t, find.text(s.helpCenterRetry));
    expect(find.textContaining('synthetic write'), findsNothing);
    expect(store.writes, 1);
    expect(t.takeException(), isNull);
  });
  testWidgets('保存尚未完成时禁用重复选择，完成后显示真实写入值', (t) async {
    final store = _Store()..gate = Completer<void>();
    await open(t, store: store);
    final s = l(t);
    await tap(t, find.text(s.agentExecutionDepthEntry));
    await t.tap(find.text(s.agentExecutionDepthDeep));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(store.writes, 1);
    final row = find.byWidgetPredicate(
        (w) => w is BeeMenuRow && w.title == s.agentExecutionDepthEntry);
    expect(t.widget<BeeMenuRow>(row).onTap, isNull);
    await t.pump(const Duration(milliseconds: 100));
    await t.pump();
    expect(find.byType(BeeSheet), findsNothing);
    await t.tap(find.text(s.agentExecutionDepthEntry));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.byType(BeeSheet), findsNothing);
    expect(store.writes, 1);
    store.gate!.complete();
    await t.pumpAndSettle();
    expect(find.text(s.agentExecutionDepthSelected(6)), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('加载失败仍保留三入口，重试回原标准值', (t) async {
    final store = _Store()..failRead = true;
    await open(t, store: store);
    final s = l(t);
    for (final text in [
      s.agentAssistantPermissionsEntry,
      s.agentAssistantMemoryEntry,
      s.agentAssistantActivityEntry
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.textContaining('synthetic read'), findsOneWidget);
    store.failRead = false;
    await tap(t, find.text(s.helpCenterRetry));
    expect(find.text(s.agentExecutionDepthSelected(4)), findsOneWidget);
    expect(store.writes, 0);
  });
  testWidgets('三个实际导航回调保留原目标类型和调用方账本身份', (t) async {
    final store = _Store();
    for (final kind in ['permissions', 'memory', 'activity']) {
      final observer = _Observer();
      await open(t, store: store, observer: observer, revision: kind.hashCode);
      final s = l(t);
      await t.tap(find.text({
        'permissions': s.agentAssistantPermissionsEntry,
        'memory': s.agentAssistantMemoryEntry,
        'activity': s.agentAssistantActivityEntry
      }[kind]!));
      final route = observer.last as MaterialPageRoute;
      final target =
          route.builder(t.element(find.byType(AgentAssistantSettingsPage)));
      if (kind == 'permissions') {
        expect(target, isA<AgentPermissionsPage>());
      } else if (kind == 'memory') {
        expect((target as AgentMemoryPage).ledgerId, 7);
      } else {
        expect((target as AgentActivityPage).ledgerId, 7);
      }
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    }
    expect(t.takeException(), isNull);
  });
  testWidgets('320英文深色140%原四选择项与底部弹层可操作且无溢出', (t) async {
    final store = _Store();
    await open(t, store: store, narrow: true);
    final s = l(t);
    await tap(t, find.text(s.agentExecutionDepthEntry));
    for (final label in [
      s.agentExecutionDepthQuick,
      s.agentExecutionDepthStandard,
      s.agentExecutionDepthDeep,
      s.agentExecutionDepthCustom
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tap(t, find.text(s.agentExecutionDepthCustom));
    expect(store.value, 8);
    expect(t.takeException(), isNull);
  });
}

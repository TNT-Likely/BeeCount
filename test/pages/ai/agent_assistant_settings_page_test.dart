import 'package:beecount/agent/runtime/agent_execution_settings.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/ai/agent_assistant_settings_page.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates the locally stored Agent execution depth',
      (tester) async {
    final settings = _InMemoryExecutionSettingsStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          agentExecutionSettingsStoreProvider.overrideWithValue(settings),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const AgentAssistantSettingsPage(ledgerId: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI助手'), findsOneWidget);
    expect(find.text('本地记忆'), findsOneWidget);
    expect(find.text('最近活动'), findsOneWidget);

    await tester.tap(find.text('执行深度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深入'));
    await tester.pumpAndSettle();

    expect(settings.maximumModelTurns, 6);
    expect(find.text('最多 6 个模型回合'), findsOneWidget);
  });
}

final class _InMemoryExecutionSettingsStore
    implements AgentExecutionSettingsStore {
  int maximumModelTurns = AgentExecutionSettings.standardTurns;

  @override
  Future<AgentExecutionSettings> read() async =>
      AgentExecutionSettings(maximumModelTurns: maximumModelTurns);

  @override
  Future<void> setMaximumModelTurns(int value) async {
    maximumModelTurns =
        AgentExecutionSettings(maximumModelTurns: value).maximumModelTurns;
  }
}

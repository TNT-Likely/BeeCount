import 'dart:async';

import 'package:beecount/agent/permission/agent_authorization_gate.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/ai/agent_tool_authorization_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<AgentToolAuthorizationChoice?> choose(
    WidgetTester tester,
    String button,
  ) async {
    final result = Completer<AgentToolAuthorizationChoice?>();
    await tester.pumpWidget(_dialogHost(result.complete));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(button));
    await tester.pumpAndSettle();
    return result.future;
  }

  testWidgets('三个授权选择返回对应的结果', (tester) async {
    expect(
      await choose(tester, '本次允许'),
      AgentToolAuthorizationChoice.allowOnce,
    );
    expect(
      await choose(tester, '始终允许'),
      AgentToolAuthorizationChoice.alwaysAllow,
    );
    expect(
      await choose(tester, '拒绝'),
      AgentToolAuthorizationChoice.deny,
    );
  });

  testWidgets('原样展示记账工具的 sourceText', (tester) async {
    await tester.pumpWidget(_dialogHost((_) {}));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('早饭花了8元'), findsOneWidget);
  });
}

Widget _dialogHost(void Function(AgentToolAuthorizationChoice?) onResult) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            final result = await showAgentToolAuthorizationDialog(
              context: context,
              request: AgentToolAuthorizationRequest(
                authorizationId: 'test',
                runId: 'run',
                ledgerId: 1,
                toolName: 'record_transaction_from_text',
                arguments: const {'sourceText': '早饭花了8元'},
              ),
            );
            onResult(result);
          },
          child: const Text('打开'),
        ),
      ),
    ),
  );
}

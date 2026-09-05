import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/models/ai_quick_command.dart';
import 'package:beecount/widgets/ai/ai_quick_commands_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('空会话建议只展示四条高频任务', (tester) async {
    AIQuickCommand? selected;
    await tester.pumpWidget(
      host(
        AIQuickCommandSuggestions(
          onCommandTap: (command) => selected = command,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('ai-quick-command-suggestion-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ai-quick-command-suggestion-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ai-quick-command-suggestion-4')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('ai-quick-command-suggestion-0')),
    );
    expect(selected, isNotNull);
  });

  testWidgets('输入框快捷入口按需打开完整指令抽屉', (tester) async {
    await tester.pumpWidget(
      host(
        AIQuickCommandLauncher(
          onCommandTap: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('ai-quick-command-launcher')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('ai-quick-command-sheet')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('ai-quick-command-sheet-item-5')),
      findsOneWidget,
    );
  });
}

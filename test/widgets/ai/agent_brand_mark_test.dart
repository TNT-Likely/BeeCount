import 'package:beecount/widgets/ai/agent_brand_mark.dart';
import 'package:beecount/widgets/biz/bee_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({Brightness brightness = Brightness.light}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(
          body: Center(
            child: AgentBrandMark(
              size: 36,
              semanticLabel: 'AI 助手',
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('品牌组件提供 AI 助手语义标签和可见图标', (tester) async {
    await tester.pumpWidget(host());

    expect(find.bySemanticsLabel('AI 助手'), findsOneWidget);
    expect(find.byType(BeeIcon), findsOneWidget);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('暗色主题和无背景模式仍保持固定尺寸', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: AgentBrandMark(
                size: 32,
                showBackground: false,
              ),
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(
      find.byKey(const ValueKey('agent-brand-mark-frame')),
    );
    expect(size, const Size(32, 32));
  });
}

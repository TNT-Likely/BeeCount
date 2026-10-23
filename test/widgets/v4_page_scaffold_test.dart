import 'package:beecount/presentation/v4/bindings/page_scaffold.dart';
import 'package:beecount/providers/theme_providers.dart';
import 'package:beecount/widgets/ui/skin_animation_scope.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('无皮肤与两款动态皮肤共用原偏好，切换不重置列表位置或吞掉操作', (tester) async {
    final container = ProviderContainer(overrides: [
      headerSkinProvider.overrideWith((ref) => 'none'),
      skinAnimationEnabledProvider.overrideWith((ref) => false)
    ]);
    final scroll = ScrollController();
    addTearDown(container.dispose);
    addTearDown(scroll.dispose);
    var taps = 0;
    tester.view.physicalSize = const Size(398, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: beeTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: false),
                child: child!),
            home: V4PageScaffold(
                bottomNavigationBar: TextButton(
                    onPressed: () => taps++, child: const Text('操作')),
                body: ListView.builder(
                    controller: scroll,
                    itemCount: 50,
                    itemBuilder: (context, i) => SizedBox(
                        height: 60,
                        child: Text(
                            '项目 $i，${MediaQuery.disableAnimationsOf(context)}')))))));
    await tester.pumpAndSettle();
    expect(find.byType(SkinAnimationScope), findsNothing);
    scroll.jumpTo(180);
    await tester.pump();
    for (final skin in ['anniversary', 'anniv_cake', 'none']) {
      container.read(headerSkinProvider.notifier).state = skin;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(scroll.offset, 180);
      expect(find.text('项目 3，false'), findsOneWidget);
      if (skin != 'none') {
        expect(find.byType(SkinAnimationScope), findsOneWidget);
        final scopedQuery = find.descendant(
            of: find.byType(SkinAnimationScope),
            matching: find.byType(MediaQuery));
        expect(
            tester.widget<MediaQuery>(scopedQuery.first).data.disableAnimations,
            isTrue);
        final background = find
            .descendant(
                of: find.byType(V4PageScaffold),
                matching: find.byType(IgnorePointer))
            .first;
        expect(tester.getSize(background), const Size(398, 844));
      }
      await tester.tap(find.text('操作'));
      await tester.pump();
    }
    expect(taps, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

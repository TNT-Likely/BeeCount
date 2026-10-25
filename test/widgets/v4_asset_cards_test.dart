import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('下划线选择显式点击且禁用项不触发，小屏大字换行没有横滑', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = 'all';
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: StatefulBuilder(
                    builder: (context, update) => SizedBox(
                        width: 185,
                        child: BeeUnderlineTabs(
                            items: const [
                              BeeSegment('all', 'All accounts'),
                              BeeSegment('assets', 'Assets'),
                              BeeSegment('disabled', 'Disabled', enabled: false)
                            ],
                            value: selected,
                            onChanged: (v) => update(() => selected = v))))))));
    await tester.tap(find.text('Assets'));
    await tester.pumpAndSettle();
    expect(selected, 'assets');
    await tester.tap(find.text('Disabled'));
    expect(selected, 'assets');
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('新版账户行的隐私覆盖原币折算和可用额度，恢复按钮不会打开详情', (tester) async {
    var details = 0, edits = 0, restores = 0;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(brightness: Brightness.dark),
        home: Scaffold(
            body: BeeSurface(
                child: BeeCompactAccountRow(
                    name: 'Hidden foreign credit',
                    subtitle: '•• 7718',
                    amount: r'$-120.00',
                    converted: '≈ ¥-852.00',
                    hidden: true,
                    icon: const BeeLineIcon('CreditCard'),
                    onTap: () => details++,
                    onEdit: () => edits++,
                    onRestore: () => restores++,
                    restoreLabel: 'Restore',
                    includedLabel: 'Included in net worth',
                    creditLeft: r'Available $19,880.00',
                    creditRight: 'Bills 12 · Due 30',
                    progress: .006)))));
    for (final value in ['120.00', '852.00', '19,880.00']) {
      expect(find.textContaining(value, findRichText: true), findsNothing);
    }
    await tester.tap(find.text('Restore'));
    expect([details, edits, restores], [0, 0, 1]);
    await tester.tap(find.text('Hidden foreign credit'));
    expect(details, 1);
    await tester.longPress(find.text('Hidden foreign credit'));
    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单色资产构成使用传入正值，点选可看原金额但隐私态不泄露', (tester) async {
    var hidden = false;
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: Scaffold(
            body: StatefulBuilder(
                builder: (context, update) => Column(children: [
                      BeeAssetComposition(items: const [
                        BeeAssetAllocation(
                            label: 'Bank', value: 30, amount: '¥30.00'),
                        BeeAssetAllocation(
                            label: 'Cash', value: 70, amount: '¥70.00'),
                        BeeAssetAllocation(
                            label: 'Negative cash',
                            value: -20,
                            amount: '¥-20.00')
                      ], hidden: hidden),
                      TextButton(
                          onPressed: () => update(() => hidden = true),
                          child: const Text('Hide'))
                    ])))));
    expect(find.textContaining('Negative cash'), findsNothing);
    await tester.tap(find.text('Cash  70.0%'));
    await tester.pumpAndSettle();
    expect(find.text('Cash · ¥70.00'), findsOneWidget);
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¥70.00'), findsNothing);
    expect(find.text('Cash · ••••'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

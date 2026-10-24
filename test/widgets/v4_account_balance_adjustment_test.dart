import 'package:beecount/presentation/v4/gallery/business_page.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('业务验收第40组实际展示余额调整而非重复账户类型', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: beeTheme(),
        home: const Scaffold(body: BusinessAcceptancePage(isolatedCase: 39))));
    await tester.pumpAndSettle();
    expect(find.byType(BeeAccountBalanceAdjustment), findsOneWidget);
    expect(find.byType(BeeAccountTypePicker), findsNothing);
    await tester.ensureVisible(find.text('新增平账记录'));
    await tester.tap(find.text('新增平账记录'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<BeeAccountBalanceAdjustment>(
                find.byType(BeeAccountBalanceAdjustment))
            .createTransaction,
        true);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final expected in <bool?>[null, false, true]) {
    testWidgets('余额调整明确区分取消、只改余额和新增平账记录：$expected', (tester) async {
      bool? result;
      var returned = false;
      var create = false;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!),
          home: Builder(builder: (context) {
            return Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showBeeSheet<bool>(context, title: '调整余额',
                          child: StatefulBuilder(builder: (sheet, setChoice) {
                        return SingleChildScrollView(
                            child: BeeAccountBalanceAdjustment(
                                currentLabel: '当前余额',
                                currentAmount: 'US\$120,000,000.55',
                                targetLabel: '调整后余额',
                                targetAmount: 'US\$120,000,010.55',
                                differenceLabel: '调整差额',
                                differenceAmount: '+US\$10.00',
                                differenceColor: Colors.green,
                                options: const [
                                  BeeBalanceAdjustmentOption(
                                      createTransaction: false,
                                      title: '只修改余额',
                                      description: '调整账户的期初余额，不新增收支记录。',
                                      confirmLabel: '确认修改余额'),
                                  BeeBalanceAdjustmentOption(
                                      createTransaction: true,
                                      title: '新增平账记录',
                                      description: '在当前账本生成一笔平账收支记录，账户余额随记录变化。',
                                      confirmLabel: '确认生成平账记录'),
                                ],
                                createTransaction: create,
                                onModeChanged: (v) =>
                                    setChoice(() => create = v),
                                onConfirm: (v) => Navigator.pop(sheet, v)));
                      }));
                      returned = true;
                    },
                    child: const Text('打开调整')));
          })));
      await tester.tap(find.text('打开调整'));
      await tester.pumpAndSettle();
      if (expected == null) {
        await tester.tap(find.byType(CloseButton));
      } else {
        if (expected) {
          await tester.ensureVisible(find.text('新增平账记录'));
          await tester.tap(find.text('新增平账记录'));
          await tester.pumpAndSettle();
        }
        final confirm = find.text(expected ? '确认生成平账记录' : '确认修改余额');
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
      }
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, expected);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

import 'package:beecount/utils/account_type_utils.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locked in [false, true]) {
    testWidgets('账户类型使用全部原始类型，浏览分组不修改草稿，编辑限制 $locked', (tester) async {
      var group = 'daily', value = 'cash';
      final selections = <String>[];
      await tester.pumpWidget(MaterialApp(
          theme: beeTheme(),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
            return BeeAccountTypePicker(
                groups: [
                  for (final id in ['daily', 'valuation'])
                    BeeAccountTypeGroup(
                        id: id,
                        label: id == 'daily' ? '日常账户' : '估值账户',
                        choices: accountTypeOrder
                            .where((type) =>
                                isValuationOnlyType(type) ==
                                (id == 'valuation'))
                            .map((type) => BeeIconChoice(
                                value: type,
                                label: getAccountTypeLabel(context, type),
                                icon: AccountTypeIcon(type: type),
                                enabled: !locked || !isValuationOnlyType(type)))
                            .toList())
                ],
                group: group,
                value: value,
                onGroupChanged: (next) => setState(() => group = next),
                onChanged: (next) => setState(() {
                      value = next;
                      selections.add(next);
                    }));
          }))));
      await tester.pumpAndSettle();
      expect(find.byType(AccountTypeIcon), findsNWidgets(6));
      await tester.tap(find.text('估值账户'));
      await tester.pumpAndSettle();
      expect(value, 'cash');
      expect(selections, isEmpty);
      expect(find.byType(AccountTypeIcon), findsNWidgets(6));
      final context = tester.element(find.byType(BeeAccountTypePicker));
      await tester.tap(find.text(getAccountTypeLabel(context, 'loan')));
      await tester.pumpAndSettle();
      expect(value, locked ? 'cash' : 'loan');
      expect(selections, locked ? isEmpty : ['loan']);
      await tester.tap(find.text('日常账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(getAccountTypeLabel(context, 'wechat')));
      await tester.pumpAndSettle();
      expect(value, 'wechat');
      expect(tester.takeException(), isNull);
    });
  }
}

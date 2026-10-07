import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/widgets/biz/transaction_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final selection in [false, true]) {
    testWidgets(
        'row preserves tap and selection gestures (selection=$selection)',
        (tester) async {
      var taps = 0;
      var selections = 0;
      Offset? longPress;
      await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
            body: TransactionListItem(
          icon: Icons.restaurant,
          title: 'Source transaction',
          amount: 12,
          isExpense: true,
          hide: false,
          isSelectionMode: selection,
          onTap: () => taps++,
          onSelectionChanged: () => selections++,
          onLongPressStart: (details) => longPress = details.globalPosition,
        )),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Source transaction'));
      await tester.pumpAndSettle();
      expect(taps, selection ? 0 : 1);
      expect(selections, selection ? 1 : 0);
      await tester.longPress(find.text('Source transaction'));
      await tester.pumpAndSettle();
      expect(longPress == null, selection);
    });
  }
}

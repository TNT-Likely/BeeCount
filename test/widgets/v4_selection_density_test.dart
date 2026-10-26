import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/account_type_utils.dart';
import 'package:beecount/widgets/biz/account_selector.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [320.0, 398.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('标签视觉与透明触控区域独立 $width $brightness', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        const data = BeeTagData('work', '工作日', Color(0xff819268));
        await tester.pumpWidget(MaterialApp(
            theme: beeTheme(brightness: brightness),
            home: Scaffold(
                body: Wrap(spacing: 6, children: [
              BeeTag(
                  key: const ValueKey('detail-tag'),
                  tag: data,
                  compact: true,
                  onTap: () => taps++),
              BeeTag(
                  key: const ValueKey('choice-tag'),
                  tag: data,
                  choice: true,
                  selected: true,
                  onTap: () => taps++),
              BeeTag(
                  key: const ValueKey('disabled-tag'),
                  tag: data,
                  choice: true,
                  enabled: false,
                  onTap: () => taps++),
            ]))));
        final detail = find.byKey(const ValueKey('detail-tag'));
        final choice = find.byKey(const ValueKey('choice-tag'));
        final disabled = find.byKey(const ValueKey('disabled-tag'));
        Finder visual(Finder item) => find.descendant(
            of: item, matching: find.byKey(const ValueKey('bee-tag-pill')));
        expect(tester.getSize(visual(detail)).height, 21);
        expect(tester.getSize(visual(choice)).height, 26);
        expect(tester.getSize(visual(disabled)).height, 26);
        expect(tester.getSize(detail).height, 44);
        expect(tester.getSize(choice).height, 44);
        // Hit the transparent margin, outside the 21px colored pill.
        await tester.tapAt(tester.getTopLeft(detail) + const Offset(10, 2));
        await tester.tap(disabled);
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('账户选择保留原SVG、类型兜底、币种过滤和历史隐藏账户', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = BeeDatabase.forTesting(NativeDatabase.memory());
    final repo = LocalRepository(db);
    await db.customStatement(
        "INSERT INTO ledgers(id,name,currency) VALUES(1,'QA','CNY')");
    for (final row in [
      [1, '微信样例', 'wechat', 'CNY', 0],
      [2, '未知类型', 'custom-type', 'CNY', 0],
      [3, '美元样例', 'cash', 'USD', 0],
      [4, '历史微信', 'wechat', 'CNY', 1],
    ]) {
      await db.customStatement(
          'INSERT INTO accounts(id,name,type,currency,initial_balance,hidden,ledger_id) VALUES(?,?,?,?,0,?,1)',
          row);
    }
    int? selected;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          repositoryProvider.overrideWithValue(repo),
          currentLedgerIdProvider.overrideWith((ref) => 1),
        ],
        child: MaterialApp(
            theme: beeTheme(),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: SizedBox(
                    height: 500,
                    child: AccountSelector(
                        ledgerId: 1,
                        expandedPicker: true,
                        selectedAccountId: 4,
                        pinnedAccountId: 4,
                        onAccountSelected: (value) => selected = value))))));
    await tester.pumpAndSettle();
    expect(find.text('美元样例'), findsNothing);
    expect(find.text('历史微信'), findsOneWidget);
    expect(find.byType(AccountTypeIcon), findsNWidgets(3));
    final svg = tester
        .widgetList<SvgPicture>(find.descendant(
            of: find.byType(AccountTypeIcon),
            matching: find.byType(SvgPicture)))
        .toList();
    expect(svg.every((widget) => widget.colorFilter == null), isTrue);
    expect(
        svg.map((widget) => (widget.bytesLoader as SvgAssetLoader).assetName),
        contains('assets/icons/other_account.svg'));
    await tester.enterText(find.byType(TextField), '未知');
    await tester.pumpAndSettle();
    await tester.tap(find.text('未知类型'));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await db.close();
  });
}

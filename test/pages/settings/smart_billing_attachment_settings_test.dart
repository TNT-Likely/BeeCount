import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/settings/smart_billing_page.dart';
import 'package:beecount/providers/attachment_settings_providers.dart';
import 'package:beecount/widgets/biz/app_list_tile.dart';

void main() {
  testWidgets('original attachment switch follows auto attachment and persists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SmartBillingPage(),
      ),
    ));
    await tester.pumpAndSettle();

    final title = find.text('附件保存原图');
    await tester.scrollUntilVisible(title, 100);
    expect(tester.getTopLeft(title).dy,
        greaterThan(tester.getTopLeft(find.text('自动添加附件')).dy));
    expect(find.text('新添加的附件不再压缩，保留原始尺寸与画质；会占用更多存储空间和同步流量。'), findsOneWidget);
    final tile = find.ancestor(of: title, matching: find.byType(AppListTile));
    final toggle = find.descendant(of: tile, matching: find.byType(Switch));
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AttachmentKeepOriginalNotifier.preferenceKey), isTrue);
    expect(tester.takeException(), isNull);
  });
}

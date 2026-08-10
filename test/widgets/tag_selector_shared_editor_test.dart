import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/widgets/tag_selector.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/providers/tag_providers.dart';

void main() {
  Ledger ledger({required String role}) => Ledger(
        id: 1,
        name: 'Shared',
        currency: 'CNY',
        type: 'personal',
        createdAt: DateTime(2026, 1, 1),
        syncId: 'shared-ledger-1',
        myRole: role,
        memberCount: 2,
        isShared: true,
        monthStartDay: 1,
      );

  Widget host({required String role}) {
    return ProviderScope(
      overrides: [
        currentLedgerProvider.overrideWith(
          (ref) => Stream<Ledger?>.value(ledger(role: role)),
        ),
        tagsForCurrentLedgerProvider.overrideWith(
          (ref) async => const <Tag>[],
        ),
        recentTagsForCurrentLedgerProvider.overrideWith(
          (ref) async => const <Tag>[],
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: TagSelector()),
      ),
    );
  }

  testWidgets('共享账本 Editor 不显示新建标签入口，并提示由 Owner 管理', (tester) async {
    await tester.pumpWidget(host(role: 'editor'));
    await tester.pumpAndSettle();

    expect(find.text('新建标签'), findsNothing);
    expect(find.text('共享账本标签由所有者管理'), findsOneWidget);
  });

  testWidgets('共享账本 Owner 仍可从标签选择器新建标签', (tester) async {
    await tester.pumpWidget(host(role: 'owner'));
    await tester.pumpAndSettle();

    expect(find.text('新建标签'), findsOneWidget);
    expect(find.text('共享账本标签由所有者管理'), findsNothing);
  });
}

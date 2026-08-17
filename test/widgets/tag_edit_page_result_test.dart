import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_edit_page.dart';
import 'package:beecount/providers/database_providers.dart';

void main() {
  late BeeDatabase db;
  late LocalRepository repo;
  Tag? routeResult;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    routeResult = null;
  });

  tearDown(() async => db.close());

  Widget host() {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => 0),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                routeResult = await Navigator.of(context).push<Tag>(
                  MaterialPageRoute(builder: (_) => const TagEditPage()),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('创建标签后将已保存的 Tag 返回给调用方', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '新标签');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(routeResult, isNotNull);
    expect(routeResult!.name, '新标签');
    expect(routeResult!.id, greaterThan(0));
    expect((await db.select(db.tags).get()).single.id, routeResult!.id);

    // showToastOnOverlay 会保留一个 2 秒移除计时器；推进测试时钟，避免泄漏。
    await tester.pump(const Duration(seconds: 3));
  });
}

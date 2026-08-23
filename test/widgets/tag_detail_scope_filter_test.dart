// #461 标签详情页按 月/年/全部 时间维度筛选:
// 默认「全部」保持旧行为;切「月」只看当前周期;切「年」只看当前年周期。
// 统计卡片与交易列表共用同一范围。
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/tag/tag_detail_page.dart';
import 'package:beecount/providers/database_providers.dart';
import 'package:beecount/widgets/biz/biz.dart' show TransactionListItem;

void main() {
  late BeeDatabase db;
  late LocalRepository repo;

  setUp(() {
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
  });

  tearDown(() async => db.close());

  Widget host(int ledgerId, int tagId) {
    return ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        currentLedgerIdProvider.overrideWith((ref) => ledgerId),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: TagDetailPage(tagId: tagId, tagName: '旅行'),
      ),
    );
  }

  testWidgets('默认全部;切月/年后统计与列表只显示对应周期', (tester) async {
    final ledgerId = await db.into(db.ledgers).insert(LedgersCompanion.insert(
          name: '测试账本',
        ));
    final tagId = await repo.createTag(name: '旅行');

    Future<void> seed(DateTime happenedAt, double amount) async {
      final txId = await repo.addTransaction(
        ledgerId: ledgerId,
        type: 'expense',
        amount: amount,
        happenedAt: happenedAt,
      );
      await repo.addTagToTransaction(transactionId: txId, tagId: tagId);
    }

    final now = DateTime.now();
    // 本月一笔(月/年/全部都可见)
    await seed(DateTime(now.year, now.month, 15), 100);
    // 今年另一个月一笔(年/全部可见;now 在 1 月时取 2 月,年范围含未来周期)
    final otherMonth = now.month == 1 ? 2 : 1;
    await seed(DateTime(now.year, otherMonth, 15), 20);
    // 久远一笔(仅全部可见)
    await seed(DateTime(2006, 1, 15), 7);

    await tester.pumpWidget(host(ledgerId, tagId));
    await tester.pumpAndSettle();

    // 默认「全部」:3 笔全显示(保持旧行为)
    expect(find.byType(TransactionListItem), findsNWidgets(3));
    expect(find.text('3笔'), findsOneWidget);

    // 切「月」:只剩本月 1 笔
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionListItem), findsNWidgets(1));
    expect(find.text('1笔'), findsOneWidget);
    // 显示当前周期标签,可再点开选择器换周期
    final monthLabel =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    expect(find.text(monthLabel), findsOneWidget);

    // 切「年」:本年 2 笔
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionListItem), findsNWidgets(2));
    expect(find.text('2笔'), findsOneWidget);
    expect(find.text('${now.year}'), findsOneWidget);

    // 切回「全部」:恢复 3 笔
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionListItem), findsNWidgets(3));
    expect(find.text('3笔'), findsOneWidget);

    // 手动拆树:drift QueryStream 取消订阅时会排一个 zero-duration Timer,
    // 留给框架自动拆树会触发 "A Timer is still pending" 断言。
    // pump 必须带时长——不带时不推进 FakeAsync 时钟,timer 不会执行。
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

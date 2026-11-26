import 'package:beecount/ai/core/bill_info.dart';
import 'package:beecount/cloud/sync/change_tracker.dart';
import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/local_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/l10n/app_localizations_zh.dart';
import 'package:beecount/pages/ai/chat/widgets/bill_card_widget.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/providers/ai_chat_providers.dart';
import 'package:beecount/services/ai/ai_chat_service.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l = AppLocalizationsZh();
  late BeeDatabase db;
  late LocalRepository repo;
  late int source, target, id;
  late ProviderContainer container;
  late AIChatService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
    repo = LocalRepository(db);
    source = await repo.createLedger(name: '原账本');
    target = await repo.createLedger(name: '目标账本');
    id = await db.into(db.transactions).insert(TransactionsCompanion.insert(
          ledgerId: source,
          type: 'expense',
          amount: 28,
          syncId: const Value('receipt-fixture-id'),
        ));
    container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(db),
      currentLedgerIdProvider.overrideWith((_) => source),
    ]);
    service = container.read(aiChatServiceProvider);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> move() => repo.moveTransactionsLocally(
      sourceLedgerId: source, targetLedgerId: target, transactionIds: {id});
  Future<List<LocalChange>> changes() =>
      (db.select(db.localChanges)..where((row) => row.action.equals('delete')))
          .get();

  test('移至另一账本后，旧回执按同一交易 ID 撤销会失败，并保留目标账单、标签和附件', () async {
    final label = await repo.createTag(name: '票据');
    await repo.updateTransactionTags(transactionId: id, tagIds: [label]);
    await db.into(db.transactionAttachments).insert(
        TransactionAttachmentsCompanion.insert(
            transactionId: id, fileName: 'receipt.png'));
    await move();
    repo.changeTracker = ChangeTracker(db);
    expect(
        await service.undoTransaction(id, expectedLedgerId: source), isFalse);
    expect((await repo.getTransactionById(id))!.ledgerId, target);
    expect((await repo.getTagsForTransaction(id)).single.id, label);
    expect((await repo.getAttachmentsByTransaction(id)).single.fileName,
        'receipt.png');
    expect(await changes(), isEmpty);
  });

  test('检查同步身份；删除与同步删除记录同事务回滚，正常撤销只登记一次', () async {
    repo.changeTracker = ChangeTracker(db);
    expect(
        await service.undoTransaction(id,
            expectedLedgerId: source, expectedSyncId: 'another-identity'),
        isFalse);
    expect(await changes(), isEmpty);
    await db.customStatement("""
      CREATE TRIGGER receipt_block_delete BEFORE DELETE ON transactions
      BEGIN SELECT RAISE(ABORT, 'fixture delete failure'); END
    """);
    expect(
        await service.undoTransaction(id, expectedLedgerId: source), isFalse);
    expect(await repo.getTransactionById(id), isNotNull);
    expect(await changes(), isEmpty);
    await db.customStatement('DROP TRIGGER receipt_block_delete');
    expect(
        await service.undoTransaction(id,
            expectedLedgerId: source, expectedSyncId: 'receipt-fixture-id'),
        isTrue);
    expect(
        await service.undoTransaction(id, expectedLedgerId: source), isFalse);
    final audit = (await changes()).single;
    expect(audit.ledgerId, source);
    expect(audit.entitySyncId, 'receipt-fixture-id');
  });

  test('已有未传账本的公开撤销入口仍可删除指定交易', () async {
    expect(await service.undoTransaction(id), isTrue);
    expect(await repo.getTransactionById(id), isNull);
  });

  Widget host({required VoidCallback action}) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: beeTheme(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
              body: BillCardWidget(
            compact: true,
            billInfo: BillInfo(ledgerId: source, amount: 28, category: '午餐'),
            transactionId: id,
            expectedLedgerId: source,
            onEdit: action,
            onUndo: action,
            onChangeLedger: action,
          )),
        ),
      );

  testWidgets('等待账单归属时不可操作；已打开的回执详情在移动后原地失效', (tester) async {
    var acted = 0;
    await tester.pumpWidget(host(action: () => acted++));
    final row = find.byType(BeeMenuRow);
    expect(tester.widget<BeeMenuRow>(row).onTap, isNull);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.aiChatReceiptView));
    await tester.pumpAndSettle();
    final sheet = find.byType(BeeSheet);
    final detail =
        find.descendant(of: sheet, matching: find.byType(BeeAssistantBillCard));
    expect(tester.widget<BeeAssistantBillCard>(detail).onUndo, isNotNull);
    await move();
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: sheet, matching: find.text(l.agentReceiptUnavailable)),
        findsOneWidget);
    expect(detail, findsNothing);
    await tester
        .tap(find.descendant(of: sheet, matching: find.byType(CloseButton)));
    await tester.pumpAndSettle();
    expect(find.text(l.aiChatReceiptView), findsNothing);
    expect(find.text(l.agentReceiptUnavailable), findsOneWidget);
    expect(acted, 0);
    expect((await repo.getTransactionById(id))!.ledgerId, target);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('从其它账单入口实际删除后，旧回执保留历史且不再提供操作', (tester) async {
    await tester.pumpWidget(host(action: () => fail('stale callback')));
    await tester.pumpAndSettle();
    await repo.deleteTransaction(id);
    await tester.pumpAndSettle();
    expect(find.text(l.agentReceiptUnavailable), findsOneWidget);
    expect(find.text(l.aiChatReceiptView), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

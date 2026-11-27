import 'package:beecount/data/db.dart';
import 'package:beecount/data/repositories/local/lock_period_repository.dart';
import 'package:beecount/l10n/app_localizations.dart';
import 'package:beecount/pages/main/ledgers_page_new.dart';
import 'package:beecount/pages/settings/lock_period/bindings/lock_period_settings_actions.dart';
import 'package:beecount/pages/settings/lock_period_settings_page.dart';
import 'package:beecount/providers.dart';
import 'package:beecount/utils/date_in_tz.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 测试替身:钉住日期选择结果,并让动作走指定的 ledgerId。
/// 用于验证"相等日期拦截"和"只影响 B 账本",不依赖滚轮交互。
class _PinnedDatePage extends ConsumerStatefulWidget {
  const _PinnedDatePage({required this.ledgerId, required this.picked});

  final int ledgerId;
  final DateTime picked;

  @override
  ConsumerState<_PinnedDatePage> createState() => _PinnedDatePageState();
}

class _PinnedDatePageState extends ConsumerState<_PinnedDatePage>
    with LockPeriodSettingsActions<_PinnedDatePage> {
  @override
  int get lockPeriodLedgerId => widget.ledgerId;

  @override
  Future<DateTime?> pickLockDate({
    required DateTime today,
    required DateTime? minDate,
  }) async =>
      widget.picked;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          ElevatedButton(
            onPressed: addLockPeriod,
            child: Text(AppLocalizations.of(context).lockPeriodAdd),
          ),
          ElevatedButton(
            onPressed: revokeLatestLockPeriod,
            child: const Text('撤销最近一次锁账'),
          ),
        ],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BeeDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = BeeDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpWith(WidgetTester tester, Widget home,
      {int currentLedgerId = 1}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentLedgerIdProvider.overrideWith((ref) => currentLedgerId),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSettingsPage(WidgetTester tester, {int ledgerId = 1}) =>
      pumpWith(tester, LockPeriodSettingsPage(ledgerId: ledgerId));

  /// toast / 日志防抖有 2 秒 Timer,测试结束前冲掉。
  Future<void> flushTimers(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  testWidgets('空态 → 新增锁账 → 成功提示 → 撤销后锁定线回退', (tester) async {
    await pumpSettingsPage(tester);

    expect(find.text('暂无锁账记录'), findsOneWidget);
    expect(find.text('未锁账'), findsOneWidget);

    await tester.tap(find.text('新增锁账'));
    await tester.pumpAndSettle();
    expect(find.text('选择日期'), findsWidgets);
    await tester.tap(find.text('确定').last);
    await tester.pumpAndSettle();

    // 确认文案含 N 条统计(锁账 key 的正式措辞)。
    expect(find.textContaining('条账单将被锁定'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final today = businessDateInShanghai();
    expect(find.text('锁账成功，$today 及以前的账单已锁定。'), findsOneWidget);

    await flushTimers(tester);
    expect(find.text(today), findsWidgets);
    expect(find.text('未锁账'), findsNothing);
    expect(find.textContaining('第 1 次锁账'), findsOneWidget);

    await tester.tap(find.text('撤销最近一次锁账'));
    await tester.pumpAndSettle();
    expect(find.textContaining('当前锁定日将回退至'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('已撤销最近一次锁账，当前锁定日为 已无锁账。'), findsOneWidget);

    await flushTimers(tester);
    expect(find.text('未锁账'), findsOneWidget);
    expect(find.text('暂无锁账记录'), findsOneWidget);
    expect(find.textContaining('第 1 次锁账'), findsNothing);
  });

  testWidgets('空态不展示撤销入口', (tester) async {
    await pumpSettingsPage(tester);
    expect(find.text('暂无锁账记录'), findsOneWidget);
    expect(find.text('撤销最近一次锁账'), findsNothing);
    await flushTimers(tester);
  });

  testWidgets('切到账本 B 后入口操作只影响 B(不回落 currentLedgerIdProvider)',
      (tester) async {
    final today = parseYmd(businessDateInShanghai())!;
    await pumpWith(
      tester,
      _PinnedDatePage(ledgerId: 2, picked: today),
      currentLedgerId: 1,
    );

    await tester.tap(find.text('新增锁账'));
    await tester.pumpAndSettle();
    expect(find.textContaining('条账单将被锁定'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await flushTimers(tester);

    final repo = LockPeriodRepository(db);
    expect(await repo.getEffectiveLockDate(2), businessDateInShanghai(),
        reason: '入口带进来的 B 账本必须被写入');
    expect(await repo.getEffectiveLockDate(1), isNull,
        reason: 'currentLedgerIdProvider 指向 A,不能被回落');
  });

  testWidgets('切到账本 B 后入口新增+撤销只影响 B:写入行 ledger_id 恒为 B、A 的 MAX 不变',
      (tester) async {
    final today = parseYmd(businessDateInShanghai())!;
    final repo = LockPeriodRepository(db);

    // A(ledger 1)预置一条锁账,currentLedgerIdProvider 也指向 A。
    const aLockDate = '2026-01-15';
    await repo.createLocal(
        syncId: 'lp-A', ledgerId: 1, lockDate: aLockDate);

    // 入口带的是 B(ledger 2);所有动作读的 lockPeriodLedgerId 必须是 2。
    await pumpWith(
      tester,
      _PinnedDatePage(ledgerId: 2, picked: today),
      currentLedgerId: 1,
    );

    // —— 新增走 B ——
    await tester.tap(find.text('新增锁账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await flushTimers(tester);

    final bRowsAfterAdd = await repo.listForLedger(2);
    expect(bRowsAfterAdd, hasLength(1));
    expect(bRowsAfterAdd.single.ledgerId, 2,
        reason: '写入行的 ledger_id 必须恒为入口带进来的 B');
    expect(await repo.getEffectiveLockDate(2), businessDateInShanghai());
    expect(await repo.getEffectiveLockDate(1), aLockDate,
        reason: '操作 B 后 A 的 MAX(lock_date) 必须原样不变');

    // —— 撤销也走 B,绝不回落 currentLedgerIdProvider(A) ——
    await tester.tap(find.text('撤销最近一次锁账'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await flushTimers(tester);

    expect(await repo.listForLedger(2), isEmpty,
        reason: '撤销删掉的是 B 的那一行');
    expect(await repo.getEffectiveLockDate(2), isNull);
    expect(await repo.getEffectiveLockDate(1), aLockDate,
        reason: '撤销 B 后 A 的 MAX(lock_date) 仍必须原样不变');
    final aRows = await repo.listForLedger(1);
    expect(aRows, hasLength(1));
    expect(aRows.single.syncId, 'lp-A',
        reason: 'A 的原有锁账行不能被 B 的操作删掉或覆盖');
  });

  testWidgets('lock_date == 当前锁定线被拦截,并提示当前锁定日', (tester) async {
    final today = businessDateInShanghai();
    await LockPeriodRepository(db).createLocal(
      syncId: 'lp-existing',
      ledgerId: 1,
      lockDate: today,
    );

    await pumpWith(
      tester,
      _PinnedDatePage(ledgerId: 1, picked: parseYmd(today)!),
    );
    await tester.tap(find.text('新增锁账'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('新锁账日期必须晚于当前锁定日'), findsOneWidget,
        reason: '相等日期必须拦截并给出提示');
    expect(find.textContaining('条账单将被锁定'), findsNothing,
        reason: '拦截后不能进入确认弹窗');

    final rows = await LockPeriodRepository(db).listForLedger(1);
    expect(rows, hasLength(1), reason: '拦截后不能写入新行');
    await flushTimers(tester);
  });

  testWidgets('无账本时不展示锁账入口', (tester) async {
    // 没有账本行 → 账本管理页没有任何长按菜单 → 不会出现锁账入口文案。
    await pumpWith(tester, const LedgersPageNew());
    expect(find.text('锁账'), findsNothing);
    expect(find.text('新增锁账'), findsNothing);
    await flushTimers(tester);
  });
}

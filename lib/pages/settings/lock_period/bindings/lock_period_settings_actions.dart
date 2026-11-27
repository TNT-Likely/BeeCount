import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/db.dart';
import '../../../../data/repositories/local/local_repository.dart';
import '../../../../data/repositories/local/lock_period_repository.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../providers.dart';
import '../../../../services/billing/post_processor.dart';
import '../../../../services/system/logger_service.dart';
import '../../../../utils/date_in_tz.dart';
import '../../../shared/lock/lock_period_toast.dart';
import '../../../shared/pickers/wheel_date_picker.dart';

/// 锁账仓储(写路径注入 ChangeTracker)。
///
/// ChangeTracker 只在 BeeCount Cloud 后端存在;其它后端(纯本地 / iCloud /
/// WebDAV / S3)没有 tracker,此时写操作只落本地库、不产生待推送的变更 ——
/// 与 [LocalRepository] 其它写路径的语义一致。
///
/// tracker 用 getter 注入而不是直接传引用:`LocalRepository.changeTracker` 是
/// 构造后才赋值的可变字段,直接传会捕获 null。
final lockPeriodRepositoryProvider = Provider<LockPeriodRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = ref.watch(repositoryProvider);
  return LockPeriodRepository(
    db,
    trackerGetter: () => repo is LocalRepository ? repo.changeTracker : null,
  );
});

/// 锁账设置页读模型:有效锁定线 + 锁账记录列表。
class LockPeriodOverview {
  const LockPeriodOverview({
    required this.effectiveLockDate,
    required this.records,
  });

  /// 有效锁定线 = MAX(lock_date);null = 该账本没有锁账记录(完全未锁)。
  final String? effectiveLockDate;

  /// 锁账记录,按 batch_no 倒序(与 [LockPeriodRepository.listForLedger] 一致)。
  final List<LockPeriod> records;

  bool get hasRecords => records.isNotEmpty;
}

/// 锁账设置页数据源。
///
/// 只读:不注入 ChangeTracker、不登记任何变更 —— 读路径绝不能反向回流。
final lockPeriodOverviewProvider =
    FutureProvider.autoDispose.family<LockPeriodOverview, int>((ref, ledgerId) async {
  final repo = ref.watch(lockPeriodRepositoryProvider);
  final effective = await repo.getEffectiveLockDate(ledgerId);
  final records = await repo.listForLedger(ledgerId);
  return LockPeriodOverview(effectiveLockDate: effective, records: records);
});

/// 新锁账日期必须**严格晚于**当前有效锁定线。
///
/// 无锁账记录(effectiveLockDate == null)是唯一例外,首次新增放行。
/// 相等也算收紧失败 —— 否则 MAX(lock_date) 不动,只会多一条不生效的记录。
bool isLockDateStrictlyLater(String lockDate, String? effectiveLockDate) =>
    effectiveLockDate == null || lockDate.compareTo(effectiveLockDate) > 0;

/// S1-01b-1 锁账写路径动作。
///
/// 两条动作:
///   - [addLockPeriod] —— 新增锁账:选日期 → 统计将被锁住的流水数 → 确认弹窗
///     → 写入 → 推送 → 成功提示;
///   - [revokeLatestLockPeriod] —— 撤销最近一次锁账:确认弹窗 → 删掉 batch_no
///     最大那条 → 有效锁定线自然回退 → 成功提示。
mixin LockPeriodSettingsActions<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  static const _uuid = Uuid();

  /// 目标账本 id(ledger scope)。
  ///
  /// 入口从账本长按菜单带进来,页面判定、只读态判定与写入目标必须用
  /// **同一个** id —— 取错账本就会出现"在 A 账本锁、B 账本被拦"。
  int get lockPeriodLedgerId;

  /// 写操作进行中(防重复点击)。
  bool lockPeriodBusy = false;

  /// 日期选择器独立成可覆盖方法:测试可钉住"用户选了某一天",
  /// 从而在没有真实滚轮交互的情况下验证严格晚于拦截。
  Future<DateTime?> pickLockDate({
    required DateTime today,
    required DateTime? minDate,
  }) =>
      showWheelDatePicker(
        context,
        initial: today,
        mode: WheelDatePickerMode.ymd,
        minDate: minDate,
        maxDate: today,
      );

  /// 新增锁账。
  Future<void> addLockPeriod() async {
    if (lockPeriodBusy) return;
    final l = AppLocalizations.of(context);
    final repo = ref.read(lockPeriodRepositoryProvider);
    final ledgerId = lockPeriodLedgerId;

    // 同一个 ledgerId 贯穿:读锁定线 / 选日期后的校验 / COUNT 过滤 /
    // 最终写入全部用 lockPeriodLedgerId,绝不回落到 currentLedgerIdProvider。
    final effective = await repo.getEffectiveLockDate(ledgerId);
    if (!mounted) return;

    // 上界 = 今天(Asia/Shanghai 业务日):不允许锁未来日期。
    final today = parseYmd(businessDateInShanghai());
    if (today == null) return;

    DateTime? minDate;
    final effectiveDate = effective == null ? null : parseYmd(effective);
    if (effectiveDate != null) {
      minDate = DateTime(
          effectiveDate.year, effectiveDate.month, effectiveDate.day + 1);
    }

    final picked = await pickLockDate(today: today, minDate: minDate);
    if (picked == null || !mounted) return;
    final lockDate = formatYmd(picked);

    // 严格晚于:等于当前锁定线也必须拦截,并且提示里带上当前锁定线。
    if (!isLockDateStrictlyLater(lockDate, effective)) {
      showBeeToast(context, l.lockPeriodMustBeLater(effective ?? ''),
          tone: BeeTone.warning);
      return;
    }

    // N = 该账本内 businessDateInShanghai(happenedAt) <= lockDate 的流水数。
    // 一次 COUNT 聚合(不把流水全量加载到内存再数);不排除已锁定记录 ——
    // 语义是"该日期及以前共 N 条",包含此前已被锁住的那些。
    final affected = await repo.countTransactionsOnOrBefore(
      ledgerId,
      lockDate,
    );
    if (!mounted) return;

    final confirmed = await showBeeConfirm(
      context,
      title: l.lockPeriodConfirmTitle,
      message: l.lockPeriodConfirmMessage(affected, lockDate),
      confirmLabel: l.commonConfirm,
      cancelLabel: l.commonCancel,
    );
    if (confirmed != true || !mounted) return;

    setState(() => lockPeriodBusy = true);
    try {
      await repo.createLocal(
        syncId: _uuid.v4(),
        ledgerId: ledgerId,
        lockDate: lockDate,
      );
      _refreshOverview();
      if (mounted) showLockPeriodCreatedToast(context, lockDate);

      // 写完立刻推一次:锁账是"封存"动作,晚推等于没封。失败不阻塞本地
      // 结果(本地已生效),下次同步会补上。
      try {
        await PostProcessor.sync(ref, ledgerId: ledgerId);
      } catch (e) {
        logger.warning('LockPeriod', '锁账后同步失败(本地已生效,下次同步重试): $e');
      }
    } catch (e) {
      if (mounted) showLockPeriodFailedToast(context, e);
    } finally {
      if (mounted) setState(() => lockPeriodBusy = false);
    }
  }

  /// 撤销最近一次锁账。
  ///
  /// 「最近一次」= 该账本 batch_no 最大那条(与列表展示顺序一致)。撤销 =
  /// 删掉这一行,有效锁定线自然回退到剩余行的 MAX(lock_date);一行不剩则
  /// 回到 null(完全解锁)。
  Future<void> revokeLatestLockPeriod() async {
    if (lockPeriodBusy) return;
    final l = AppLocalizations.of(context);
    final repo = ref.read(lockPeriodRepositoryProvider);
    final ledgerId = lockPeriodLedgerId;

    final records = await repo.listForLedger(ledgerId);
    if (!mounted) return;
    if (records.isEmpty) {
      showLockPeriodNothingToRevokeToast(context);
      return;
    }
    final latest = records.first;
    // 撤销后的有效锁定线 = 剩余行里最大的 lock_date。
    final effectiveAfter = records
        .skip(1)
        .map((r) => r.lockDate)
        .fold<String?>(null, (a, b) => a == null || b.compareTo(a) > 0 ? b : a);

    final confirmed = await showBeeConfirm(
      context,
      title: l.lockPeriodRevokeConfirmTitle,
      message: l.lockPeriodRevokeConfirmMessage(
        latest.lockDate,
        effectiveAfter ?? l.lockPeriodNoLockLeft,
      ),
      confirmLabel: l.commonConfirm,
      cancelLabel: l.commonCancel,
      danger: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => lockPeriodBusy = true);
    try {
      await repo.revokeLatest(ledgerId);
      _refreshOverview();
      if (mounted) {
        showLockPeriodRevokedToast(
            context, effectiveAfter ?? l.lockPeriodNoLockLeft);
      }

      try {
        await PostProcessor.sync(ref, ledgerId: ledgerId);
      } catch (e) {
        logger.warning('LockPeriod', '撤销锁账后同步失败(本地已生效,下次同步重试): $e');
      }
    } catch (e) {
      if (mounted) showLockPeriodFailedToast(context, e);
    } finally {
      if (mounted) setState(() => lockPeriodBusy = false);
    }
  }

  void _refreshOverview() =>
      ref.invalidate(lockPeriodOverviewProvider(lockPeriodLedgerId));
}

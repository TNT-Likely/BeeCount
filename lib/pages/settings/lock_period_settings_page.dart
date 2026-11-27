import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/date_in_tz.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import 'lock_period/bindings/lock_period_settings_actions.dart';

/// 锁账设置页(ledger scope)。
///
/// 锁账是**账本内**的权威状态,不是全局设置 —— 所以本页必须显式接收
/// [ledgerId],不读 `currentLedgerIdProvider`。入口从账本长按菜单带进来,
/// 页面判定、只读态判定与写入目标用的是同一个 id,不会出现"在 A 账本锁、
/// B 账本被拦"。
class LockPeriodSettingsPage extends ConsumerStatefulWidget {
  const LockPeriodSettingsPage({super.key, required this.ledgerId});

  /// 目标账本 id。
  final int ledgerId;

  @override
  ConsumerState<LockPeriodSettingsPage> createState() =>
      _LockPeriodSettingsPageState();
}

class _LockPeriodSettingsPageState extends ConsumerState<LockPeriodSettingsPage>
    with LockPeriodSettingsActions<LockPeriodSettingsPage> {
  @override
  int get lockPeriodLedgerId => widget.ledgerId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final overview = ref.watch(lockPeriodOverviewProvider(widget.ledgerId));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(
          title: l.lockPeriodTitle,
          leading: const BackButton(),
          actions: [
            BeeIconButton(
                label: l.lockPeriodAdd,
                icon: const BeeLineIcon('Plus'),
                onPressed: () => addLockPeriod())
          ]),
      Expanded(
          child: overview.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => BeeEmptyState(
                  title: l.commonFailed,
                  message: '$error',
                  icon: const BeeLineIcon('CircleAlert', size: 36),
                  action: BeeButton(
                      label: l.v4RecordingRetry,
                      onPressed: () => ref.invalidate(
                          lockPeriodOverviewProvider(widget.ledgerId)))),
              data: (data) => BeePageBody(eager: true, children: [
                    _LockLineCard(overview: data),
                    if (!data.hasRecords)
                      BeeEmptyState(
                          title: l.lockPeriodEmpty,
                          message: l.lockPeriodEmptyHint,
                          icon: const BeeLineIcon('LockKeyhole', size: 40),
                          action: BeeButton(
                              label: l.lockPeriodAdd,
                              icon: const BeeLineIcon('Plus', size: 18),
                              onPressed: () => addLockPeriod()))
                    else
                      BeeSection(
                          title: l.lockPeriodRecords,
                          action: BeeButton(
                              label: l.lockPeriodRevokeLatest,
                              kind: BeeButtonKind.secondary,
                              compact: true,
                              onPressed: () => revokeLatestLockPeriod()),
                          child: BeeSurface(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 3),
                              child: Column(children: [
                                for (var i = 0; i < data.records.length; i++)
                                  ...[
                                    if (i > 0)
                                      const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: BeeDivider(height: .6)),
                                    _LockPeriodRow(record: data.records[i]),
                                  ]
                              ]))),
                  ]))),
    ]));
  }
}

/// 当前有效锁定线卡片。
///
/// 有效锁定线 = 该账本 MAX(lock_date);null = 没有锁账记录(完全未锁)。
class _LockLineCard extends StatelessWidget {
  const _LockLineCard({required this.overview});
  final LockPeriodOverview overview;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final effective = overview.effectiveLockDate;
    final locked = effective != null;
    return BeeSurface(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: BeeMenuRow(
            title: l.lockPeriodEffectiveLine,
            subtitle: l.lockPeriodEffectiveLineHint,
            leading: const BeeLineIcon('Lock'),
            trailing: Text(
              effective ?? l.lockPeriodNotLocked,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).hintColor),
            )));
  }
}

/// 单条锁账记录(锁账日期 + 第几次 + 锁账时间)。
class _LockPeriodRow extends StatelessWidget {
  const _LockPeriodRow({required this.record});
  final LockPeriod record;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeMenuRow(
        title: record.lockDate,
        subtitle:
            '${l.lockPeriodBatchNo(record.batchNo)} · ${_formatLockedAt(record.lockedAt)}',
        leading: const BeeLineIcon('LockKeyhole'));
  }
}

/// locked_at 是 UTC ISO8601 字符串,展示时换算到设备本地时间。
String _formatLockedAt(String lockedAt) {
  final parsed = parseUtcIso8601(lockedAt);
  if (parsed == null) return lockedAt;
  return DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
}

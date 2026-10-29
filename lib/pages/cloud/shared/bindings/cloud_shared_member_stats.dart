// 共享账本成员收支统计 — 简化版,只列每个成员本期 +收入 / -支出 / N笔。
// 入口在账本动作菜单。Web 端有图表版,mobile 走简版列表足矣。
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../providers/shared_ledger_providers.dart';
import '../../../../providers/sync_providers.dart'
    show beecountCloudProviderInstance;
import '../../../../styles/tokens.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/cloud_shared.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';
import '../../../../utils/format_money.dart';

class CloudSharedStatsControls extends ConsumerStatefulWidget {
  const CloudSharedStatsControls({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  final String ledgerExternalId;
  final String ledgerName;

  @override
  ConsumerState<CloudSharedStatsControls> createState() =>
      _CloudSharedStatsControlsState();
}

class _CloudSharedStatsControlsState
    extends ConsumerState<CloudSharedStatsControls> {
  String _scope = 'month'; // month | year | all

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(memberStatsProvider(
      MemberStatsKey(ledgerId: widget.ledgerExternalId, scope: _scope),
    ));

    return V4PageScaffold(
      body: Column(
        children: [
          BeePageHeader(
            title: l10n.sharedMembersStatsTitle,
            subtitle: widget.ledgerName,
            leading: const BackButton(),
            actions: [
              BeeIconButton(
                label: l10n.v4RecordingRetry,
                icon: const BeeLineIcon('RefreshCw', size: 21),
                onPressed: () => ref.invalidate(memberStatsProvider(
                  MemberStatsKey(
                      ledgerId: widget.ledgerExternalId, scope: _scope),
                )),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: BeeSegmented<String>(
              value: _scope,
              items: [
                BeeSegment('month', l10n.analyticsMonth),
                BeeSegment('year', l10n.analyticsYear),
                BeeSegment('all', l10n.analyticsAll),
              ],
              onChanged: (v) => setState(() => _scope = v),
            ),
          ),
          Expanded(
            child: statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => BeeEmptyState(
                  title: '${l10n.commonError}: $e',
                  action: BeeButton(
                      label: l10n.v4RecordingRetry,
                      onPressed: () => ref.invalidate(memberStatsProvider(
                          MemberStatsKey(
                              ledgerId: widget.ledgerExternalId,
                              scope: _scope))))),
              data: (stats) => _buildBody(context, stats, l10n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BeeCountCloudMemberStats? stats,
    AppLocalizations l10n,
  ) {
    if (stats == null || stats.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.sharedMembersStatsEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: BeeTokens.textTertiary(context)),
          ),
        ),
      );
    }
    final totalIncome =
        stats.items.fold<double>(0, (s, it) => s + it.incomeTotal);
    final totalExpense =
        stats.items.fold<double>(0, (s, it) => s + it.expenseTotal);
    final currency = stats.ledgerCurrency;
    final symbol = _currencySymbol(currency);
    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        BeeCloudSharedStatsSummary(
          incomeLabel: l10n.sharedMembersStatsIncome,
          expenseLabel: l10n.sharedMembersStatsExpense,
          income: '+$symbol${formatMoneyCompact(totalIncome)}',
          expense: '-$symbol${formatMoneyCompact(totalExpense)}',
          incomeColor: BeeTokens.incomeColor(context, ref),
          expenseColor: BeeTokens.expenseColor(context, ref),
        ),
        const SizedBox(height: 8),
        BeeCloudSharedCard(
          child: Column(
            children: [
              for (final s in stats.items) ...[
                _MemberStatTile(
                  stat: s,
                  currency: currency,
                  totalExpense: totalExpense,
                ),
                if (s != stats.items.last) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberStatTile extends ConsumerWidget {
  const _MemberStatTile({
    required this.stat,
    required this.currency,
    required this.totalExpense,
  });

  final BeeCountCloudMemberStatItem stat;
  final String currency;
  final double totalExpense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final displayName = stat.displayName?.isNotEmpty == true
        ? stat.displayName!
        : (stat.email?.split('@').first ??
            stat.userId.substring(0, stat.userId.length.clamp(0, 6)));
    final symbol = _currencySymbol(currency);
    final share = totalExpense > 0
        ? (stat.expenseTotal / totalExpense * 100).clamp(0, 100)
        : 0;
    return BeeCloudSharedStatsRow(
      avatar: _StatsAvatar(stat: stat, displayName: displayName),
      name: displayName,
      count: l10n.sharedMembersStatsTxCount(stat.txCount),
      income: '+$symbol${formatMoneyCompact(stat.incomeTotal)}',
      expense:
          '-$symbol${formatMoneyCompact(stat.expenseTotal)}${totalExpense > 0 ? '  (${share.toStringAsFixed(0)}%)' : ''}',
      incomeColor: BeeTokens.incomeColor(context, ref),
      expenseColor: BeeTokens.expenseColor(context, ref),
    );
  }
}

class _StatsAvatar extends ConsumerWidget {
  const _StatsAvatar({required this.stat, required this.displayName});

  final BeeCountCloudMemberStatItem stat;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letter = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final relativeUrl = stat.avatarUrl;
    if (relativeUrl == null || relativeUrl.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final cloudAsync = ref.watch(beecountCloudProviderInstance);
    final cloud = cloudAsync.valueOrNull;
    final base = cloud?.baseUrl;
    if (base == null || base.isEmpty) {
      return CircleAvatar(child: Text(letter));
    }
    final absoluteUrl =
        relativeUrl.startsWith('http') ? relativeUrl : '$base$relativeUrl';
    return CircleAvatar(
      backgroundImage: NetworkImage(absoluteUrl),
      onBackgroundImageError: (_, __) {},
      child: Text(letter),
    );
  }
}

String _currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'CNY':
    case 'RMB':
      return '¥';
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'HKD':
      return r'HK$';
    case 'TWD':
      return r'NT$';
    default:
      return '$code ';
  }
}

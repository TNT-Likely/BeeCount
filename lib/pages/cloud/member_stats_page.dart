// 共享账本成员收支统计 — 简化版,只列每个成员本期 +收入 / -支出 / N笔。
// 入口在账本动作菜单。Web 端有图表版,mobile 走简版列表足矣。
import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../providers/sync_providers.dart' show beecountCloudProviderInstance;
import '../../styles/tokens.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/capsule_switcher.dart';
import '../../widgets/ui/ui.dart';

class MemberStatsPage extends ConsumerStatefulWidget {
  const MemberStatsPage({
    super.key,
    required this.ledgerExternalId,
    required this.ledgerName,
  });

  final String ledgerExternalId;
  final String ledgerName;

  @override
  ConsumerState<MemberStatsPage> createState() => _MemberStatsPageState();
}

class _MemberStatsPageState extends ConsumerState<MemberStatsPage> {
  String _scope = 'month'; // month | year | all

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statsAsync = ref.watch(memberStatsProvider(
      MemberStatsKey(ledgerId: widget.ledgerExternalId, scope: _scope),
    ));

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.sharedMembersStatsTitle,
            subtitle: widget.ledgerName,
            showBack: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(memberStatsProvider(
                  MemberStatsKey(
                      ledgerId: widget.ledgerExternalId, scope: _scope),
                )),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: CapsuleSwitcher<String>(
              selectedValue: _scope,
              options: [
                CapsuleOption(value: 'month', label: l10n.analyticsMonth),
                CapsuleOption(value: 'year', label: l10n.analyticsYear),
                CapsuleOption(value: 'all', label: l10n.analyticsAll),
              ],
              onChanged: (v) => setState(() => _scope = v),
            ),
          ),
          Expanded(
            child: statsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('${l10n.commonError}: $e',
                      textAlign: TextAlign.center),
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: [
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryCell(
                  label: l10n.sharedMembersStatsIncome,
                  amount: '+$symbol${formatMoneyCompact(totalIncome)}',
                  color: BeeTokens.incomeColor(context, ref),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: BeeTokens.divider(context),
                ),
                _SummaryCell(
                  label: l10n.sharedMembersStatsExpense,
                  amount: '-$symbol${formatMoneyCompact(totalExpense)}',
                  color: BeeTokens.expenseColor(context, ref),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
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

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final String amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: BeeTokens.textSecondary(context),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
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
        : (stat.email?.split('@').first ?? stat.userId.substring(0, 6));
    final symbol = _currencySymbol(currency);
    final share = totalExpense > 0
        ? (stat.expenseTotal / totalExpense * 100).clamp(0, 100)
        : 0;
    return ListTile(
      leading: _StatsAvatar(stat: stat, displayName: displayName),
      title: Text(displayName, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        l10n.sharedMembersStatsTxCount(stat.txCount),
        style: TextStyle(
          color: BeeTokens.textTertiary(context),
          fontSize: 11,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$symbol${formatMoneyCompact(stat.incomeTotal)}',
            style: TextStyle(
              color: BeeTokens.incomeColor(context, ref),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (totalExpense > 0) ...[
                Text(
                  '${share.toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: BeeTokens.textTertiary(context),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '-$symbol${formatMoneyCompact(stat.expenseTotal)}',
                style: TextStyle(
                  color: BeeTokens.expenseColor(context, ref),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
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
    final absoluteUrl = relativeUrl.startsWith('http')
        ? relativeUrl
        : '$base$relativeUrl';
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

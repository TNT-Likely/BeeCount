import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/marketing/product_promos.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/biz/product_promo_card.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../widgets/charts/asset_composition_chart.dart';
import 'account_edit_page.dart';
import 'account_detail_page.dart';

class AccountsPage extends ConsumerStatefulWidget {
  final bool asTab;
  const AccountsPage({super.key, this.asTab = false});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  /// 拖拽后临时保持本地排序，防止 stream rebuild 闪烁
  Map<String, List<db.Account>>? _reorderingGroups;

  Map<String, List<db.Account>> _groupAccounts(List<db.Account> accounts) {
    final Map<String, List<db.Account>> grouped = {};
    for (final account in accounts) {
      grouped.putIfAbsent(account.type, () => []).add(account);
    }
    return grouped;
  }

  void _onReorder(String type, List<db.Account> groupAccounts, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;

    // 乐观更新：用本地状态锁住当前排序，防止 stream 刷新导致闪烁
    setState(() {
      _reorderingGroups ??= _groupAccounts(
        ref.read(allAccountsStreamProvider).asData?.value ?? [],
      );
      final list = _reorderingGroups![type]!;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
    });

    // 构建批量更新
    final list = _reorderingGroups![type]!;
    final updates = <({int id, int sortOrder})>[];
    for (int i = 0; i < list.length; i++) {
      updates.add((id: list[i].id, sortOrder: i));
    }

    // 写入数据库，延迟清除本地状态让 stream 先到位
    ref.read(repositoryProvider).updateAccountSortOrders(updates).then((_) {
      // 账户拖拽排序也推到服务端。账户的 ChangeTracker 变更用的是 account.ledgerId
      // （非 0），走常规 push 路径即可。
      final activeLedgerId = ref.read(currentLedgerIdProvider);
      if (activeLedgerId > 0) {
        unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _reorderingGroups = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final accountsAsync = ref.watch(allAccountsStreamProvider);
    final accountFeatureAsync = ref.watch(accountFeatureEnabledProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final allStatsAsync = ref.watch(allAccountStatsProvider);
    final netWorthByCurrencyAsync = ref.watch(netWorthBreakdownByCurrencyProvider);
    final isDark = BeeTokens.isDark(context);

    // 资产构成数据
    final compositionAsync = ref.watch(assetCompositionProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // ======== 简洁 Header ========
          PrimaryHeader(
            title: l10n.accountsTitle,
            showBack: !widget.asTab,
            compact: true,
            // 顺序(左 → 右):加号 / 蜜蜂家当入口 / 设置。
            // 设置放最右边(Material 设计惯例,溢出 / 设置类放最右),
            // 蜜蜂家当放中间,顺手能点到但不抢主操作位。
            actions: [
              IconButton(
                onPressed: () => _addAccount(context, ref, ledgerId),
                icon: const Icon(Icons.add),
                tooltip: l10n.accountAddTooltip,
              ),
              // 蜜蜂家当 BeeAssets 入口 — 行为走 ProductPromoLauncher
              // (iOS 跳商店 / Android 弹窗)。
              _BeeAssetsHeaderEntry(),
              IconButton(
                onPressed: () => _showSettingsSheet(context, ref, accountFeatureAsync, accountsAsync),
                icon: const Icon(Icons.settings_outlined),
                tooltip: l10n.commonSettings,
              ),
            ],
          ),

          // ======== 主内容 ========
          Expanded(
            child: accountsAsync.when(
              skipLoadingOnReload: true,
              data: (accounts) {
                final groups = _reorderingGroups ?? _groupAccounts(accounts);

                return ListView(
                  padding: EdgeInsets.only(
                    left: 12.0.scaled(context, ref),
                    right: 12.0.scaled(context, ref),
                    top: 8.0.scaled(context, ref),
                    bottom: widget.asTab
                        ? 8.0.scaled(context, ref) + 56 + MediaQuery.of(context).padding.bottom + 24
                        : 8.0.scaled(context, ref),
                  ),
                  children: [
                    if (accounts.isEmpty)
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 64.0.scaled(context, ref),
                                color: primaryColor.withValues(alpha: 0.4),
                              ),
                              SizedBox(height: 16.0.scaled(context, ref)),
                              Text(
                                l10n.accountsEmptyMessage,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: BeeTokens.textSecondary(context),
                                ),
                              ),
                              SizedBox(height: 24.0.scaled(context, ref)),
                              ElevatedButton.icon(
                                onPressed: () => _addAccount(context, ref, ledgerId),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(l10n.accountAddButton),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // 0. 净资产汇总 + 资产构成（合并卡片）
                      _buildNetWorthAndCompositionCard(
                        context, ref, netWorthByCurrencyAsync, compositionAsync, primaryColor,
                      ),

                      // 2. 资产账户分组
                      ..._buildClassificationSection(
                        context: context,
                        l10n: l10n,
                        title: l10n.assetAccounts,
                        icon: Icons.trending_up,
                        iconColor: BeeTokens.incomeColor(context, ref),
                        typeOrder: assetTypeOrder,
                        groups: groups,
                        allStats: allStatsAsync.asData?.value,
                        primaryColor: primaryColor,
                        ledgerId: ledgerId,
                      ),

                      // 3. 负债账户分组
                      ..._buildClassificationSection(
                        context: context,
                        l10n: l10n,
                        title: l10n.liabilityAccounts,
                        icon: Icons.trending_down,
                        iconColor: BeeTokens.expenseColor(context, ref),
                        typeOrder: liabilityTypeOrder,
                        groups: groups,
                        allStats: allStatsAsync.asData?.value,
                        primaryColor: primaryColor,
                        ledgerId: ledgerId,
                      ),

                      // 4. 其他未知类型
                      ...groups.keys
                          .where((type) => !accountTypeOrder.contains(type) && groups[type]!.isNotEmpty)
                          .map((type) {
                        final groupList = groups[type]!;
                        return _AccountTypeGroup(
                          type: type,
                          accounts: groupList,
                          primaryColor: primaryColor,
                          allStats: allStatsAsync.asData?.value,
                          onReorder: (oldIndex, newIndex) =>
                              _onReorder(type, groupList, oldIndex, newIndex),
                          onTap: (account) =>
                              _viewAccountDetail(context, ref, account),
                          onEdit: (account) =>
                              _editAccount(context, ref, account, ledgerId),
                        );
                      }),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('${l10n.commonError}: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 净资产汇总 + 资产构成合并卡片
  Widget _buildNetWorthAndCompositionCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, ({double totalAssets, double totalLiabilities, double netWorth})>> netWorthAsync,
    AsyncValue<List<({String type, double totalBalance})>> compositionAsync,
    Color primaryColor,
  ) {
    final isSingleCurrency = netWorthAsync.asData?.value != null
        ? netWorthAsync.asData!.value.length <= 1
        : true;

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 净资产部分
          netWorthAsync.when(
            skipLoadingOnReload: true,
            data: (nwByCurrency) => _buildNetWorthContent(context, ref, nwByCurrency),
            loading: () => SizedBox(
              height: 80.0.scaled(context, ref),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // 饼图仅在单货币时显示
          if (isSingleCurrency) ...[
            // 分割线
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
              child: Divider(height: 1, color: BeeTokens.divider(context)),
            ),
            // 资产构成饼图部分
            compositionAsync.when(
              skipLoadingOnReload: true,
              data: (data) => Padding(
                padding: EdgeInsets.all(12.0.scaled(context, ref)),
                child: AssetCompositionChart(data: data, embedded: true),
              ),
              loading: () => SizedBox(
                height: 180.0.scaled(context, ref),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }

  /// 净资产内容（不含外层 SectionCard）
  Widget _buildNetWorthContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, ({double totalAssets, double totalLiabilities, double netWorth})> nwByCurrency,
  ) {
    final l10n = AppLocalizations.of(context);
    final useCompact = ref.watch(compactAmountProvider);

    final isSingleCurrency = nwByCurrency.length <= 1;
    final singleNw = nwByCurrency.isEmpty
        ? (totalAssets: 0.0, totalLiabilities: 0.0, netWorth: 0.0)
        : nwByCurrency.values.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 净资产标签
        Text(
          l10n.accountTotalBalance,
          style: TextStyle(
            fontSize: 12,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        SizedBox(height: 4.0.scaled(context, ref)),
        if (isSingleCurrency) ...[
          AmountText(
            value: singleNw.netWorth,
            signed: false,
            showCurrency: false,
            useCompactFormat: useCompact,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: singleNw.netWorth >= 0
                  ? BeeTokens.incomeColor(context, ref)
                  : BeeTokens.expenseColor(context, ref),
            ),
          ),
        ] else ...[
          ...nwByCurrency.entries.toList().asMap().entries.map((mapEntry) {
            final isFirst = mapEntry.key == 0;
            final currency = mapEntry.value.key;
            final nw = mapEntry.value.value;
            return Padding(
              padding: EdgeInsets.only(top: isFirst ? 0 : 2.0.scaled(context, ref)),
              child: AmountText(
                value: nw.netWorth,
                signed: false,
                showCurrency: true,
                currencyCode: currency,
                useCompactFormat: useCompact,
                style: TextStyle(
                  fontSize: isFirst ? 26 : 20,
                  fontWeight: FontWeight.bold,
                  color: nw.netWorth >= 0
                      ? BeeTokens.incomeColor(context, ref)
                      : BeeTokens.expenseColor(context, ref),
                ),
              ),
            );
          }),
        ],
        SizedBox(height: 12.0.scaled(context, ref)),
        // 总资产 | 总负债
        if (isSingleCurrency)
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: l10n.totalAssets,
                  value: singleNw.totalAssets,
                  valueColor: BeeTokens.incomeColor(context, ref),
                ),
              ),
              Container(
                width: 1,
                height: 28.0.scaled(context, ref),
                color: BeeTokens.divider(context),
              ),
              Expanded(
                child: _StatCell(
                  label: l10n.totalLiabilities,
                  value: singleNw.totalLiabilities.abs(),
                  valueColor: BeeTokens.expenseColor(context, ref),
                ),
              ),
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.totalAssets,
                        style: TextStyle(
                          fontSize: 11,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                      SizedBox(height: 2.0.scaled(context, ref)),
                      _buildMultiCurrencyAmountRow(
                        context, ref,
                        entries: nwByCurrency.entries
                            .where((e) => e.value.totalAssets != 0)
                            .map((e) => (currency: e.key, value: e.value.totalAssets))
                            .toList(),
                        valueColor: BeeTokens.incomeColor(context, ref),
                        useCompact: useCompact,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  color: BeeTokens.divider(context),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.totalLiabilities,
                        style: TextStyle(
                          fontSize: 11,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                      SizedBox(height: 2.0.scaled(context, ref)),
                      _buildMultiCurrencyAmountRow(
                        context, ref,
                        entries: nwByCurrency.entries
                            .where((e) => e.value.totalLiabilities != 0)
                            .map((e) => (currency: e.key, value: e.value.totalLiabilities.abs()))
                            .toList(),
                        valueColor: BeeTokens.expenseColor(context, ref),
                        useCompact: useCompact,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // 总资产/总负债数字跟下面的 Divider 之间留出呼吸空间,不然视觉上紧贴着
        // 横线很挤。
        SizedBox(height: 20.0.scaled(context, ref)),
      ],
    );
  }

  /// 多货币金额横排（用 · 分隔）
  Widget _buildMultiCurrencyAmountRow(
    BuildContext context,
    WidgetRef ref, {
    required List<({String currency, double value})> entries,
    required Color valueColor,
    required bool useCompact,
  }) {
    if (entries.isEmpty) {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: BeeTokens.textTertiary(context),
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.0.scaled(context, ref)),
                child: Text(
                  '·',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            AmountText(
              value: entries[i].value,
              signed: false,
              showCurrency: true,
              currencyCode: entries[i].currency,
              useCompactFormat: useCompact,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建资产/负债分类区域
  List<Widget> _buildClassificationSection({
    required BuildContext context,
    required AppLocalizations l10n,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<String> typeOrder,
    required Map<String, List<db.Account>> groups,
    required Map<int, ({double balance, double expense, double income})>? allStats,
    required Color primaryColor,
    required int ledgerId,
  }) {
    // 检查此分类下是否有账户
    final hasAccounts = typeOrder.any((type) =>
        groups.containsKey(type) && groups[type]!.isNotEmpty);
    if (!hasAccounts) return [];

    // 按币种分组计算小计
    final Map<String, double> subtotalByCurrency = {};
    for (final type in typeOrder) {
      if (groups.containsKey(type)) {
        for (final account in groups[type]!) {
          final balance = allStats?[account.id]?.balance ?? 0;
          subtotalByCurrency.update(
            account.currency,
            (v) => v + balance,
            ifAbsent: () => balance,
          );
        }
      }
    }
    final useCompact = ref.watch(compactAmountProvider);
    final isSingleCurrency = subtotalByCurrency.length <= 1;

    return [
      // 分类标题
      Padding(
        padding: EdgeInsets.only(
          top: 16.0.scaled(context, ref),
          bottom: 4.0.scaled(context, ref),
          left: 4.0.scaled(context, ref),
          right: 4.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.0.scaled(context, ref), color: iconColor),
            SizedBox(width: 6.0.scaled(context, ref)),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BeeTokens.textPrimary(context),
              ),
            ),
            const Spacer(),
            if (isSingleCurrency)
              AmountText(
                value: subtotalByCurrency.values.firstOrNull ?? 0,
                signed: false,
                showCurrency: false,
                useCompactFormat: useCompact,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              )
            else
              Flexible(
                child: _buildMultiCurrencyAmountRow(
                  context, ref,
                  entries: subtotalByCurrency.entries
                      .map((e) => (currency: e.key, value: e.value))
                      .toList(),
                  valueColor: iconColor,
                  useCompact: useCompact,
                ),
              ),
          ],
        ),
      ),
      // 类型分组
      ...typeOrder
          .where((type) => groups.containsKey(type) && groups[type]!.isNotEmpty)
          .map((type) {
        final groupList = groups[type]!;
        return _AccountTypeGroup(
          type: type,
          accounts: groupList,
          primaryColor: primaryColor,
          allStats: allStats,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(type, groupList, oldIndex, newIndex),
          onTap: (account) =>
              _viewAccountDetail(context, ref, account),
          onEdit: (account) =>
              _editAccount(context, ref, account, ledgerId),
        );
      }),
    ];
  }

  /// 设置底部弹窗
  void _showSettingsSheet(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<bool> accountFeatureAsync,
    AsyncValue<List<db.Account>> accountsAsync,
  ) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);
    final accounts = accountsAsync.asData?.value ?? [];

    showModalBottomSheet(
      context: context,
      backgroundColor: BeeTokens.surfaceSheet(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final featureAsync = ref.watch(accountFeatureEnabledProvider);
            final enabled = featureAsync.asData?.value ?? false;

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 拖拽条
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BeeTokens.textTertiary(context).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      l10n.commonSettings,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
                  ),
                  // 功能开关
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SwitchListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      title: Text(
                        l10n.accountsEnableFeature,
                        style: TextStyle(
                          fontSize: 14,
                          color: BeeTokens.textPrimary(context),
                        ),
                      ),
                      value: enabled,
                      activeColor: primaryColor,
                      onChanged: (value) async {
                        await ref
                            .read(accountFeatureSetterProvider)
                            .setEnabled(value);
                        ref.invalidate(accountFeatureEnabledProvider);
                      },
                    ),
                  ),
                  if (enabled && accounts.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: BeeTokens.divider(context),
                    ),
                    _CompactDefaultAccount(
                      accounts: accounts,
                      primaryColor: primaryColor,
                      type: 'expense',
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: BeeTokens.divider(context),
                    ),
                    _CompactDefaultAccount(
                      accounts: accounts,
                      primaryColor: primaryColor,
                      type: 'income',
                    ),
                  ],
                  SizedBox(height: 16.0.scaled(context, ref)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref, int ledgerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountEditPage(ledgerId: ledgerId),
      ),
    );

    // 只 bump tick:4 个 stats provider 都 ref.watch(statsRefreshProvider),
    // 自动重算且保留旧值,`when` 不会闪 loading。
    // `ref.invalidate` 会清掉 cached value 让 `.when` 走 loading 分支,资产
    // 页 spinner 闪烁 / 整页 reload 体感的根因。
    ref.read(statsRefreshProvider.notifier).state++;
  }

  Future<void> _editAccount(BuildContext context, WidgetRef ref,
      db.Account account, int ledgerId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountEditPage(
          account: account,
          ledgerId: ledgerId,
        ),
      ),
    );

    ref.read(statsRefreshProvider.notifier).state++;
  }

  void _viewAccountDetail(
      BuildContext context, WidgetRef ref, db.Account account) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AccountDetailPage(account: account),
      ),
    );
  }
}

/// Header 内统计项（白色文字）
class _StatCell extends ConsumerWidget {
  final String label;
  final double value;
  final Color? valueColor;

  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        SizedBox(height: 2.0.scaled(context, ref)),
        AmountText(
          value: value,
          signed: false,
          showCurrency: false,
          useCompactFormat: ref.watch(compactAmountProvider),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: valueColor ?? BeeTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

/// 账户类型分组（可折叠，默认展开）
class _AccountTypeGroup extends ConsumerStatefulWidget {
  final String type;
  final List<db.Account> accounts;
  final Color primaryColor;
  final Map<int, ({double balance, double expense, double income})>? allStats;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(db.Account account) onTap;
  final void Function(db.Account account) onEdit;

  const _AccountTypeGroup({
    required this.type,
    required this.accounts,
    required this.primaryColor,
    this.allStats,
    required this.onReorder,
    required this.onTap,
    required this.onEdit,
  });

  @override
  ConsumerState<_AccountTypeGroup> createState() => _AccountTypeGroupState();
}

class _AccountTypeGroupState extends ConsumerState<_AccountTypeGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final typeColor = getColorForAccountType(widget.type, widget.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 类型标题栏（点击展开/折叠）
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(
              top: 12.0.scaled(context, ref),
              bottom: 6.0.scaled(context, ref),
              left: 4.0.scaled(context, ref),
              right: 4.0.scaled(context, ref),
            ),
            child: Row(
              children: [
                Container(
                  width: 28.0.scaled(context, ref),
                  height: 28.0.scaled(context, ref),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7.0.scaled(context, ref)),
                  ),
                  child: Center(
                    child: AccountTypeIcon(
                      type: widget.type,
                      size: 16.0.scaled(context, ref),
                      color: typeColor,
                    ),
                  ),
                ),
                SizedBox(width: 8.0.scaled(context, ref)),
                Text(
                  getAccountTypeLabel(context, widget.type),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                SizedBox(width: 6.0.scaled(context, ref)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 5.0.scaled(context, ref),
                    vertical: 1.0.scaled(context, ref),
                  ),
                  decoration: BoxDecoration(
                    color: BeeTokens.textTertiary(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                  ),
                  child: Text(
                    '${widget.accounts.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18.0.scaled(context, ref),
                    color: BeeTokens.iconTertiary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        // 账户卡片列表
        if (_expanded)
          ...widget.accounts.map((account) {
            return _AccountCard(
              key: ValueKey(account.id),
              account: account,
              primaryColor: widget.primaryColor,
              typeColor: typeColor,
              stats: widget.allStats?[account.id],
              onTap: () => widget.onTap(account),
              onEdit: () => widget.onEdit(account),
            );
          }),
      ],
    );
  }
}

/// 账户卡片
class _AccountCard extends ConsumerWidget {
  final db.Account account;
  final Color primaryColor;
  final Color typeColor;
  final ({double balance, double expense, double income})? stats;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AccountCard({
    super.key,
    required this.account,
    required this.primaryColor,
    required this.typeColor,
    this.stats,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDark = BeeTokens.isDark(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onEdit,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.0.scaled(context, ref)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    typeColor.withValues(alpha: 0.25),
                    typeColor.withValues(alpha: 0.12),
                  ]
                : [typeColor, typeColor.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12.0.scaled(context, ref)),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0.scaled(context, ref)),
          child: Stack(
            children: [
              // 装饰圆圈
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 80.0.scaled(context, ref),
                  height: 80.0.scaled(context, ref),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.1),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14.0.scaled(context, ref),
                  vertical: 12.0.scaled(context, ref),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部行：图标 + 名称 + 编辑
                    Row(
                      children: [
                        Container(
                          width: 32.0.scaled(context, ref),
                          height: 32.0.scaled(context, ref),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: AccountTypeIcon(
                              type: account.type,
                              size: 18.0.scaled(context, ref),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.0.scaled(context, ref)),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  account.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.0.scaled(context, ref)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.0.scaled(context, ref),
                                  vertical: 1.0.scaled(context, ref),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4.0.scaled(context, ref)),
                                ),
                                child: Text(
                                  getCurrencyName(account.currency, context),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: EdgeInsets.all(6.0.scaled(context, ref)),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit,
                              color: isDark ? Colors.white.withValues(alpha: 0.8) : Colors.white,
                              size: 14.0.scaled(context, ref),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.0.scaled(context, ref)),
                    // 信用卡：进度条 + 额度信息
                    if (account.type == 'credit_card' && account.creditLimit != null && stats != null)
                      _buildCreditCardStats(context, ref, l10n, isDark)
                    // 估值账户：仅显示当前估值
                    else if (isValuationOnlyType(account.type) && stats != null)
                      _buildValuationStats(context, ref, l10n, isDark)
                    // 普通账户：余额/收入/支出
                    else if (stats != null)
                      _buildNormalStats(context, ref, l10n, isDark)
                    else
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4.0.scaled(context, ref)),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNormalStats(BuildContext context, WidgetRef ref, AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white;
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8);

    return Row(
      children: [
        Expanded(
          child: _CardStat(
            label: l10n.accountBalance,
            value: stats!.balance,
            textColor: textColor,
            labelColor: labelColor,
            ref: ref,
            currencyCode: account.currency,
          ),
        ),
        Container(
          width: 1,
          height: 24.0.scaled(context, ref),
          color: Colors.white.withValues(alpha: 0.2),
        ),
        Expanded(
          child: _CardStat(
            label: l10n.homeIncome,
            value: stats!.income,
            textColor: textColor,
            labelColor: labelColor,
            ref: ref,
            currencyCode: account.currency,
          ),
        ),
        Container(
          width: 1,
          height: 24.0.scaled(context, ref),
          color: Colors.white.withValues(alpha: 0.2),
        ),
        Expanded(
          child: _CardStat(
            label: l10n.homeExpense,
            value: stats!.expense,
            textColor: textColor,
            labelColor: labelColor,
            ref: ref,
            currencyCode: account.currency,
          ),
        ),
      ],
    );
  }

  Widget _buildValuationStats(BuildContext context, WidgetRef ref, AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white;
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8);
    final isLiability = isLiabilityType(account.type);
    final displayValue = isLiability ? stats!.balance.abs() : stats!.balance;
    final label = isLiability ? l10n.valuationCurrentDebt : l10n.valuationCurrentValue;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                ),
              ),
              SizedBox(height: 2.0.scaled(context, ref)),
              AmountText(
                value: displayValue,
                signed: false,
                showCurrency: false,
                useCompactFormat: ref.watch(compactAmountProvider),
                currencyCode: account.currency,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (account.updatedAt != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                Icons.update,
                size: 14.0.scaled(context, ref),
                color: labelColor,
              ),
              SizedBox(height: 2.0.scaled(context, ref)),
              Text(
                '${account.updatedAt!.month.toString().padLeft(2, '0')}-${account.updatedAt!.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 11,
                  color: labelColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCreditCardStats(BuildContext context, WidgetRef ref, AppLocalizations l10n, bool isDark) {
    final creditLimit = account.creditLimit!;
    final used = stats!.balance < 0 ? -stats!.balance : 0.0;
    final usageRate = creditLimit > 0 ? (used / creditLimit).clamp(0.0, 1.0) : 0.0;
    final textColor = isDark ? Colors.white.withValues(alpha: 0.9) : Colors.white;
    final labelColor = isDark ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.8);

    return Column(
      children: [
        // 进度条
        ClipRRect(
          borderRadius: BorderRadius.circular(3.0.scaled(context, ref)),
          child: LinearProgressIndicator(
            value: usageRate,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withValues(alpha: 0.8),
            ),
            minHeight: 4.0.scaled(context, ref),
          ),
        ),
        SizedBox(height: 8.0.scaled(context, ref)),
        Row(
          children: [
            Expanded(
              child: _CardStat(
                label: l10n.creditLimit,
                value: creditLimit,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
            Container(
              width: 1,
              height: 24.0.scaled(context, ref),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _CardStat(
                label: l10n.creditUsed,
                value: used,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
            Container(
              width: 1,
              height: 24.0.scaled(context, ref),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            Expanded(
              child: _CardStat(
                label: l10n.creditAvailable,
                value: creditLimit - used,
                textColor: textColor,
                labelColor: labelColor,
                ref: ref,
                currencyCode: account.currency,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 卡片内统计项
class _CardStat extends StatelessWidget {
  final String label;
  final double value;
  final Color textColor;
  final Color labelColor;
  final WidgetRef ref;
  /// 账户的货币代码 — 用来锁住 formatBalance 的格式;不传则 fallback 到账本货币。
  final String? currencyCode;

  const _CardStat({
    required this.label,
    required this.value,
    required this.textColor,
    required this.labelColor,
    required this.ref,
    this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AmountText(
          value: value,
          signed: false,
          showCurrency: false,
          useCompactFormat: ref.watch(compactAmountProvider),
          currencyCode: currencyCode,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

/// 紧凑默认账户选择行
class _CompactDefaultAccount extends ConsumerWidget {
  final List<db.Account> accounts;
  final Color primaryColor;
  final String type;

  const _CompactDefaultAccount({
    required this.accounts,
    required this.primaryColor,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isIncome = type == 'income';
    final defaultAccountIdAsync = isIncome
        ? ref.watch(defaultIncomeAccountIdProvider)
        : ref.watch(defaultExpenseAccountIdProvider);

    return defaultAccountIdAsync.when(
      data: (defaultAccountId) {
        db.Account? defaultAccount;
        if (defaultAccountId != null) {
          defaultAccount = accounts.where((a) => a.id == defaultAccountId).firstOrNull;
        }

        final title = isIncome
            ? l10n.accountDefaultIncomeTitle
            : l10n.accountDefaultExpenseTitle;

        return InkWell(
          onTap: () => _showPicker(context, ref, accounts, defaultAccountId),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.0.scaled(context, ref),
              vertical: 10.0.scaled(context, ref),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                Text(
                  defaultAccount?.name ?? l10n.accountDefaultNone,
                  style: TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
                SizedBox(width: 2.0.scaled(context, ref)),
                Icon(
                  Icons.chevron_right,
                  size: 16.0.scaled(context, ref),
                  color: BeeTokens.iconTertiary(context),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showPicker(BuildContext context, WidgetRef ref, List<db.Account> accounts, int? currentDefaultId) {
    final l10n = AppLocalizations.of(context);
    final isIncome = type == 'income';
    final title = isIncome ? l10n.accountDefaultIncomeTitle : l10n.accountDefaultExpenseTitle;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BeeTokens.surfaceElevated(context),
        title: Text(title, style: TextStyle(color: BeeTokens.textPrimary(context))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                leading: Icon(Icons.block, color: BeeTokens.iconSecondary(context)),
                title: Text(
                  l10n.accountDefaultNone,
                  style: TextStyle(
                    color: currentDefaultId == null ? primaryColor : BeeTokens.textPrimary(context),
                    fontWeight: currentDefaultId == null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: currentDefaultId == null ? Icon(Icons.check, color: primaryColor) : null,
                onTap: () async {
                  if (isIncome) {
                    await ref.read(defaultAccountSetterProvider).setDefaultIncomeAccountId(null);
                    ref.invalidate(defaultIncomeAccountIdProvider);
                  } else {
                    await ref.read(defaultAccountSetterProvider).setDefaultExpenseAccountId(null);
                    ref.invalidate(defaultExpenseAccountIdProvider);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ...accounts.map((account) {
                final isSelected = account.id == currentDefaultId;
                return ListTile(
                  dense: true,
                  leading: AccountTypeIcon(
                    type: account.type,
                    size: 24,
                  ),
                  title: Text(
                    account.name,
                    style: TextStyle(
                      color: isSelected ? primaryColor : BeeTokens.textPrimary(context),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: primaryColor) : null,
                  onTap: () async {
                    if (isIncome) {
                      await ref.read(defaultAccountSetterProvider).setDefaultIncomeAccountId(account.id);
                      ref.invalidate(defaultIncomeAccountIdProvider);
                    } else {
                      await ref.read(defaultAccountSetterProvider).setDefaultExpenseAccountId(account.id);
                      ref.invalidate(defaultExpenseAccountIdProvider);
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// 资产管理页 header 右上角的「蜜蜂家当」入口。
///
/// 用 Material 标准的 Premium / 进阶版图标(`workspace_premium_outlined`),
/// 跟 setting / add 等 outlined 图标视觉重量完全一致;语义上暗示「升级 /
/// 进阶版本」,鼓励点击。颜色自适应 header 背景。点击进入介绍弹窗。
class _BeeAssetsHeaderEntry extends StatelessWidget {
  const _BeeAssetsHeaderEntry();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final info = beeAssetsPromo(context);
    final texts = buildPromoTexts(context, l10n.aboutBeeAssets);

    return IconButton(
      onPressed: () => ProductPromoLauncher.open(context, info, texts),
      tooltip: info.title,
      icon: const Icon(Icons.auto_awesome_outlined),
    );
  }
}


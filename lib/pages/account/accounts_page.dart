import '../../presentation/v4/bindings/account_sections.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/currency/rate_math.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/account_type_utils.dart';
import '../../utils/currencies.dart';
import '../../widgets/charts/asset_composition_chart.dart';
import '../../widgets/charts/line_chart.dart';
import '../../utils/net_worth_trend_utils.dart';
import '../currency/exchange_rate_page.dart';
import 'account_edit_page.dart';
import 'account_detail_page.dart';
import 'net_worth_trend_page.dart';

class AccountsPage extends ConsumerStatefulWidget {
  final bool asTab;
  const AccountsPage({super.key, this.asTab = false});

  @override
  ConsumerState<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends ConsumerState<AccountsPage> {
  /// 拖拽后临时保持本地排序，防止 stream rebuild 闪烁
  Map<String, List<db.Account>>? _reorderingGroups;

  @override
  void initState() {
    super.initState();
    // 进页静默刷新汇率:内部自带多币种总闸(D6)+ 24h 节流,单币种零请求。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshExchangeRatesFromUi(ref);
    });
  }

  Map<String, List<db.Account>> _groupAccounts(List<db.Account> accounts) {
    final Map<String, List<db.Account>> grouped = {};
    for (final account in accounts) {
      grouped.putIfAbsent(account.type, () => []).add(account);
    }
    return grouped;
  }

  void _onReorder(
      String type, List<db.Account> groupAccounts, int oldIndex, int newIndex) {
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
    final netWorthByCurrencyAsync =
        ref.watch(netWorthBreakdownByCurrencyProvider);

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
              BeeAssetsHeaderEntryBinding(),
              IconButton(
                onPressed: () => _showSettingsSheet(
                    context, ref, accountFeatureAsync, accountsAsync),
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
                        ? 8.0.scaled(context, ref) +
                            56 +
                            MediaQuery.of(context).padding.bottom +
                            24
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
                                onPressed: () =>
                                    _addAccount(context, ref, ledgerId),
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
                        context,
                        ref,
                        netWorthByCurrencyAsync,
                        compositionAsync,
                        primaryColor,
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
                        allStats: allStatsAsync.valueOrNull,
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
                        allStats: allStatsAsync.valueOrNull,
                        primaryColor: primaryColor,
                        ledgerId: ledgerId,
                      ),

                      // 4. 其他未知类型(排除隐藏账户,账户隐藏 #240)
                      ...groups.keys
                          .where((type) =>
                              !accountTypeOrder.contains(type) &&
                              groups[type]!.any((a) => !a.hidden))
                          .map((type) {
                        final groupList =
                            groups[type]!.where((a) => !a.hidden).toList();
                        return AccountTypeGroupBinding(
                          type: type,
                          accounts: groupList,
                          primaryColor: primaryColor,
                          allStats: allStatsAsync.valueOrNull,
                          onReorder: (oldIndex, newIndex) =>
                              _onReorder(type, groupList, oldIndex, newIndex),
                          onTap: (account) =>
                              _viewAccountDetail(context, ref, account),
                          onEdit: (account) =>
                              _editAccount(context, ref, account, ledgerId),
                        );
                      }),

                      // 5. 已隐藏账户分区(账户隐藏 #240,D2:主列表退场,
                      // 分区头小计与净资产卡差额对账)
                      HiddenAccountsSectionBinding(
                        accounts: accounts.where((a) => a.hidden).toList(),
                        allStats: allStatsAsync.valueOrNull,
                        primaryColor: primaryColor,
                        onTap: (account) =>
                            _viewAccountDetail(context, ref, account),
                        onEdit: (account) =>
                            _editAccount(context, ref, account, ledgerId),
                        onRestore: (account) =>
                            _restoreAccount(context, ref, account),
                      ),
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
    AsyncValue<
            Map<
                String,
                ({
                  double totalAssets,
                  double totalLiabilities,
                  double netWorth
                })>>
        netWorthAsync,
    AsyncValue<List<({String type, double totalBalance})>> compositionAsync,
    Color primaryColor,
  ) {
    // reload 时 asData 会短暂变 null 致布局闪动,用 valueOrNull 保留上次结果
    final isSingleCurrency = (netWorthAsync.valueOrNull?.length ?? 1) <= 1;
    // 折算态:总闸开启时也展示饼图,数据换成折算后聚合(主币种口径)。
    final multiCurrencyActive = ref.watch(multiCurrencyActiveProvider);
    final showComposition = isSingleCurrency || multiCurrencyActive;
    // 折算 active 喂折算后构成;否则原币构成。组件入参类型相同。
    final effectiveCompositionAsync = multiCurrencyActive
        ? ref.watch(convertedAssetCompositionProvider)
        : compositionAsync;

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 净资产部分
          netWorthAsync.when(
            skipLoadingOnReload: true,
            data: (nwByCurrency) =>
                _buildNetWorthContent(context, ref, nwByCurrency),
            loading: () => SizedBox(
              height: 80.0.scaled(context, ref),
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // 走势 / 构成 切换区:
          // - showComposition=true（单币种 或 折算态）：可在「净值走势」「资产构成」间切换，记住偏好；
          // - showComposition=false（多币种非折算，构成无法合并）：只展示走势（净值裸加）。
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
            child: Divider(height: 1, color: BeeTokens.divider(context)),
          ),
          Builder(builder: (context) {
            final view = showComposition
                ? ref.watch(assetTrendViewProvider)
                : AssetTrendView.trend;
            return Column(
              children: [
                if (showComposition)
                  Padding(
                    padding: EdgeInsets.only(top: 10.0.scaled(context, ref)),
                    child: _trendCompositionToggle(
                        context, ref, view, primaryColor),
                  ),
                Padding(
                  padding: EdgeInsets.all(12.0.scaled(context, ref)),
                  child: view == AssetTrendView.composition
                      ? effectiveCompositionAsync.when(
                          skipLoadingOnReload: true,
                          data: (data) =>
                              AssetCompositionChart(data: data, embedded: true),
                          loading: () => SizedBox(
                            height: 180.0.scaled(context, ref),
                            child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        )
                      : _buildNetWorthChartInline(context, ref),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 净资产内容（不含外层 SectionCard）
  Widget _buildNetWorthContent(
    BuildContext context,
    WidgetRef ref,
    Map<String,
            ({double totalAssets, double totalLiabilities, double netWorth})>
        nwByCurrency,
  ) {
    final l10n = AppLocalizations.of(context);
    final useCompact = ref.watch(compactAmountProvider);

    // 多币种态总闸开启且折算结果就绪 → 走折算视图;否则原 per-currency 渲染原样回退。
    final multiCurrencyActive = ref.watch(multiCurrencyActiveProvider);
    final converted = ref.watch(convertedNetWorthProvider).valueOrNull;
    if (multiCurrencyActive && converted != null) {
      return _buildConvertedNetWorthContent(
          context, ref, converted, useCompact);
    }

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
              padding:
                  EdgeInsets.only(top: isFirst ? 0 : 2.0.scaled(context, ref)),
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
                child: StatCellBinding(
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
                child: StatCellBinding(
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
                        context,
                        ref,
                        entries: nwByCurrency.entries
                            .where((e) => e.value.totalAssets != 0)
                            .map((e) =>
                                (currency: e.key, value: e.value.totalAssets))
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
                        context,
                        ref,
                        entries: nwByCurrency.entries
                            .where((e) => e.value.totalLiabilities != 0)
                            .map((e) => (
                                  currency: e.key,
                                  value: e.value.totalLiabilities.abs()
                                ))
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

  /// 资产卡内嵌净值走势图（完整版：带网格 + 月份标签，非缩略 sparkline），点击进全屏
  /// 趋势页。interactive:false → LineChart 不吞 tap，把点击交给外层 InkWell。
  Widget _buildNetWorthChartInline(BuildContext context, WidgetRef ref) {
    final now = trendTodayAnchor();
    final start = DateTime(now.year, now.month - 11, 1);
    final seriesAsync = ref
        .watch(netWorthTrendSeriesProvider((startDate: start, endDate: now)));
    final hide = ref.watch(hideAmountsProvider);
    final primary = ref.watch(primaryColorProvider);
    final l10n = AppLocalizations.of(context);
    return seriesAsync.maybeWhen(
      data: (series) {
        final monthly = downsampleMonthly(series);
        if (monthly.length < 2) {
          return _inlineChartBox(
            context,
            ref,
            Text(l10n.commonEmpty,
                style: TextStyle(
                    fontSize: 12, color: BeeTokens.textTertiary(context))),
          );
        }
        return InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NetWorthTrendPage()),
          ),
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 180.0.scaled(context, ref),
            child: LineChart(
              values: monthly.map((e) => e.net).toList(),
              xLabels: monthly
                  .map((e) => '${e.date.year % 100}/${e.date.month}')
                  .toList(),
              highlightIndex: monthly.length - 1,
              onSwipeLeft: () {},
              onSwipeRight: () {},
              showHint: false,
              hideAmounts: hide,
              themeColor: primary,
              whiteBg: !BeeTokens.isDark(context),
              isDark: BeeTokens.isDark(context),
              showGrid: true,
              showDots: false,
              annotate: true,
              interactive: false, // 点击交给外层 InkWell 进全屏页
              minimal: true, // 去背景/Y轴/均线，避免嵌在 SectionCard 内暗黑模式「卡中卡」
            ),
          ),
        );
      },
      error: (_, __) => _inlineChartBox(
        context,
        ref,
        Text(l10n.commonError,
            style: TextStyle(
                fontSize: 12, color: BeeTokens.textTertiary(context))),
      ),
      orElse: () => _inlineChartBox(context, ref,
          const Center(child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }

  Widget _inlineChartBox(BuildContext context, WidgetRef ref, Widget child) =>
      SizedBox(
        height: 180.0.scaled(context, ref),
        child: Center(child: child),
      );

  /// 走势 / 构成 切换控件（主题色分段胶囊）。
  Widget _trendCompositionToggle(
      BuildContext context, WidgetRef ref, AssetTrendView view, Color primary) {
    final l10n = AppLocalizations.of(context);
    Widget seg(AssetTrendView v, String label) {
      final on = view == v;
      return GestureDetector(
        onTap: () => ref.read(assetTrendViewProvider.notifier).select(v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
              horizontal: 14.0.scaled(context, ref),
              vertical: 6.0.scaled(context, ref)),
          decoration: BoxDecoration(
            color: on ? primary.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: on ? primary : BeeTokens.border(context), width: 1),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                color: on ? primary : BeeTokens.textSecondary(context),
                fontWeight: on ? FontWeight.w600 : FontWeight.normal,
              )),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        seg(AssetTrendView.trend, l10n.netWorthTrendTitle),
        SizedBox(width: 8.0.scaled(context, ref)),
        seg(AssetTrendView.composition, l10n.assetComposition),
      ],
    );
  }

  /// 折算视图：净资产折算总额 + 每币种折算行 + 缺失标示 + 脚注入口 + 折算总资产/总负债。
  /// 仅在多币种总闸开启且 [convertedNetWorthProvider] 就绪时渲染（见 _buildNetWorthContent）。
  Widget _buildConvertedNetWorthContent(
    BuildContext context,
    WidgetRef ref,
    ConvertedNetWorth converted,
    bool useCompact,
  ) {
    final l10n = AppLocalizations.of(context);
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final nwByCurrency =
        ref.watch(netWorthBreakdownByCurrencyProvider).valueOrNull ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标题行：左 净资产(折X) 标签 + 右 详情入口
        Row(
          children: [
            const Spacer(),
            Text(
              l10n.convertedNetWorth(base),
              style: TextStyle(
                fontSize: 12,
                color: BeeTokens.textTertiary(context),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _showNetWorthConversionDetail(
                      context, ref, converted, nwByCurrency, base, useCompact),
                  borderRadius: BorderRadius.circular(4.0.scaled(context, ref)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4.0.scaled(context, ref),
                      vertical: 2.0.scaled(context, ref),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.commonDetail,
                          style: TextStyle(
                            fontSize: 12,
                            color: BeeTokens.textTertiary(context),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 14.0.scaled(context, ref),
                          color: BeeTokens.iconTertiary(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 4.0.scaled(context, ref)),
        // 折算总额：≈(灰) + 折算净资产(主币种符号, 收支色)
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '≈ ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: BeeTokens.textTertiary(context),
              ),
            ),
            Flexible(
              child: AmountText(
                value: converted.netWorth,
                signed: false,
                showCurrency: true,
                currencyCode: base,
                useCompactFormat: useCompact,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: converted.netWorth >= 0
                      ? BeeTokens.incomeColor(context, ref)
                      : BeeTokens.expenseColor(context, ref),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.0.scaled(context, ref)),
        // 折算总资产 | 折算总负债(单行折算版)
        Row(
          children: [
            Expanded(
              child: ConvertedStatCellBinding(
                label: l10n.totalAssets,
                value: converted.totalAssets,
                currencyCode: base,
                valueColor: BeeTokens.incomeColor(context, ref),
                useCompact: useCompact,
              ),
            ),
            Container(
              width: 1,
              height: 28.0.scaled(context, ref),
              color: BeeTokens.divider(context),
            ),
            Expanded(
              child: ConvertedStatCellBinding(
                label: l10n.totalLiabilities,
                value: converted.totalLiabilities.abs(),
                currencyCode: base,
                valueColor: BeeTokens.expenseColor(context, ref),
                useCompact: useCompact,
              ),
            ),
          ],
        ),
        // 汇率折算脚注已折叠进「详情」弹窗(见 _showNetWorthConversionDetail），首屏不再展示。
        SizedBox(height: 8.0.scaled(context, ref)),
      ],
    );
  }

  /// 净资产折算明细弹窗:每币种原币净值 + 折算后/未折算。复用 showAccountConversionDetailSheet。
  void _showNetWorthConversionDetail(
    BuildContext context,
    WidgetRef ref,
    ConvertedNetWorth converted,
    Map<String,
            ({double totalAssets, double totalLiabilities, double netWorth})>
        nwByCurrency,
    String base,
    bool useCompact,
  ) {
    final l10n = AppLocalizations.of(context);
    final baseSymbol = getCurrencySymbol(base);
    final entries = nwByCurrency.entries.map((e) {
      final code = e.key.toUpperCase();
      return AccountConversionEntry(
        code: code,
        originalValue: e.value.netWorth,
        convertedValue: converted.netByCurrency[code],
        isBase: code == base,
        isMissing: converted.missingCurrencies.contains(code),
      );
    }).toList();
    // 汇率折算脚注（原在资产页首屏）折叠到这里:无缺失→折算日期(>7 天变橙),有缺失→
    // 缺失提示(橙),点击进汇率页管理。
    final hasMissing = converted.missingCurrencies.isNotEmpty;
    final rd = converted.oldestRateDate != null
        ? DateTime.tryParse(converted.oldestRateDate!)
        : null;
    final isStale = !hasMissing &&
        rd != null &&
        DateTime.now().difference(rd) > const Duration(days: 7);
    final footer = InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExchangeRatePage()),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          hasMissing
              ? l10n.convertedPartialWarning(
                  converted.missingCurrencies.join('/'))
              : l10n.convertedFootnote(converted.oldestRateDate ?? '-'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: (hasMissing || isStale)
                ? Colors.orange
                : BeeTokens.textTertiary(context),
          ),
        ),
      ),
    );
    showAccountConversionDetailSheet(
      context,
      ref,
      title: l10n.conversionDetailTitle,
      entries: entries,
      baseSymbol: baseSymbol,
      useCompact: useCompact,
      footer: footer,
    );
  }

  /// 分组小计折算视图:≈ {symbol}{折算和}(有缺失加橙警示),整块点击 → 分组明细弹窗。
  /// 折算口径与净资产/构成图一致:缺汇率币种剔除,绝不按 1.0。
  Widget _buildGroupConvertedSubtotal(
    BuildContext context,
    WidgetRef ref, {
    required String groupTitle,
    required Map<String, double> subtotalByCurrency,
    required Map<String, EffectiveRate> rates,
    required String base,
    required Color iconColor,
    required bool useCompact,
  }) {
    final baseSymbol = getCurrencySymbol(base);
    final result = convertAmountsToBase(
      amounts: subtotalByCurrency,
      rates: rates,
      base: base,
    );
    final hasMissing = result.missingCurrencies.isNotEmpty;
    final hide = ref.watch(hideAmountsProvider);

    return InkWell(
      onTap: () => _showGroupConversionDetail(
        context,
        ref,
        groupTitle: groupTitle,
        subtotalByCurrency: subtotalByCurrency,
        result: result,
        baseSymbol: baseSymbol,
        base: base,
        useCompact: useCompact,
      ),
      borderRadius: BorderRadius.circular(4.0.scaled(context, ref)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4.0.scaled(context, ref),
          vertical: 2.0.scaled(context, ref),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (hasMissing) ...[
              Icon(
                Icons.warning_amber_rounded,
                size: 14.0.scaled(context, ref),
                color: Colors.orange,
              ),
              SizedBox(width: 4.0.scaled(context, ref)),
            ],
            Flexible(
              // abs 以沿用现状符号惯例:非折算时小计走 AmountText(signed:false) 即显绝对值,
              // 负债组同口径(折算值不带负号)。
              child: Text(
                hide
                    ? '≈ ****'
                    : '≈ $baseSymbol${result.total.abs().toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 14.0.scaled(context, ref),
              color: BeeTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 分组小计折算明细弹窗:每币种原币小计 + 折算后/未折算。复用 showAccountConversionDetailSheet。
  void _showGroupConversionDetail(
    BuildContext context,
    WidgetRef ref, {
    required String groupTitle,
    required Map<String, double> subtotalByCurrency,
    required ({
      double total,
      Map<String, double> convertedByCurrency,
      List<String> missingCurrencies
    }) result,
    required String baseSymbol,
    required String base,
    required bool useCompact,
  }) {
    final entries = subtotalByCurrency.entries.map((e) {
      final code = e.key.toUpperCase();
      return AccountConversionEntry(
        code: code,
        originalValue: e.value,
        convertedValue: result.convertedByCurrency[code],
        isBase: code == base,
        isMissing: result.missingCurrencies.contains(code),
      );
    }).toList();
    showAccountConversionDetailSheet(
      context,
      ref,
      title: groupTitle,
      entries: entries,
      baseSymbol: baseSymbol,
      useCompact: useCompact,
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
                padding:
                    EdgeInsets.symmetric(horizontal: 4.0.scaled(context, ref)),
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
    required Map<int, ({double balance, double expense, double income})>?
        allStats,
    required Color primaryColor,
    required int ledgerId,
  }) {
    // 检查此分类下是否有在用(非隐藏)账户 —— 账户隐藏 #240:隐藏账户移入
    // 底部「已隐藏」分区(HiddenAccountsSectionBinding),此处只看在用账户。
    final hasAccounts = typeOrder.any((type) =>
        groups.containsKey(type) && groups[type]!.any((a) => !a.hidden));
    if (!hasAccounts) return [];

    // 按币种分组计算小计(仅在用账户;隐藏账户的小计在「已隐藏」分区单独
    // 展示,两者相加与净资产汇总卡对账 —— 01 §4.1)
    final Map<String, double> subtotalByCurrency = {};
    for (final type in typeOrder) {
      if (groups.containsKey(type)) {
        for (final account in groups[type]!) {
          if (account.hidden) continue;
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

    // 折算态(总闸开启且汇率就绪)且组内多币种 → 小计折算并支持点击详情。
    final multiCurrencyActive = ref.watch(multiCurrencyActiveProvider);
    final rates = ref.watch(effectiveRatesProvider).valueOrNull;
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final convertActive =
        multiCurrencyActive && rates != null && !isSingleCurrency;

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
            if (convertActive)
              // 折算小计:≈ {symbol}{折算和}(有缺失加橙色警示),整块点击进详情。
              // Expanded+Align 保证贴右(Spacer+Flexible 会让内容在右半槽内左对齐,
              // 表头右侧出现空白),内部 Text 仍有 Flexible/ellipsis 兜长文本。
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildGroupConvertedSubtotal(
                    context,
                    ref,
                    groupTitle: title,
                    subtotalByCurrency: subtotalByCurrency,
                    rates: rates,
                    base: base,
                    iconColor: iconColor,
                    useCompact: useCompact,
                  ),
                ),
              )
            else if (isSingleCurrency)
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
                  context,
                  ref,
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
      // 类型分组(排除隐藏账户,账户隐藏 #240)
      ...typeOrder
          .where((type) =>
              groups.containsKey(type) && groups[type]!.any((a) => !a.hidden))
          .map((type) {
        final groupList = groups[type]!.where((a) => !a.hidden).toList();
        return AccountTypeGroupBinding(
          type: type,
          accounts: groupList,
          primaryColor: primaryColor,
          allStats: allStats,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(type, groupList, oldIndex, newIndex),
          onTap: (account) => _viewAccountDetail(context, ref, account),
          onEdit: (account) => _editAccount(context, ref, account, ledgerId),
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
    // 默认收/支账户选择器排除隐藏账户(账户隐藏 #240 §四):列表本身不出现,
    // 且若当前默认恰好指向隐藏账户,下方 CompactDefaultAccountBinding 找不到匹配项
    // 会自动显示「不设置」,兜底 E3。
    final accounts = (accountsAsync.asData?.value ?? const <db.Account>[])
        .where((a) => !a.hidden)
        .toList();

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
                      color: BeeTokens.textTertiary(context)
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // 标题
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  // 汇率管理入口:仅在使用中币种 ≥2 时出现。折算开关已下线
                  // (多币种恒折算,与 Web 端对齐),这里只保留汇率管理入口。
                  Consumer(
                    builder: (context, ref, _) {
                      final used =
                          ref.watch(usedCurrenciesProvider).valueOrNull;
                      if (used == null || used.length < 2) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: BeeTokens.divider(context),
                          ),
                          ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              l10n.exchangeRatePageTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: BeeTokens.textPrimary(context),
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              size: 18.0.scaled(context, ref),
                              color: BeeTokens.iconTertiary(context),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const ExchangeRatePage()),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  if (enabled && accounts.isNotEmpty) ...[
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: BeeTokens.divider(context),
                    ),
                    CompactDefaultAccountBinding(
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
                    CompactDefaultAccountBinding(
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

  Future<void> _addAccount(
      BuildContext context, WidgetRef ref, int ledgerId) async {
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

  /// 「已隐藏」分区卡片上的「恢复」快捷入口(账户隐藏 #240)。恢复无需确认
  /// (低风险、可逆,产品设计 01 §3.2),即时生效并推送同步。
  Future<void> _restoreAccount(
      BuildContext context, WidgetRef ref, db.Account account) async {
    final l10n = AppLocalizations.of(context);
    await ref.read(repositoryProvider).setAccountHidden(account.id, false);

    // 账户变更推同步,同 _onReorder 的写法。
    final activeLedgerId = ref.read(currentLedgerIdProvider);
    if (activeLedgerId > 0) {
      unawaited(PostProcessor.sync(ref, ledgerId: activeLedgerId));
    }

    // 只 bump tick,不 invalidate,避免资产页整页 loading 闪烁(同 _addAccount)。
    ref.read(statsRefreshProvider.notifier).state++;

    if (context.mounted) showToast(context, l10n.accountRestoredToast);
  }
}

/// Header 内统计项（白色文字）

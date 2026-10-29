part of '../../accounts_page.dart';

mixin _AccountsOverviewBindings on ConsumerState<AccountsPage> {
  String _assetAccountFilter = 'all';
  bool _assetOriginalCurrency = false;
  String? _assetCurrency;
  int? _assetTrendIndex;
  final _assetListController = ScrollController();
  final _assetHiddenKey = GlobalKey();
  bool _assetLocatingHidden = false;
  void _updateAssetView(VoidCallback update) => setState(update);

  Map<String, List<db.Account>>? get _reorderingGroups;
  Map<String, List<db.Account>> _groupAccounts(List<db.Account> accounts);
  void _onReorder(
      String type, List<db.Account> accounts, int oldIndex, int newIndex);

  Widget _buildAccountsBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accountDisplay = AccountCardDisplayData.watch(ref);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final accountsAsync = ref.watch(allAccountsStreamProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final allStatsAsync = ref.watch(allAccountStatsProvider);
    final netWorthByCurrencyAsync =
        ref.watch(netWorthBreakdownByCurrencyProvider);
    final compositionAsync = ref.watch(assetCompositionProvider);
    return accountsAsync.when(
      skipLoadingOnReload: true,
      data: (accounts) {
        final groups = _reorderingGroups ?? _groupAccounts(accounts);

        return ListView(
          controller: _assetListController,
          padding: EdgeInsets.only(
            left: 17,
            right: 17,
            top: 8.0.scaled(context, ref),
            bottom: widget.asTab
                ? 8.0.scaled(context, ref) +
                    56 +
                    MediaQuery.of(context).padding.bottom +
                    24
                : 24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (accounts.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: BeeStatus(
                      label: l10n.accountsEmptyMessage,
                      action: BeeButton(
                          label: l10n.accountAddButton,
                          onPressed: () =>
                              _addAccount(context, ref, ledgerId))))
            else ...[
              // 资产汇总及图表分别使用受控业务组件。
              _buildNetWorthAndCompositionCard(
                context,
                ref,
                netWorthByCurrencyAsync,
                compositionAsync,
                primaryColor,
              ),

              BeeAssetAccountToolbar(
                  items: [
                    BeeSegment('all', l10n.v4AssetsAllAccounts),
                    BeeSegment('assets', l10n.assetAccounts),
                    BeeSegment('liabilities', l10n.liabilityAccounts)
                  ],
                  value: _assetAccountFilter,
                  onChanged: (value) =>
                      setState(() => _assetAccountFilter = value),
                  searchLabel: l10n.commonSearch,
                  onSearch: () => _showAssetSearch(accounts),
                  orderLabel: l10n.v4AssetsOrder,
                  onOrder: () => _showAssetOrder(accounts)),

              if ((_assetAccountFilter == 'assets' &&
                      !accounts.any((a) => !a.hidden && isAssetType(a.type))) ||
                  (_assetAccountFilter == 'liabilities' &&
                      !accounts
                          .any((a) => !a.hidden && isLiabilityType(a.type))))
                BeeSurface(child: BeeStatus(label: l10n.widgetNoAccounts)),

              // 2. 资产账户分组
              if (_assetAccountFilter != 'liabilities')
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
                  accountDisplay: accountDisplay,
                ),

              // 3. 负债账户分组
              if (_assetAccountFilter != 'assets')
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
                  accountDisplay: accountDisplay,
                ),

              // 4. 其他未知类型(排除隐藏账户,账户隐藏 #240)
              ...groups.keys
                  .where((type) =>
                      _assetAccountFilter != 'liabilities' &&
                      !accountTypeOrder.contains(type) &&
                      groups[type]!.any((a) => !a.hidden))
                  .map((type) {
                final groupList =
                    groups[type]!.where((a) => !a.hidden).toList();
                return AccountTypeGroupBinding(
                  key: ValueKey('account-type-$type'),
                  compact: true,
                  type: type,
                  accounts: groupList,
                  primaryColor: primaryColor,
                  allStats: allStatsAsync.valueOrNull,
                  display: accountDisplay,
                  onReorder: (oldIndex, newIndex) =>
                      _onReorder(type, groupList, oldIndex, newIndex),
                  onTap: (account) => _viewAccountDetail(context, ref, account),
                  onEdit: (account) =>
                      _editAccount(context, ref, account, ledgerId),
                );
              }),

              // 5. 已隐藏账户分区(账户隐藏 #240,D2:主列表退场,
              // 分区头小计与净资产卡差额对账)
              HiddenAccountsSectionBinding(
                key: _assetHiddenKey,
                compact: true,
                accounts: accounts.where((a) => a.hidden).toList(),
                allStats: allStatsAsync.valueOrNull,
                display: accountDisplay,
                primaryColor: primaryColor,
                onTap: (account) => _viewAccountDetail(context, ref, account),
                onEdit: (account) =>
                    _editAccount(context, ref, account, ledgerId),
                onRestore: (account) => _restoreAccount(context, ref, account),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => BeeStatus(
          label: l10n.commonError,
          tone: BeeTone.error,
          detail: err.toString(),
          action: BeeButton(
              label: l10n.helpCenterRetry,
              onPressed: () => ref.invalidate(allAccountsStreamProvider))),
    );
  }

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
      Color primaryColor) {
    final l = AppLocalizations.of(context);
    final multiCurrency = ref.watch(multiCurrencyActiveProvider);
    final showComposition = (netWorthAsync.valueOrNull?.length ?? 1) <= 1 ||
        (!_assetOriginalCurrency && multiCurrency);
    final composition = multiCurrency
        ? ref.watch(convertedAssetCompositionProvider)
        : compositionAsync;
    final view = showComposition
        ? ref.watch(assetTrendViewProvider)
        : AssetTrendView.trend;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      netWorthAsync.when(
          skipLoadingOnReload: true,
          data: (data) => _buildNetWorthContent(context, ref, data),
          loading: () => const BeeSurface(
              child: SizedBox(
                  height: 160,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (_, __) => BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action: BeeButton(
                  label: l.helpCenterRetry,
                  onPressed: () =>
                      ref.invalidate(netWorthBreakdownByCurrencyProvider)))),
      const SizedBox(height: 11),
      BeeAssetChartSection<AssetTrendView>(
          compact: true,
          title: view == AssetTrendView.trend
              ? l.netWorthTrendTitle
              : l.assetComposition,
          segments: [
            BeeSegment(AssetTrendView.trend, l.v4AssetsTrend),
            BeeSegment(AssetTrendView.composition, l.v4AssetsComposition,
                enabled: showComposition)
          ],
          selected: view,
          onSelected: (value) =>
              ref.read(assetTrendViewProvider.notifier).select(value),
          child: view == AssetTrendView.trend
              ? _buildNetWorthChartInline(context, ref)
              : composition.when(
                  skipLoadingOnReload: true,
                  data: (data) => BeeAssetComposition(
                      hidden: ref.watch(hideAmountsProvider),
                      items: [
                        for (final item in data)
                          if (item.totalBalance > 0)
                            BeeAssetAllocation(
                                label: getAccountTypeLabel(context, item.type),
                                value: item.totalBalance,
                                amount: _overviewAmount(item.totalBalance,
                                    currency: ref.watch(baseCurrencyProvider),
                                    showCurrency: true))
                      ],
                      note: data.any((d) => d.totalBalance < 0)
                          ? l.negativeAssetBalanceHint
                          : null),
                  loading: () => const SizedBox(
                      height: 110,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) =>
                      BeeStatus(label: l.commonError, tone: BeeTone.error)))
    ]);
  }

  String _overviewAmount(double value,
      {String? currency, bool showCurrency = false}) {
    final selectedLocale = ref.watch(languageProvider);
    final isChinese = selectedLocale?.languageCode == 'zh' ||
        (selectedLocale == null &&
            Localizations.localeOf(context).languageCode == 'zh');
    return formatDisplayAmount(value,
        currencyCode:
            currency ?? ref.watch(currentLedgerProvider).valueOrNull?.currency,
        showCurrency: showCurrency,
        useCompactFormat: ref.watch(compactAmountProvider),
        isChineseLocale: isChinese,
        signed: false);
  }

  Widget _buildNetWorthContent(
      BuildContext context,
      WidgetRef ref,
      Map<String,
              ({double totalAssets, double totalLiabilities, double netWorth})>
          byCurrency) {
    final l = AppLocalizations.of(context);
    final multi = ref.watch(multiCurrencyActiveProvider);
    final converted = ref.watch(convertedNetWorthProvider).valueOrNull;
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final useCompact = ref.watch(compactAmountProvider);
    final isConverted = multi && converted != null && !_assetOriginalCurrency;
    final code = byCurrency.containsKey(_assetCurrency)
        ? _assetCurrency!
        : byCurrency.containsKey(base)
            ? base
            : byCurrency.keys.firstOrNull ?? base;
    final original = byCurrency[code] ??
        (totalAssets: 0.0, totalLiabilities: 0.0, netWorth: 0.0);
    final assets = isConverted ? converted.totalAssets : original.totalAssets;
    final liabilities =
        isConverted ? converted.totalLiabilities : original.totalLiabilities;
    final net = isConverted ? converted.netWorth : original.netWorth;
    final displayCode = isConverted ? base : code;
    final hiddenAccounts = (ref.watch(allAccountsStreamProvider).valueOrNull ??
            const <db.Account>[])
        .where((a) => a.hidden)
        .length;
    return BeeAssetSummary(
        compact: true,
        title: l.accountTotalBalance,
        balances: [
          BeeAssetAmount(
              _overviewAmount(net,
                  currency: displayCode,
                  showCurrency: isConverted || byCurrency.length > 1),
              approximate: isConverted)
        ],
        assetsLabel: l.totalAssets,
        assets: [
          _overviewAmount(assets,
              currency: displayCode,
              showCurrency: isConverted || byCurrency.length > 1)
        ],
        liabilitiesLabel: l.totalLiabilities,
        liabilities: [
          _overviewAmount(liabilities.abs(),
              currency: displayCode,
              showCurrency: isConverted || byCurrency.length > 1)
        ],
        hidden: ref.watch(hideAmountsProvider),
        privacyLabel:
            ref.watch(hideAmountsProvider) ? l.v4AmountsShow : l.v4AmountsHide,
        onPrivacy: () => ref.read(hideAmountsProvider.notifier).state =
            !ref.read(hideAmountsProvider),
        unitLabel: isConverted
            ? l.v4RecordingConvertedLabel(base)
            : '$displayCode · ${l.v4AssetsOriginal}',
        onUnit: () => _showAssetCurrency(byCurrency.keys.toList()),
        currencies: !isConverted && byCurrency.length > 1
            ? [for (final c in byCurrency.keys) BeeSegment(c, c)]
            : const [],
        currency: code,
        onCurrency: (value) => setState(() => _assetCurrency = value),
        footnote: hiddenAccounts > 0
            ? l.v4AssetsIncludesHidden(hiddenAccounts)
            : l.v4AssetsAllAccounts,
        onFootnote: hiddenAccounts > 0 ? _scrollToAssetHidden : null,
        detailLabel: isConverted && converted.missingCurrencies.isNotEmpty
            ? l.unconvertedBadge
            : l.conversionDetailTitle,
        warning: isConverted && converted.missingCurrencies.isNotEmpty,
        onDetails: isConverted
            ? () => _showNetWorthConversionDetail(
                context, ref, converted, byCurrency, base, useCompact)
            : () => showAccountConversionDetailSheet(context, ref,
                title: l.v4AssetsByCurrency,
                entries: [
                  for (final e in byCurrency.entries)
                    AccountConversionEntry(
                        code: e.key,
                        originalValue: e.value.netWorth,
                        convertedValue: null,
                        isBase: true,
                        isMissing: false)
                ],
                baseSymbol: getCurrencySymbol(base),
                useCompact: useCompact));
  }

  /// 资产卡内嵌净值走势图（完整版：带网格 + 月份标签，非缩略 sparkline），点击进全屏
  /// 趋势页。interactive:false → LineChart 不吞 tap，把点击交给外层 InkWell。
  Widget _buildNetWorthChartInline(BuildContext context, WidgetRef ref) {
    final now = trendTodayAnchor(), l = AppLocalizations.of(context);
    final start = DateTime(now.year, now.month - 5, 1);
    final seriesAsync = ref
        .watch(netWorthTrendSeriesProvider((startDate: start, endDate: now)));
    final hide = ref.watch(hideAmountsProvider),
        base = ref.watch(baseCurrencyProvider);
    return seriesAsync.when(
        skipLoadingOnReload: true,
        data: (series) {
          final monthly = downsampleMonthly(series);
          if (monthly.length < 2) {
            return Padding(
                padding: const EdgeInsets.all(22), child: Text(l.commonEmpty));
          }
          final selected = (_assetTrendIndex ?? monthly.length - 1)
              .clamp(0, monthly.length - 1);
          final point = monthly[selected];
          final labels = monthly.map((p) => '${p.date.month}').toList();
          return BeeAssetTrendPreview(
              values: monthly.map((p) => p.net).toList(),
              labels: labels,
              selected: selected,
              pointLabel: '${point.date.year}/${point.date.month}',
              amount: _overviewAmount(point.net,
                  currency: base, showCurrency: true),
              hidden: hide,
              onSelected: (index) => setState(() => _assetTrendIndex = index),
              detailLabel: '${l.netWorthTrend6M} · $base',
              onDetails: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NetWorthTrendPage())));
        },
        error: (_, __) => Padding(
            padding: const EdgeInsets.all(22), child: Text(l.commonError)),
        loading: () => const SizedBox(
            height: 115,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
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
    required AccountCardDisplayData accountDisplay,
  }) {
    // 检查此分类下是否有在用(非隐藏)账户 —— 账户隐藏 #240:隐藏账户移入
    // 底部「已隐藏」分区(HiddenAccountsSectionBinding),此处只看在用账户。
    final hasAccounts = typeOrder.any((type) =>
        groups.containsKey(type) && groups[type]!.any((a) => !a.hidden));
    if (!hasAccounts) return [];

    return [
      // 类型分组(排除隐藏账户,账户隐藏 #240)
      ...typeOrder
          .where((type) =>
              groups.containsKey(type) && groups[type]!.any((a) => !a.hidden))
          .map((type) {
        final groupList = groups[type]!.where((a) => !a.hidden).toList();
        return AccountTypeGroupBinding(
          key: ValueKey('account-type-$type'),
          compact: true,
          type: type,
          accounts: groupList,
          primaryColor: primaryColor,
          allStats: allStats,
          display: accountDisplay,
          onReorder: (oldIndex, newIndex) =>
              _onReorder(type, groupList, oldIndex, newIndex),
          onTap: (account) => _viewAccountDetail(context, ref, account),
          onEdit: (account) => _editAccount(context, ref, account, ledgerId),
        );
      }),
    ];
  }

  Future<void> _showSettingsSheet() async {
    final l = AppLocalizations.of(context);
    await showBeeSheet<void>(context, title: l.commonSettings,
        child: Consumer(builder: (sheet, localRef, _) {
      final accounts = (localRef.watch(allAccountsStreamProvider).valueOrNull ??
              const <db.Account>[])
          .where((account) => !account.hidden)
          .toList();
      final enabled =
          localRef.watch(accountFeatureEnabledProvider).valueOrNull ?? false;
      final expense =
          localRef.watch(defaultExpenseAccountIdProvider).valueOrNull;
      final income = localRef.watch(defaultIncomeAccountIdProvider).valueOrNull;
      final used = localRef.watch(usedCurrenciesProvider).valueOrNull;
      String accountName(int? id) =>
          accounts.where((a) => a.id == id).firstOrNull?.name ??
          l.accountDefaultNone;
      return SingleChildScrollView(
          child: BeeAccountPreferences(
              enabled: enabled,
              enableLabel: l.accountsEnableFeature,
              onEnabled: (value) async {
                await localRef
                    .read(accountFeatureSetterProvider)
                    .setEnabled(value);
                localRef.invalidate(accountFeatureEnabledProvider);
              },
              showDefaults: accounts.isNotEmpty,
              expenseLabel: l.accountDefaultExpenseTitle,
              expenseAccount: accountName(expense),
              onExpenseAccount: () => _showDefaultAccountPicker(sheet,
                  accounts: accounts, current: expense, income: false),
              incomeLabel: l.accountDefaultIncomeTitle,
              incomeAccount: accountName(income),
              onIncomeAccount: () => _showDefaultAccountPicker(sheet,
                  accounts: accounts, current: income, income: true),
              rateLabel: l.exchangeRatePageTitle,
              onRates: used != null && used.length >= 2
                  ? () {
                      Navigator.pop(sheet);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const ExchangeRatePage()));
                    }
                  : null));
    }));
  }

  Future<void> _showDefaultAccountPicker(BuildContext sheet,
      {required List<db.Account> accounts,
      required int? current,
      required bool income}) async {
    final l = AppLocalizations.of(context);
    await showBeeDialog<void>(sheet,
        title:
            income ? l.accountDefaultIncomeTitle : l.accountDefaultExpenseTitle,
        child: Builder(
            builder: (dialog) => BeeAccountPicker(
                    accounts: [
                      for (final a in accounts)
                        BeeAccountChoice(
                            id: '${a.id}',
                            name: a.name,
                            currency: a.currency,
                            detail: getAccountTypeLabel(context, a.type),
                            icon: AccountTypeIcon(type: a.type, size: 22))
                    ],
                    currency: ref.read(baseCurrencyProvider),
                    filterByCurrency: false,
                    selected: current?.toString(),
                    searchLabel: l.commonSearch,
                    emptyLabel: l.widgetNoAccounts,
                    unsetLabel: l.accountDefaultNone,
                    onSelected: (id) async {
                      final setter = ref.read(defaultAccountSetterProvider);
                      if (income) {
                        await setter.setDefaultIncomeAccountId(
                            id == null ? null : int.parse(id));
                        ref.invalidate(defaultIncomeAccountIdProvider);
                      } else {
                        await setter.setDefaultExpenseAccountId(
                            id == null ? null : int.parse(id));
                        ref.invalidate(defaultExpenseAccountIdProvider);
                      }
                      if (dialog.mounted) Navigator.pop(dialog);
                    })));
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

    if (context.mounted) showBeeToast(context, l10n.accountRestoredToast);
  }
}

part of '../../../pages/account/accounts_page.dart';

mixin _AccountsOverviewBindings on ConsumerState<AccountsPage> {
  Map<String, List<db.Account>>? get _reorderingGroups;
  Map<String, List<db.Account>> _groupAccounts(List<db.Account> accounts);
  void _onReorder(
      String type, List<db.Account> accounts, int oldIndex, int newIndex);

  Widget _buildAccountsBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  key: ValueKey('account-type-$type'),
                  type: type,
                  accounts: groupList,
                  primaryColor: primaryColor,
                  allStats: allStatsAsync.valueOrNull,
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
                accounts: accounts.where((a) => a.hidden).toList(),
                allStats: allStatsAsync.valueOrNull,
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
    final showComposition =
        (netWorthAsync.valueOrNull?.length ?? 1) <= 1 || multiCurrency;
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
                  height: 100,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)))),
          error: (_, __) => BeeStatus(
              label: l.commonError,
              tone: BeeTone.error,
              action: BeeButton(
                  label: l.helpCenterRetry,
                  onPressed: () =>
                      ref.invalidate(netWorthBreakdownByCurrencyProvider)))),
      const SizedBox(height: 12),
      BeeAssetChartSection<AssetTrendView>(
          title: view == AssetTrendView.trend
              ? l.netWorthTrendTitle
              : l.assetComposition,
          segments: showComposition
              ? [
                  BeeSegment(AssetTrendView.trend, l.netWorthTrendTitle),
                  BeeSegment(AssetTrendView.composition, l.assetComposition)
                ]
              : const [],
          selected: view,
          onSelected: (value) =>
              ref.read(assetTrendViewProvider.notifier).select(value),
          detailLabel: l.commonDetail,
          onDetails: view == AssetTrendView.trend
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NetWorthTrendPage()))
              : null,
          child: view == AssetTrendView.trend
              ? _buildNetWorthChartInline(context, ref)
              : composition.when(
                  skipLoadingOnReload: true,
                  data: (data) =>
                      AssetCompositionChart(data: data, embedded: true),
                  loading: () => const SizedBox(
                      height: 180,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, __) =>
                      BeeStatus(label: l.commonError, tone: BeeTone.error))),
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
    final multiCurrency = ref.watch(multiCurrencyActiveProvider);
    final converted = ref.watch(convertedNetWorthProvider).valueOrNull;
    final base = ref.watch(baseCurrencyProvider).toUpperCase();
    final useCompact = ref.watch(compactAmountProvider);
    final hidden = ref.watch(hideAmountsProvider);
    final isConverted = multiCurrency && converted != null;
    final singleCurrency = byCurrency.length <= 1;
    final values = byCurrency.values.firstOrNull ??
        (totalAssets: 0.0, totalLiabilities: 0.0, netWorth: 0.0);
    final soleCurrency = byCurrency.keys.firstOrNull ?? base;
    final balances = isConverted
        ? [
            BeeAssetAmount(
                _overviewAmount(converted.netWorth,
                    currency: base, showCurrency: true),
                approximate: true)
          ]
        : singleCurrency
            ? [
                BeeAssetAmount(
                    _overviewAmount(values.netWorth, currency: soleCurrency))
              ]
            : [
                for (final e in byCurrency.entries)
                  BeeAssetAmount(_overviewAmount(e.value.netWorth,
                      currency: e.key, showCurrency: true))
              ];
    final assets = isConverted
        ? [
            '≈ ${_overviewAmount(converted.totalAssets, currency: base, showCurrency: true)}'
          ]
        : singleCurrency
            ? [_overviewAmount(values.totalAssets, currency: soleCurrency)]
            : [
                for (final e in byCurrency.entries
                    .where((e) => e.value.totalAssets != 0))
                  _overviewAmount(e.value.totalAssets,
                      currency: e.key, showCurrency: true)
              ];
    final liabilities = isConverted
        ? [
            '≈ ${_overviewAmount(converted.totalLiabilities.abs(), currency: base, showCurrency: true)}'
          ]
        : singleCurrency
            ? [
                _overviewAmount(values.totalLiabilities.abs(),
                    currency: soleCurrency)
              ]
            : [
                for (final e in byCurrency.entries
                    .where((e) => e.value.totalLiabilities != 0))
                  _overviewAmount(e.value.totalLiabilities.abs(),
                      currency: e.key, showCurrency: true)
              ];
    return BeeAssetSummary(
        title: isConverted
            ? l.convertedNetWorth(base)
            : singleCurrency
                ? '${l.accountTotalBalance} · $soleCurrency'
                : l.accountTotalBalance,
        balances: balances,
        assetsLabel: l.totalAssets,
        assets: assets.isEmpty ? ['0'] : assets,
        liabilitiesLabel: l.totalLiabilities,
        liabilities: liabilities.isEmpty ? ['0'] : liabilities,
        hidden: hidden,
        privacyLabel: hidden ? l.v4AmountsShow : l.v4AmountsHide,
        onPrivacy: () => ref.read(hideAmountsProvider.notifier).state = !hidden,
        detailLabel: l.conversionDetailTitle,
        onDetails: isConverted
            ? () => _showNetWorthConversionDetail(
                context, ref, converted, byCurrency, base, useCompact)
            : null);
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
          key: ValueKey('account-type-$type'),
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

    if (context.mounted) showToast(context, l10n.accountRestoredToast);
  }
}

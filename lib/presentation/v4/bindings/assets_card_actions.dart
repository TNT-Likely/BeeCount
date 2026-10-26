part of '../../../pages/account/accounts_page.dart';

/// The redesign only adds read-only view choices. Settings, sort writes, account
/// editing and the detail routes keep their original App/Repository operations.
extension _AssetsCardActions on _AccountsOverviewBindings {
  Future<void> _scrollToAssetHidden() async {
    if (_assetLocatingHidden || !_assetListController.hasClients) return;
    _assetLocatingHidden = true;
    try {
      // The final section may not be mounted by ListView yet. Bring its end
      // into the viewport before resolving the key; lazy estimates can grow
      // once another group is laid out, so allow a few bounded frame updates.
      for (var attempt = 0;
          mounted &&
              _assetListController.hasClients &&
              _assetHiddenKey.currentContext == null &&
              attempt < 3;
          attempt++) {
        await _assetListController.animateTo(
            _assetListController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut);
        if (!mounted) return;
        await WidgetsBinding.instance.endOfFrame;
      }
      final target = _assetHiddenKey.currentContext;
      if (mounted && target != null && target.mounted) {
        await Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 220), alignment: .2);
      }
    } finally {
      _assetLocatingHidden = false;
    }
  }

  Future<void> _showAssetMore() async {
    final l = AppLocalizations.of(context);
    final accounts =
        ref.read(allAccountsStreamProvider).valueOrNull ?? const <db.Account>[];
    void next(BuildContext sheet, VoidCallback callback) {
      Navigator.pop(sheet);
      callback();
    }

    await showBeeSheet<void>(context,
        title: l.commonMore,
        child: SingleChildScrollView(
            child: Builder(
                builder: (sheet) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      BeeMenuRow(
                          title: l.accountAddTooltip,
                          leading: const BeeLineIcon('Plus'),
                          onTap: () => next(
                              sheet,
                              () => _addAccount(context, ref,
                                  ref.read(currentLedgerIdProvider)))),
                      BeeMenuRow(
                          title: l.commonSearch,
                          leading: const BeeLineIcon('Search'),
                          onTap: () =>
                              next(sheet, () => _showAssetSearch(accounts))),
                      BeeMenuRow(
                          title: l.v4AssetsOrder,
                          subtitle: l.v4AssetsOrderHint,
                          leading: const RotatedBox(
                              quarterTurns: 1,
                              child: BeeLineIcon('ArrowRightLeft')),
                          onTap: () =>
                              next(sheet, () => _showAssetOrder(accounts))),
                      BeeMenuRow(
                          title: l.commonSettings,
                          leading: const BeeLineIcon('Settings2'),
                          onTap: () => next(sheet, _showSettingsSheet)),
                      BeeMenuRow(
                          title: l.v4AssetsCurrencyView,
                          leading: const BeeLineIcon('RefreshCw'),
                          onTap: () => next(
                              sheet,
                              () => _showAssetCurrency(accounts
                                  .map((a) => a.currency)
                                  .toSet()
                                  .toList()))),
                      BeeMenuRow(
                          title: l.netWorthTrendTitle,
                          leading: const BeeLineIcon('ChartNoAxesCombined'),
                          onTap: () => next(
                              sheet,
                              () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NetWorthTrendPage())))),
                      BeeMenuRow(
                          title: l.assetAccounts,
                          subtitle: l.conversionDetailTitle,
                          leading: const BeeLineIcon('Wallet'),
                          onTap: () => next(
                              sheet, () => _showAssetGroupSubtotal(false))),
                      BeeMenuRow(
                          title: l.liabilityAccounts,
                          subtitle: l.conversionDetailTitle,
                          leading: const BeeLineIcon('CreditCard'),
                          onTap: () =>
                              next(sheet, () => _showAssetGroupSubtotal(true))),
                      BeeMenuRow(
                          title: l.accountHiddenSection,
                          subtitle: l.v4AssetsHiddenIncluded,
                          leading: const BeeLineIcon('EyeOff'),
                          onTap: () => next(sheet, _scrollToAssetHidden)),
                      const BeeAssetsHeaderEntryBinding(asMenuRow: true),
                    ]))));
  }

  Future<void> _showAssetCurrency(List<String> currencies) async {
    final l = AppLocalizations.of(context),
        base = ref.read(baseCurrencyProvider);
    await showBeeSheet<void>(context,
        title: l.v4AssetsCurrencyView,
        child: SingleChildScrollView(
            child: Builder(
                builder: (sheet) =>
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      BeeMenuRow(
                          title: l.v4AssetsUnifiedConversion,
                          subtitle: l.v4RecordingConvertedLabel(base),
                          leading: const BeeLineIcon('RefreshCw'),
                          trailing: !_assetOriginalCurrency
                              ? const BeeLineIcon('Check')
                              : null,
                          onTap: () {
                            _updateAssetView(
                                () => _assetOriginalCurrency = false);
                            Navigator.pop(sheet);
                          }),
                      BeeMenuRow(
                          title: l.v4AssetsByCurrency,
                          subtitle: l.v4AssetsSeparateCurrencyHint,
                          leading: const BeeLineIcon('Wallet'),
                          trailing: _assetOriginalCurrency
                              ? const BeeLineIcon('Check')
                              : null,
                          onTap: () {
                            _updateAssetView(() {
                              _assetOriginalCurrency = true;
                              if (!currencies.contains(_assetCurrency)) {
                                _assetCurrency = currencies.firstOrNull;
                              }
                            });
                            Navigator.pop(sheet);
                          }),
                      BeeMenuRow(
                          title: l.exchangeRatePageTitle,
                          subtitle: base,
                          leading: const BeeLineIcon('RefreshCw'),
                          onTap: () {
                            Navigator.pop(sheet);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const ExchangeRatePage()));
                          }),
                    ]))));
  }

  Future<void> _showAssetSearch(List<db.Account> accounts) async {
    final l = AppLocalizations.of(context);
    await showBeeDialog<void>(context,
        title: l.commonSearch,
        child: Builder(
            builder: (dialog) => BeeAccountPicker(
                    accounts: [
                      for (final a in accounts)
                        BeeAccountChoice(
                            id: '${a.id}',
                            name: a.name,
                            currency: a.currency,
                            detail:
                                '${getAccountTypeLabel(context, a.type)}${a.hidden ? ' · ${l.accountHiddenTag}' : ''}',
                            icon: AccountTypeIcon(type: a.type, size: 21))
                    ],
                    currency: ref.read(baseCurrencyProvider),
                    selected: null,
                    unsetLabel: l.commonCancel,
                    filterByCurrency: false,
                    searchLabel: l.commonSearch,
                    emptyLabel: l.widgetNoAccounts,
                    onSelected: (id) {
                      final account =
                          accounts.firstWhereOrNull((a) => '${a.id}' == id);
                      if (account == null) {
                        Navigator.pop(dialog);
                        return;
                      }
                      Navigator.pop(dialog);
                      _viewAccountDetail(context, ref, account);
                    })));
  }

  Future<void> _showAssetOrder(List<db.Account> accounts) async {
    final l = AppLocalizations.of(context);
    final groups = _groupAccounts(accounts);
    await showBeeSheet<void>(context,
        title: l.v4AssetsOrder,
        child: StatefulBuilder(
            builder: (sheet, update) => SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      Text(l.v4AssetsOrderHint,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)),
                      for (final type in [
                        ...accountTypeOrder,
                        ...groups.keys
                            .where((t) => !accountTypeOrder.contains(t))
                      ])
                        if (groups[type]?.isNotEmpty == true) ...[
                          Padding(
                              padding:
                                  const EdgeInsets.only(top: 16, bottom: 5),
                              child: Text(getAccountTypeLabel(context, type),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor))),
                          ReorderableListView.builder(
                              key: ValueKey('asset-sort-$type'),
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: groups[type]!.length,
                              itemBuilder: (context, index) {
                                final account = groups[type]![index];
                                return ListTile(
                                    key: ValueKey('asset-sort-${account.id}'),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(account.name,
                                        style: const TextStyle(fontSize: 13)),
                                    subtitle: Text(
                                        '${account.currency}${account.hidden ? ' · ${l.accountHiddenTag}' : ''}',
                                        style: const TextStyle(fontSize: 10)),
                                    trailing: ReorderableDragStartListener(
                                        index: index,
                                        child: Container(
                                            width: 40,
                                            height: 40,
                                            color: Colors.transparent,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.drag_handle,
                                                size: 18))));
                              },
                              onReorder: (oldIndex, newIndex) {
                                // Include hidden rows in the same original ordering domain;
                                // otherwise visible indices could reorder a hidden neighbour.
                                _onReorder(
                                    type, groups[type]!, oldIndex, newIndex);
                                update(() {
                                  if (oldIndex < newIndex) newIndex--;
                                  final item = groups[type]!.removeAt(oldIndex);
                                  groups[type]!.insert(newIndex, item);
                                });
                              })
                        ]
                    ]))));
  }

  void _showAssetGroupSubtotal(bool liability) {
    final l = AppLocalizations.of(context),
        base = ref.read(baseCurrencyProvider).toUpperCase();
    final accounts =
        ref.read(allAccountsStreamProvider).valueOrNull ?? const <db.Account>[];
    final stats = ref.read(allAccountStatsProvider).valueOrNull;
    final included = liability ? liabilityTypeOrder : assetTypeOrder;
    final amounts = <String, double>{};
    for (final a
        in accounts.where((a) => !a.hidden && included.contains(a.type))) {
      amounts.update(a.currency, (v) => v + (stats?[a.id]?.balance ?? 0),
          ifAbsent: () => stats?[a.id]?.balance ?? 0);
    }
    final result = convertAmountsToBase(
        amounts: amounts,
        rates: ref.read(effectiveRatesProvider).valueOrNull ?? const {},
        base: base);
    _showGroupConversionDetail(context, ref,
        groupTitle: liability ? l.liabilityAccounts : l.assetAccounts,
        subtotalByCurrency: amounts,
        result: result,
        baseSymbol: getCurrencySymbol(base),
        base: base,
        useCompact: ref.read(compactAmountProvider));
  }
}

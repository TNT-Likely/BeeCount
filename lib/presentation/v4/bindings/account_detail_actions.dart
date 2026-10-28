part of '../../../pages/account/account_detail_page.dart';

mixin _AccountDetailActions on ConsumerState<AccountDetailPage> {
  AccountDetailController get c;
  set _point(int? value);
  bool _accountActionBusy = false;
  Future<void> _perform(Future<void> Function() action) async {
    if (_accountActionBusy) return;
    _accountActionBusy = true;
    try {
      await action();
    } catch (error) {
      if (mounted) {
        showBeeToast(
            context, '${AppLocalizations.of(context).commonError}: $error',
            tone: BeeTone.error);
      }
    } finally {
      _accountActionBusy = false;
    }
  }

  void _refresh() {
    ref.invalidate(accountStatsProvider(c.account.id));
    ref.invalidate(accountCategoryStatsProvider);
    ref.invalidate(accountPeriodCategoryStatsProvider);
    ref.invalidate(accountDetailReferencesProvider);
    ref.invalidate(accountRowMetadataProvider);
    unawaited(c.refresh());
  }

  Future<void> _edit() async {
    final ledger = ref.read(currentLedgerProvider).valueOrNull;
    if (ledger == null || c.account.id < 0) return;
    final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AccountEditPage(account: c.account, ledgerId: ledger.id)));
    if (changed == true && mounted) _refresh();
  }

  Future<void> _transfer() async {
    final a = c.account;
    if (a.hidden || a.id < 0) return;
    final candidates = (await ref
            .read(repositoryProvider)
            .getAccountsByCurrency(a.currency))
        .where((x) => x.id != a.id && !x.hidden && !isValuationOnlyType(x.type))
        .toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      final l = AppLocalizations.of(context);
      final add = await showBeeSheet<bool>(context,
          title: l.transferTitle,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.v4AccountNoPeer),
            const SizedBox(height: 12),
            BeeButton(
                label: l.accountAddButton,
                onPressed: () => Navigator.pop(context, true))
          ]));
      if (add == true && mounted) {
        final ledger = ref.read(currentLedgerIdProvider);
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AccountEditPage(ledgerId: ledger)));
        if (mounted) _refresh();
      }
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
                initialKind: 'transfer',
                initialAccountId: a.type == 'credit_card' ? null : a.id,
                initialToAccountId: a.type == 'credit_card' ? a.id : null,
                initialCurrencyCode: a.currency,
                quickAdd: true)));
    if (mounted) _refresh();
  }

  Future<void> _record() async {
    if (c.account.hidden || c.account.id < 0) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionEditorPage(
                initialKind: 'expense',
                initialAccountId: c.account.id,
                initialCurrencyCode: c.account.currency)));
    if (mounted) _refresh();
  }

  Future<void> _value() async {
    final value = await showAccountValuationDialog(context, c.account);
    if (value == null || !mounted) return;
    try {
      await ref.read(repositoryProvider).updateAccountValuation(
          c.account.id, isLiabilityType(c.account.type) ? -value.abs() : value);
      ref.read(statsRefreshProvider.notifier).state++;
      if (mounted) {
        showBeeToast(context, AppLocalizations.of(context).commonSave,
            tone: BeeTone.success);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        showBeeToast(context, '${AppLocalizations.of(context).commonError}: $e',
            tone: BeeTone.error);
      }
    }
  }

  Future<void> _period() async {
    final result = await showResourcePeriodPicker(context,
        period: c.period, anchor: c.anchor);
    if (result != null && mounted) {
      setState(() => _point = null);
      await c.choosePeriod(result.period, date: result.anchor);
    }
  }

  Future<void> _search() async {
    final text = TextEditingController(text: c.query),
        l = AppLocalizations.of(context);
    final result = await showBeeSheet<String>(context,
        title: l.searchTitle,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: text,
              autofocus: true,
              decoration: InputDecoration(hintText: l.searchTitle),
              onSubmitted: (value) => Navigator.pop(context, value)),
          const SizedBox(height: 12),
          BeeButton(
              label: l.commonConfirm,
              onPressed: () => Navigator.pop(context, text.text))
        ]));
    text.dispose();
    if (result != null && mounted) {
      await c.filter(direction: c.flow, text: result.trim(), order: c.sort);
    }
  }

  Future<void> _filter() async {
    final l = AppLocalizations.of(context);
    var flow = c.flow ?? 'all', sort = c.sort;
    final apply = await showBeeSheet<bool>(context,
        title: l.accountAllFlows,
        child: StatefulBuilder(
            builder: (context, update) => BeeAccountFlowFilter(
                flow: flow,
                sort: sort,
                sortLabel: l.categoryDetailSortTitle,
                flows: [
                  BeeSegment('all', l.accountAllFlows),
                  BeeSegment('expense', l.accountOutflows),
                  BeeSegment('income', l.accountInflows)
                ],
                sorts: [
                  BeeSegment('timeDesc', l.categoryDetailSortTimeDesc),
                  BeeSegment('timeAsc', l.categoryDetailSortTimeAsc),
                  BeeSegment('amountDesc', l.categoryDetailSortAmountDesc),
                  BeeSegment('amountAsc', l.categoryDetailSortAmountAsc)
                ],
                onFlowChanged: (v) => update(() => flow = v),
                onSortChanged: (v) => update(() => sort = v),
                confirmLabel: l.commonConfirm,
                onConfirm: () => Navigator.pop(context, true))));
    if (apply == true && mounted) {
      await c.filter(
          direction: flow == 'all' ? null : flow, text: c.query, order: sort);
    }
  }

  Future<void> _ledgers() async {
    final id = await showBeeSheet<int>(context,
        title: AppLocalizations.of(context).v4AccountLinkedBooks,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final book
              in c.ledgers.where((book) => c.usage.containsKey(book.id)))
            BeeMenuRow(
                title: book.name,
                subtitle: '${c.usage[book.id]}',
                leading: const BeeLineIcon('BookOpen'),
                onTap: () => Navigator.pop(context, book.id)),
          if (c.usage.isEmpty) Text(AppLocalizations.of(context).commonEmpty)
        ]));
    if (id != null && mounted) {
      final name = c.ledgers.firstWhere((book) => book.id == id).name;
      await c.filter(direction: null, text: name, order: c.sort);
    }
  }

  Future<void> _info() async {
    final l = AppLocalizations.of(context);
    await showBeeSheet<void>(context,
        title: l.accountMetaInfo,
        child: Text(
            '${c.account.name}\n${getAccountTypeLabel(context, c.account.type)} · ${c.account.currency}\n${l.v4AssetsHiddenIncluded}'));
  }

  Future<void> _distribution() async {
    var kind = 'expense';
    await showBeeSheet<void>(context,
        title: AppLocalizations.of(context).accountCategoryBreakdown,
        child: StatefulBuilder(
            builder: (context, update) => SingleChildScrollView(
                child: AccountDetailDistribution(
                    accountId: c.account.id,
                    credit: c.account.type == 'credit_card',
                    value: kind,
                    startDate: c.start,
                    endExclusive: c.endExclusive,
                    onChanged: (value) => update(() => kind = value)))));
  }

  Future<void> _toggleHidden() async {
    final a = c.account,
        l = AppLocalizations.of(context),
        repo = ref.read(repositoryProvider);
    if (a.id < 0) return;
    if (!a.hidden) {
      final recurring = await repo.getActiveRecurringCountByAccount(a.id);
      if (!mounted) return;
      final ok = await showBeeConfirm(context,
          title: l.accountHideConfirmTitle,
          message: recurring > 0
              ? '${l.accountHideConfirmBody}\n${l.accountHideRecurringWarn(recurring)}'
              : l.accountHideConfirmBody,
          confirmLabel: l.accountHide,
          cancelLabel: l.commonCancel);
      if (!ok || !mounted) return;
    }
    await repo.setAccountHidden(a.id, !a.hidden);
    if (!a.hidden) {
      final setter = ref.read(defaultAccountSetterProvider);
      if (await ref.read(defaultIncomeAccountIdProvider.future) == a.id) {
        await setter.setDefaultIncomeAccountId(null);
        ref.invalidate(defaultIncomeAccountIdProvider);
      }
      if (await ref.read(defaultExpenseAccountIdProvider.future) == a.id) {
        await setter.setDefaultExpenseAccountId(null);
        ref.invalidate(defaultExpenseAccountIdProvider);
      }
    }
    if (mounted) {
      PostProcessor.sync(ref, ledgerId: ref.read(currentLedgerIdProvider));
      ref.read(statsRefreshProvider.notifier).state++;
      _refresh();
    }
  }

  Future<void> _delete() async {
    if (c.account.id < 0) return;
    final l = AppLocalizations.of(context), repo = ref.read(repositoryProvider);
    final count = await repo.getTransactionCountByAccount(c.account.id);
    if (!mounted) return;
    final ok = await showBeeConfirm(context,
        title: count > 0 ? l.accountDeleteWarningTitle : l.commonConfirm,
        message: count > 0
            ? l.accountDeleteWarningMessage(count)
            : l.accountDeleteConfirm,
        confirmLabel: l.commonDelete,
        cancelLabel: l.commonCancel,
        danger: true);
    if (ok && mounted) {
      await repo.deleteAccount(c.account.id);
      if (mounted) {
        PostProcessor.sync(ref, ledgerId: ref.read(currentLedgerIdProvider));
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _menu() async {
    final l = AppLocalizations.of(context);
    final action = await showBeeSheet<String>(context,
        title: l.v4AccountActions,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (c.account.id >= 0)
            BeeMenuRow(
                title: l.accountEditTitle,
                leading: const BeeLineIcon('PencilLine'),
                onTap: () => Navigator.pop(context, 'edit')),
          if (!isValuationOnlyType(c.account.type))
            BeeMenuRow(
                title: l.searchTitle,
                leading: const BeeLineIcon('Search'),
                onTap: () => Navigator.pop(context, 'search')),
          BeeMenuRow(
              title: l.v4AccountLinkedBooks,
              leading: const BeeLineIcon('BookOpen'),
              onTap: () => Navigator.pop(context, 'ledgers')),
          if (c.account.id >= 0) ...[
            BeeMenuRow(
                title: c.account.hidden ? l.accountRestore : l.accountHide,
                leading: const BeeLineIcon('EyeOff'),
                onTap: () => Navigator.pop(context, 'hide')),
            BeeMenuRow(
                title: l.commonDelete,
                leading: const BeeLineIcon('Trash2'),
                onTap: () => Navigator.pop(context, 'delete'))
          ]
        ]));
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _edit();
      case 'search':
        await _search();
      case 'ledgers':
        await _ledgers();
      case 'hide':
        await _toggleHidden();
      case 'delete':
        await _delete();
    }
  }
}

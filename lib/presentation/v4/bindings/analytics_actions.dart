part of '../../../pages/main/analytics_page.dart';

mixin _AnalyticsActions on ConsumerState<AnalyticsPage> {
  String _scope = 'month', _type = 'expense';
  Object? _queryKey;
  Future<Map<String, AnalyticsResult>>? _query;

  void _selectType(String value) => setState(() => _type = value);

  DateTime get _latestPeriod =>
      labelForDate(DateTime.now(), ref.read(currentMonthStartDayProvider));

  bool get _canGoNext {
    final selected = ref.read(selectedMonthProvider), latest = _latestPeriod;
    return _scope == 'month'
        ? DateTime(selected.year, selected.month).isBefore(latest)
        : _scope == 'year' && selected.year < latest.year;
  }

  Future<void> _showPeriodPicker() async {
    final selected = ref.read(selectedMonthProvider), latest = _latestPeriod;
    final result = await showWheelDatePicker(context,
        initial: selected,
        mode: _scope == 'year' ? WheelDatePickerMode.y : WheelDatePickerMode.ym,
        maxDate: latest);
    if (result != null && mounted) {
      ref.read(selectedMonthProvider.notifier).state =
          DateTime(result.year, _scope == 'year' ? 1 : result.month, 1);
    }
  }

  void _movePeriod(int delta) {
    if (_scope == 'all' || (delta > 0 && !_canGoNext)) return;
    final selected = ref.read(selectedMonthProvider);
    ref.read(selectedMonthProvider.notifier).state = _scope == 'year'
        ? DateTime(selected.year + delta, 1)
        : DateTime(selected.year, selected.month + delta);
  }

  Future<void> _runRecalcForeignTx(int count) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => BeeDialog(
                title: Text(l.recalcForeignTxAction),
                content: Text(l.recalcSyncCountHint(count)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l.commonConfirm))
                ]));
    if (confirmed != true || !mounted) return;
    final repo = ref.read(repositoryProvider),
        id = ref.read(currentLedgerIdProvider);
    final foreign = await repo.getLedgerForeignCurrencies(id);
    await refreshExchangeRatesFromUi(ref, force: true, extraQuotes: foreign);
    final n = await repo.recomputeForeignTxForLedger(id);
    if (!mounted) return;
    showToast(context, l.recalcForeignTxDone(n));
    ref.read(statsRefreshProvider.notifier).state++;
  }

  Future<void> _share() async {
    final l = AppLocalizations.of(context),
        id = ref.read(currentLedgerIdProvider),
        month = ref.read(selectedMonthProvider);
    if (id == 0) {
      showToast(context, l.sharePosterNoLedger);
      return;
    }
    try {
      await SharePosterService.showDynamicPosterPreview(context, ref,
          type: _scope == 'month'
              ? 'month'
              : _scope == 'year'
                  ? 'year'
                  : 'ledger',
          ledgerId: id,
          year: _scope == 'all' ? null : month.year,
          month: _scope == 'month' ? month.month : null);
    } catch (e) {
      if (mounted) showToast(context, '${l.commonError}: $e');
    }
  }
}

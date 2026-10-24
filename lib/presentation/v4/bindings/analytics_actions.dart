part of '../../../pages/main/analytics_page.dart';

mixin _AnalyticsActions on ConsumerState<AnalyticsPage> {
  String _scope = 'month', _type = 'expense';
  bool _chartSwiped = false,
      _localHeaderDismissed = false,
      _localChartDismissed = false,
      _showPieChart = false;
  Object? _queryKey;
  Future<AnalyticsResult>? _query;
  // 显示周期选择器
  void _showPeriodPicker() async {
    final selMonth = ref.read(selectedMonthProvider);
    if (_scope == 'month') {
      final res = await showWheelDatePicker(
        context,
        initial: selMonth,
        mode: WheelDatePickerMode.ym,
        maxDate: DateTime.now(),
      );
      final picked = res == null ? null : DateTime(res.year, res.month, 1);
      if (picked != null && mounted) {
        ref.read(selectedMonthProvider.notifier).state = picked;
      }
    } else if (_scope == 'year') {
      final res = await showWheelDatePicker(
        context,
        initial: selMonth,
        mode: WheelDatePickerMode.y,
        maxDate: DateTime.now(),
      );
      if (res != null && mounted) {
        ref.read(selectedMonthProvider.notifier).state =
            DateTime(res.year, 1, 1);
      }
    }
    // all视角不显示选择器
  }

  // 循环切换类型（用于滑动）：expense -> income -> balance -> expense
  void _cycleTypeForward() {
    setState(() {
      if (_type == 'expense') {
        _type = 'income';
      } else if (_type == 'income') {
        _type = 'balance';
      } else {
        _type = 'expense';
      }
    });
  }

  void _cycleTypeBackward() {
    setState(() {
      if (_type == 'expense') {
        _type = 'balance';
      } else if (_type == 'balance') {
        _type = 'income';
      } else {
        _type = 'expense';
      }
    });
  }

  // 根据scope切换周期（用于图表滑动）
  void _onChartSwipeLeft() {
    final selMonth = ref.read(selectedMonthProvider);
    final now = DateTime.now();
    setState(() {
      if (_scope == 'month') {
        // 月视角：切换到下一个月（不能超过当前月）
        final nextMonth = DateTime(selMonth.year, selMonth.month + 1, 1);
        if (nextMonth.year < now.year ||
            (nextMonth.year == now.year && nextMonth.month <= now.month)) {
          ref.read(selectedMonthProvider.notifier).state = nextMonth;
        }
      } else if (_scope == 'year') {
        // 年视角：切换到下一年（不能超过当前年）
        final nextYear = DateTime(selMonth.year + 1, 1, 1);
        if (nextYear.year <= now.year) {
          ref.read(selectedMonthProvider.notifier).state = nextYear;
        }
      }
      // all视角：不做任何操作
    });
  }

  void _onChartSwipeRight() {
    final selMonth = ref.read(selectedMonthProvider);
    setState(() {
      if (_scope == 'month') {
        // 月视角：切换到上一个月
        final prevMonth = DateTime(selMonth.year, selMonth.month - 1, 1);
        ref.read(selectedMonthProvider.notifier).state = prevMonth;
      } else if (_scope == 'year') {
        // 年视角：切换到上一年
        final prevYear = DateTime(selMonth.year - 1, 1, 1);
        ref.read(selectedMonthProvider.notifier).state = prevYear;
      }
      // all视角：不做任何操作
    });
  }

  String _viewLabel(AppLocalizations l) => _type == 'expense'
      ? l.homeExpense
      : _type == 'income'
          ? l.homeIncome
          : l.homeBalance;
  Future<void> _showTypeMenu() async {
    final l = AppLocalizations.of(context);
    final value = await showDialog<String>(
        context: context,
        builder: (ctx) => BeeDialog(
            title: Text(l.v4AnalyticsView),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (key, label) in [
                ('expense', l.homeExpense),
                ('income', l.homeIncome),
                ('balance', l.homeBalance)
              ])
                RadioListTile<String>(
                    value: key,
                    groupValue: _type,
                    title: Text(label),
                    onChanged: (v) => Navigator.pop(ctx, v))
            ])));
    if (value != null && mounted) setState(() => _type = value);
  }

  Future<void> _dismissHint(bool chart) async {
    final setter = ref.read(analyticsHintsSetterProvider);
    if (chart) {
      await setter.dismissChart();
    } else {
      await setter.dismissHeader();
    }
    if (mounted) {
      setState(() {
        if (chart) {
          _localChartDismissed = true;
        } else {
          _localHeaderDismissed = true;
        }
      });
    }
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

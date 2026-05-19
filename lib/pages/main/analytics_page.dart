import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// wheel_date_picker exported via ui barrel
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/charts/line_chart.dart';
import '../../widgets/charts/category_pie_chart.dart';
import '../../widgets/analytics/analytics_summary.dart';
import '../../widgets/analytics/category_rank_row.dart';
import '../../widgets/ui/capsule_switcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_service.dart';
import '../../data/db.dart' as db;

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  String _scope = 'month'; // month | year | all
  String _type = 'expense'; // expense | income | balance
  bool _chartSwiped = false; // 吸收图表区域横滑，避免父级切换收入/支出
  bool _localHeaderDismissed = false; // 本地快速隐藏，实际持久化在 provider 中
  bool _localChartDismissed = false;
  bool _showPieChart = false; // 切换饼图/排行榜

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
      if (picked != null) {
        ref.read(selectedMonthProvider.notifier).state = picked;
      }
    } else if (_scope == 'year') {
      final res = await showWheelDatePicker(
        context,
        initial: selMonth,
        mode: WheelDatePickerMode.y,
        maxDate: DateTime.now(),
      );
      if (res != null) {
        ref.read(selectedMonthProvider.notifier).state =
            DateTime(res.year, 1, 1);
      }
    }
    // all视角不显示选择器
  }

  // 显示类型选择菜单
  void _showTypeMenu() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('选择视角'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'expense'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: _type == 'expense'
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.homeExpense,
                    style: TextStyle(
                      fontWeight: _type == 'expense' ? FontWeight.bold : null,
                      color: _type == 'expense'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'income'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: _type == 'income'
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.homeIncome,
                    style: TextStyle(
                      fontWeight: _type == 'income' ? FontWeight.bold : null,
                      color: _type == 'income'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'balance'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.balance,
                    color: _type == 'balance'
                        ? Theme.of(context).primaryColor
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.homeBalance,
                    style: TextStyle(
                      fontWeight: _type == 'balance' ? FontWeight.bold : null,
                      color: _type == 'balance'
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _type = result;
      });
    }
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

  // 计算结余序列（收入 - 支出）
  dynamic _calculateBalanceSeries(dynamic incomeData, dynamic expenseData) {
    if (incomeData is List<({DateTime day, double total})> &&
        expenseData is List<({DateTime day, double total})>) {
      final Map<DateTime, double> incomeMap = {
        for (var e in incomeData) e.day: e.total
      };
      final Map<DateTime, double> expenseMap = {
        for (var e in expenseData) e.day: e.total
      };
      final allDays = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
      return allDays.map((day) {
        final income = incomeMap[day] ?? 0.0;
        final expense = expenseMap[day] ?? 0.0;
        return (day: day, total: income - expense);
      }).toList();
    }
    if (incomeData is List<({DateTime month, double total})> &&
        expenseData is List<({DateTime month, double total})>) {
      final Map<DateTime, double> incomeMap = {
        for (var e in incomeData) e.month: e.total
      };
      final Map<DateTime, double> expenseMap = {
        for (var e in expenseData) e.month: e.total
      };
      final allMonths = {...incomeMap.keys, ...expenseMap.keys}.toList()
        ..sort();
      return allMonths.map((month) {
        final income = incomeMap[month] ?? 0.0;
        final expense = expenseMap[month] ?? 0.0;
        return (month: month, total: income - expense);
      }).toList();
    }
    if (incomeData is List<({int year, double total})> &&
        expenseData is List<({int year, double total})>) {
      final Map<int, double> incomeMap = {
        for (var e in incomeData) e.year: e.total
      };
      final Map<int, double> expenseMap = {
        for (var e in expenseData) e.year: e.total
      };
      final allYears = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
      return allYears.map((year) {
        final income = incomeMap[year] ?? 0.0;
        final expense = expenseMap[year] ?? 0.0;
        return (year: year, total: income - expense);
      }).toList();
    }
    return [];
  }

  // 从序列数据中计算总和
  double _getSumFromSeries(dynamic seriesData) {
    if (seriesData is List<({DateTime day, double total})>) {
      return seriesData.fold<double>(0, (sum, e) => sum + e.total);
    }
    if (seriesData is List<({DateTime month, double total})>) {
      return seriesData.fold<double>(0, (sum, e) => sum + e.total);
    }
    if (seriesData is List<({int year, double total})>) {
      return seriesData.fold<double>(0, (sum, e) => sum + e.total);
    }
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final selMonth = ref.watch(selectedMonthProvider);
    // 统计刷新 tick：当有新增/编辑/删除时我们会 +1，这里监听以触发重建和重新拉取
    ref.watch(statsRefreshProvider);

    // 时间范围
    late DateTime start;
    late DateTime end;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_scope == 'month') {
      start = DateTime(selMonth.year, selMonth.month, 1);
      final monthEnd = DateTime(selMonth.year, selMonth.month + 1, 1);
      // 当前月份：只到今天；历史月份：到月末
      final isCurrentMonth =
          selMonth.year == now.year && selMonth.month == now.month;
      end = isCurrentMonth ? today.add(const Duration(days: 1)) : monthEnd;
    } else if (_scope == 'year') {
      start = DateTime(selMonth.year, 1, 1);
      final yearEnd = DateTime(selMonth.year + 1, 1, 1);
      // 当前年份：只到今天；历史年份：到年末
      final isCurrentYear = selMonth.year == now.year;
      end = isCurrentYear ? today.add(const Duration(days: 1)) : yearEnd;
    } else {
      start = DateTime(1970, 1, 1);
      end = today.add(const Duration(days: 1));
    }

    // 按视角获取序列
    Future<dynamic> seriesFuture;
    Future<dynamic>? incomeSeriesFuture;
    Future<dynamic>? expenseSeriesFuture;

    if (_type == 'balance') {
      // 结余模式：同时获取收入和支出数据
      if (_scope == 'month') {
        incomeSeriesFuture = repo.totalsByDay(
            ledgerId: ledgerId, type: 'income', start: start, end: end);
        expenseSeriesFuture = repo.totalsByDay(
            ledgerId: ledgerId, type: 'expense', start: start, end: end);
        seriesFuture = Future.value([]); // 占位
      } else if (_scope == 'year') {
        incomeSeriesFuture = repo.totalsByMonth(
            ledgerId: ledgerId, type: 'income', year: selMonth.year);
        expenseSeriesFuture = repo.totalsByMonth(
            ledgerId: ledgerId, type: 'expense', year: selMonth.year);
        seriesFuture = Future.value([]);
      } else {
        incomeSeriesFuture =
            repo.totalsByYearSeries(ledgerId: ledgerId, type: 'income');
        expenseSeriesFuture =
            repo.totalsByYearSeries(ledgerId: ledgerId, type: 'expense');
        seriesFuture = Future.value([]);
      }
    } else {
      // 收入或支出模式
      seriesFuture = _scope == 'month'
          ? repo.totalsByDay(
              ledgerId: ledgerId, type: _type, start: start, end: end)
          : _scope == 'year'
              ? repo.totalsByMonth(
                  ledgerId: ledgerId, type: _type, year: selMonth.year)
              : repo.totalsByYearSeries(ledgerId: ledgerId, type: _type);
    }

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: _currentPeriodLabel(_scope, selMonth, context),
            leadingIcon: Icons.bar_chart_outlined,
            leadingPlain: true,
            compact: true,
            showTitleSection: false,
            content: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.bar_chart_outlined,
                      color: BeeTokens.textPrimary(context)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _scope != 'all' ? _showPeriodPicker : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentPeriodLabel(_scope, selMonth, context),
                          style: BeeTextTokens.title(context),
                        ),
                        if (_scope != 'all')
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: BeeTokens.textPrimary(context),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _showTypeMenu,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _type == 'expense'
                              ? AppLocalizations.of(context).homeExpense
                              : _type == 'income'
                                  ? AppLocalizations.of(context).homeIncome
                                  : AppLocalizations.of(context).homeBalance,
                          style: BeeTextTokens.title(context),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: BeeTokens.textPrimary(context),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // 分享按钮
                  IconButton(
                    icon: Icon(Icons.share,
                        color: BeeTokens.textPrimary(context)),
                    onPressed: () async {
                      final ledgerId = ref.read(currentLedgerIdProvider);
                      if (ledgerId == 0) {
                        showToast(context, AppLocalizations.of(context).sharePosterNoLedger);
                        return;
                      }

                      // 显示加载对话框（与轮播海报预览样式统一）
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        barrierColor: Colors.black.withValues(alpha: 0.3),
                        builder: (ctx) => PopScope(
                          canPop: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  AppLocalizations.of(context).mineShareGenerating,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      try {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // 关闭加载对话框

                          // 使用动态预览对话框（支持隐藏收入）
                          if (_scope == 'month') {
                            await SharePosterService.showDynamicPosterPreview(
                              context,
                              ref,
                              type: 'month',
                              ledgerId: ledgerId,
                              year: selMonth.year,
                              month: selMonth.month,
                            );
                          } else if (_scope == 'year') {
                            await SharePosterService.showDynamicPosterPreview(
                              context,
                              ref,
                              type: 'year',
                              ledgerId: ledgerId,
                              year: selMonth.year,
                            );
                          } else {
                            await SharePosterService.showDynamicPosterPreview(
                              context,
                              ref,
                              type: 'ledger',
                              ledgerId: ledgerId,
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.of(context).pop(); // 关闭加载对话框
                          showToast(context,
                              '${AppLocalizations.of(context).commonError}: $e');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            padding: EdgeInsets.zero,
            bottom: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: CapsuleSwitcher<String>(
                selectedValue: _scope,
                options: [
                  CapsuleOption(
                    value: 'month',
                    label: AppLocalizations.of(context).analyticsMonth,
                  ),
                  CapsuleOption(
                    value: 'year',
                    label: AppLocalizations.of(context).analyticsYear,
                  ),
                  CapsuleOption(
                    value: 'all',
                    label: AppLocalizations.of(context).analyticsAll,
                  ),
                ],
                onChanged: (value) => setState(() => _scope = value),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder(
              key: ValueKey('analytics_$_type'),
              future: _type == 'balance'
                  ? _loadBalanceData(repo, ledgerId, start, end, seriesFuture,
                      incomeSeriesFuture!, expenseSeriesFuture!)
                  : _loadCategoryData(
                      repo, ledgerId, _type, start, end, seriesFuture),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data as List<dynamic>;

                // 在balance模式下，需要计算结余数据
                dynamic seriesRaw;
                List<({int? id, String name, db.Category? category, double total, List<({int id, db.Category category, String name, double total})> subCategories})>
                    catData;
                int txCount;
                double sum;

                if (_type == 'balance') {
                  // balance模式：list[3]是收入数据，list[4]是支出数据，list[5]是收入交易数量
                  final incomeData = list[3];
                  final expenseData = list[4];

                  // 计算结余序列
                  seriesRaw = _calculateBalanceSeries(incomeData, expenseData);

                  // 分类数据显示支出分类（但结余模式下不显示排行榜）
                  catData = list[0] as List<
                      ({int? id, String name, db.Category? category, double total, List<({int id, db.Category category, String name, double total})> subCategories})>;

                  // 获取收入和支出的交易数量
                  final expenseCount = list[2] as int;
                  final incomeCount = list[5] as int;
                  txCount = expenseCount + incomeCount;

                  // 计算总结余（收入总额 - 支出总额）
                  final incomeSum = _getSumFromSeries(incomeData);
                  final expenseSum = _getSumFromSeries(expenseData);
                  sum = incomeSum - expenseSum;
                } else {
                  catData = list[0] as List<
                      ({int? id, String name, db.Category? category, double total, List<({int id, db.Category category, String name, double total})> subCategories})>;
                  seriesRaw = list[1];
                  txCount = list[2] as int;
                  sum = catData.fold<double>(0, (a, b) => a + b.total);
                }

                // 统一取数列的数值数组
                List<double> valuesOnly() {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  if (seriesRaw is List<({int year, double total})>) {
                    return seriesRaw.map((e) => e.total).toList();
                  }
                  return const <double>[];
                }

                final vals = valuesOnly();
                final allZero = vals.isEmpty || vals.every((v) => v == 0);
                if (txCount == 0 || (sum == 0 && allZero)) {
                  final headerDismissed = (ref
                              .watch(analyticsHeaderHintDismissedProvider)
                              .asData
                              ?.value ??
                          false) ||
                      _localHeaderDismissed;
                  return GestureDetector(
                    onHorizontalDragEnd: (details) {
                      // 左右滑动切换周期（月份/年份）
                      if (details.primaryVelocity! > 0) {
                        _onChartSwipeRight(); // 向右滑动 -> 上一个周期
                      } else {
                        _onChartSwipeLeft(); // 向左滑动 -> 下一个周期
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        AppEmpty(
                          text: AppLocalizations.of(context).commonEmpty,
                          subtext: AppLocalizations.of(context)
                              .analyticsNoDataSubtext,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.center,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.swap_horiz),
                            label: Text(AppLocalizations.of(context)
                                .analyticsSwitchTo(_type == "expense"
                                    ? AppLocalizations.of(context).homeIncome
                                    : _type == "income"
                                        ? AppLocalizations.of(context)
                                            .homeBalance
                                        : AppLocalizations.of(context)
                                            .homeExpense)),
                            onPressed: _cycleTypeForward,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!headerDismissed)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14,
                                  color: BeeTokens.textSecondary(context)),
                              const SizedBox(width: 6),
                              Text(
                                  AppLocalizations.of(context)
                                      .analyticsTipHeader,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: BeeTokens.textSecondary(
                                              context))),
                            ],
                          ),
                      ],
                    ),
                  );
                }

                // 注意：sum 非 0 或曲线存在非零值则继续渲染

                // 过滤数据：只显示到当前时间的数据
                final filteredSeriesRaw = () {
                  if (seriesRaw is List<({DateTime day, double total})>) {
                    // 天数据：已经通过时间范围过滤了
                    return seriesRaw;
                  }
                  if (seriesRaw is List<({DateTime month, double total})>) {
                    // 月数据：过滤到当前月份
                    final isCurrentYear = selMonth.year == now.year;
                    if (isCurrentYear) {
                      return seriesRaw
                          .where((e) => e.month.month <= now.month)
                          .toList();
                    }
                    return seriesRaw;
                  }
                  if (seriesRaw is List<({int year, double total})>) {
                    // 年数据：过滤到当前年份
                    return seriesRaw.where((e) => e.year <= now.year).toList();
                  }
                  return seriesRaw;
                }();

                // 转换为折线值数组 + x 轴标签
                final values = () {
                  if (filteredSeriesRaw
                      is List<({DateTime day, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  if (filteredSeriesRaw
                      is List<({DateTime month, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  if (filteredSeriesRaw is List<({int year, double total})>) {
                    return filteredSeriesRaw.map((e) => e.total).toList();
                  }
                  return const <double>[];
                }();

                final xLabels = () {
                  if (filteredSeriesRaw
                      is List<({DateTime day, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => e.day.day.toString())
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw
                      is List<({DateTime month, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => AppLocalizations.of(context).homeMonth(
                            e.month.month.toString().padLeft(2, '0')))
                        .toList(growable: false);
                  }
                  if (filteredSeriesRaw is List<({int year, double total})>) {
                    return filteredSeriesRaw
                        .map((e) => e.year.toString())
                        .toList(growable: false);
                  }
                  return const <String>[];
                }();

                int? highlightIndex;
                if (_scope == 'month' &&
                    filteredSeriesRaw is List<({DateTime day, double total})>) {
                  final today = DateTime.now();
                  if (today.year == selMonth.year &&
                      today.month == selMonth.month) {
                    highlightIndex = today.day - 1; // 从 0 开始
                    if (highlightIndex >= 0 &&
                        highlightIndex < xLabels.length) {
                      xLabels[highlightIndex] =
                          AppLocalizations.of(context).analyticsToday;
                    }
                  }
                }

                // 提示是否已被持久化关闭
                final headerDismissed = (ref
                            .watch(analyticsHeaderHintDismissedProvider)
                            .asData
                            ?.value ??
                        false) ||
                    _localHeaderDismissed;
                final chartDismissed = (ref
                            .watch(analyticsChartHintDismissedProvider)
                            .asData
                            ?.value ??
                        false) ||
                    _localChartDismissed;
                final hide = ref.watch(hideAmountsProvider);

                return GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (_chartSwiped) {
                      setState(() => _chartSwiped = false);
                      return;
                    }
                    // 左右滑动切换类型
                    if (details.primaryVelocity! > 0) {
                      _cycleTypeBackward();
                    } else {
                      _cycleTypeForward();
                    }
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AnalyticsSummary(
                        scope: _scope,
                        isExpense: _type == 'expense',
                        isBalance: _type == 'balance',
                        total: sum,
                        avg: _computeAverage(filteredSeriesRaw, _scope),
                        expenseColor: Theme.of(context).colorScheme.primary,
                        incomeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: LineChart(
                          values: values,
                          xLabels: xLabels,
                          highlightIndex: highlightIndex,
                          hideAmounts: hide,
                          themeColor: Theme.of(context).colorScheme.primary,
                          // 使用统一图表令牌
                          lineWidth: BeeChartTokens.lineWidth,
                          dotRadius: BeeChartTokens.dotRadius,
                          cornerRadius: BeeChartTokens.cornerRadius,
                          xLabelFontSize: BeeChartTokens.xLabelFontSize,
                          yLabelFontSize: BeeChartTokens.yLabelFontSize,
                          onSwipeLeft: () {
                            // 根据scope切换周期
                            _onChartSwipeLeft();
                            setState(() => _chartSwiped = true);
                          },
                          onSwipeRight: () {
                            // 根据scope切换周期
                            _onChartSwipeRight();
                            setState(() => _chartSwiped = true);
                          },
                          showHint: !chartDismissed,
                          hintText:
                              AppLocalizations.of(context).analyticsSwipeHint,
                          onCloseHint: () async {
                            final setter =
                                ref.read(analyticsHintsSetterProvider);
                            await setter.dismissChart();
                            if (mounted) {
                              setState(() => _localChartDismissed = true);
                            }
                          },
                          whiteBg: !BeeTokens.isDark(context),
                          isDark: BeeTokens.isDark(context),
                          showGrid: false,
                          showDots: true,
                          annotate: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 结余视角不显示分类排行榜标题和内容
                      if (_type != 'balance')
                        Row(
                          children: [
                            Text(
                              AppLocalizations.of(context)
                                  .analyticsCategoryRanking,
                              style: BeeTextTokens.title(context),
                            ),
                            const Spacer(),
                            // 饼图/列表切换按钮
                            if (catData.isNotEmpty && sum > 0)
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _showPieChart = !_showPieChart),
                                child: Icon(
                                  _showPieChart
                                      ? Icons.format_list_bulleted
                                      : Icons.pie_chart_outline,
                                  size: 20,
                                  color: BeeTokens.textSecondary(context),
                                ),
                              ),
                            if (!headerDismissed) const SizedBox(width: 12),
                            if (!headerDismissed)
                              InkWell(
                                onTap: () async {
                                  final setter =
                                      ref.read(analyticsHintsSetterProvider);
                                  await setter.dismissHeader();
                                  if (mounted) {
                                    setState(
                                        () => _localHeaderDismissed = true);
                                  }
                                },
                                child: Row(
                                  children: [
                                    Icon(Icons.swipe,
                                        size: 14,
                                        color:
                                            BeeTokens.textSecondary(context)),
                                    const SizedBox(width: 4),
                                    Text(
                                        AppLocalizations.of(context)
                                            .analyticsSwipeToSwitch,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: BeeTokens.textSecondary(
                                                    context))),
                                    const SizedBox(width: 4),
                                    Icon(Icons.close,
                                        size: 14,
                                        color: BeeTokens.textTertiary(context)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      if (_type != 'balance') const SizedBox(height: 8),
                      if (_type != 'balance' && _showPieChart && catData.isNotEmpty && sum > 0)
                        CategoryPieChart(
                          data: catData,
                          sum: sum,
                        ),
                      if (_type != 'balance' && !_showPieChart)
                        for (final item in catData)
                          CategoryRankRow(
                            categoryId: item.id,
                            category: item.category,
                            name: item.name,
                            value: item.total,
                            percent: sum == 0 ? 0 : item.total / sum,
                            color: Theme.of(context).colorScheme.primary,
                            start: start,
                            end: end,
                            scope: _scope,
                            selMonth: selMonth,
                            subCategories: item.subCategories,
                          ),
                      // 底部留白，避免被悬浮 Tab 栏遮挡
                      SizedBox(height: 56 + 12 + MediaQuery.of(context).viewPadding.bottom + 16),
                    ],
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// 顶部类型下拉已移除

// 自定义选择器：月份（年+月）
// 旧的自定义年月选择器已移除，统一使用 showWheelDatePicker。

String _currentPeriodLabel(
    String scope, DateTime selMonth, BuildContext context) {
  switch (scope) {
    case 'year':
      return '${selMonth.year}';
    case 'all':
      return AppLocalizations.of(context).analyticsAllYears;
    case 'month':
    default:
      return '${selMonth.year}-${selMonth.month.toString().padLeft(2, '0')}';
  }
}

double _computeAverage(dynamic seriesRaw, String scope) {
  if (seriesRaw is List<({DateTime day, double total})>) {
    if (seriesRaw.isEmpty) return 0;

    // 过滤出有数据的天数(金额>0)
    final nonZeroDays = seriesRaw.where((e) => e.total > 0).toList();
    if (nonZeroDays.isEmpty) return 0;

    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    // 月度视角：按实际有记账的天数计算平均值
    return sum / nonZeroDays.length;
  }

  if (seriesRaw is List<({DateTime month, double total})>) {
    if (seriesRaw.isEmpty) return 0;

    // 过滤出有数据的月份(金额>0)
    final nonZeroMonths = seriesRaw.where((e) => e.total > 0).toList();
    if (nonZeroMonths.isEmpty) return 0;

    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    // 年度视角：按实际有记账的月份计算平均值
    return sum / nonZeroMonths.length;
  }

  if (seriesRaw is List<({int year, double total})>) {
    if (seriesRaw.isEmpty) return 0;

    // 过滤出有数据的年份(金额>0)
    final nonZeroYears = seriesRaw.where((e) => e.total > 0).toList();
    if (nonZeroYears.isEmpty) return 0;

    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    // 全部视角：按实际有记账的年份计算平均值
    return sum / nonZeroYears.length;
  }

  return 0;
}

// 加载分类数据并聚合
Future<List<dynamic>> _loadCategoryData(
  dynamic repo,
  int ledgerId,
  String type,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: type, start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: type, start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[3] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [aggregated, results[1], results[2]];
}

// 加载结余数据并聚合
Future<List<dynamic>> _loadBalanceData(
  dynamic repo,
  int ledgerId,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
  Future<dynamic> incomeSeriesFuture,
  Future<dynamic> expenseSeriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    incomeSeriesFuture,
    expenseSeriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'income', start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[6] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [
    aggregated,
    results[1],
    results[2],
    results[3],
    results[4],
    results[5]
  ];
}

// 聚合一级分类数据（将二级分类金额聚合到一级分类）
Future<List<({int? id, String name, db.Category? category, double total, List<({int id, db.Category category, String name, double total})> subCategories})>>
    _aggregateTopLevelCategories(
        List<
                ({
                  int? id,
                  String name,
                  String? icon,
                  int? parentId,
                  int level,
                  double total
                })>
            hierarchyData,
        dynamic repo,
        Map<int, db.Category> sharedSynthetic) async {
  // 1. 先收集所有一级分类的完整信息
  // §7 共享账本:Editor 的 tx 用 SharedLedger* 表(synthetic 负 id),
  // 主表 getCategoryById 查不到。topLevelNames/Icons 兜底从 hierarchyData
  // 直接取,渲染时不再依赖 db.Category 对象。
  final topLevelInfo = <int, db.Category>{};
  final topLevelNames = <int?, String>{};
  final topLevelIcons = <int?, String?>{};
  for (final item in hierarchyData) {
    if (item.level == 1) {
      topLevelNames[item.id] = item.name;
      topLevelIcons[item.id] = item.icon;
      if (item.id != null && item.id! > 0) {
        // 主表正 id:查 db.Category
        final category = await repo.getCategoryById(item.id!);
        if (category != null) {
          topLevelInfo[item.id!] = category;
        }
      } else if (item.id != null && item.id! < 0) {
        // SharedLedger* synthetic 负 id:从 sharedSynthetic 取合成 Category
        // (含 iconType/customIconPath,UI 能正确渲染自定义图标)
        final synthetic = sharedSynthetic[item.id!];
        if (synthetic != null) {
          topLevelInfo[item.id!] = synthetic;
        }
      }
    }
  }

  // 2. 收集所有需要查询的父分类ID（二级分类的父分类，但在topLevelInfo中不存在的）
  final parentIdsToQuery = <int>{};
  for (final item in hierarchyData) {
    if (item.level == 2 &&
        item.parentId != null &&
        !topLevelInfo.containsKey(item.parentId!)) {
      parentIdsToQuery.add(item.parentId!);
    }
  }

  // 3. 查询缺失的父分类信息
  // §7 共享账本:负 id 是 SharedLedger* 的 synthetic id,主表 getCategoryById
  // 查不到 — fallback 到 sharedSynthetic map(已含所有 SharedLedger 分类)。
  // 顺便补 topLevelNames / topLevelIcons,让结果阶段(line 1146+)能正确
  // fallback 渲染 L1 分类名字 / 图标。
  for (final parentId in parentIdsToQuery) {
    if (parentId < 0 && sharedSynthetic.containsKey(parentId)) {
      final synthetic = sharedSynthetic[parentId]!;
      topLevelInfo[parentId] = synthetic;
      topLevelNames[parentId] = synthetic.name;
      topLevelIcons[parentId] = synthetic.icon;
      continue;
    }
    final category = await repo.getCategoryById(parentId);
    if (category != null) {
      topLevelInfo[parentId] = category;
    }
  }

  // 4. 聚合金额，同时收集子分类明细
  final topLevelMap = <int?, double>{};
  final subCategoriesMap = <int?, List<({int id, db.Category category, String name, double total})>>{};

  for (final item in hierarchyData) {
    if (item.level == 1) {
      // 一级分类：累加金额
      topLevelMap.update(item.id, (v) => v + item.total,
          ifAbsent: () => item.total);
    } else if (item.level == 2 && item.parentId != null) {
      // 二级分类：累加到父分类
      topLevelMap.update(item.parentId, (v) => v + item.total,
          ifAbsent: () => item.total);
      // 收集子分类明细 — §7 共享账本:负 id 的 L2 走 sharedSynthetic
      // fallback,主表 getCategoryById 查不到。这样点击一级分类才能展开
      // SharedLedger* 的子分类,点击子分类才能进 CategoryDetailPage。
      if (item.id != null) {
        db.Category? subCategory;
        if (item.id! < 0) {
          subCategory = sharedSynthetic[item.id!];
        } else {
          subCategory = await repo.getCategoryById(item.id!);
        }
        if (subCategory != null) {
          subCategoriesMap.putIfAbsent(item.parentId, () => []);
          subCategoriesMap[item.parentId]!.add((
            id: item.id!,
            category: subCategory,
            name: item.name,
            total: item.total,
          ));
        }
      }
    }
  }

  // 5. 对每个父分类的子分类按金额降序排列
  for (final subs in subCategoriesMap.values) {
    subs.sort((a, b) => b.total.compareTo(a.total));
  }

  // 6. 转换为列表并排序
  final result = topLevelMap.entries.map((e) {
    final id = e.key;
    final total = e.value;
    final subs = subCategoriesMap[id] ?? <({int id, db.Category category, String name, double total})>[];

    // 获取一级分类信息
    if (id != null && topLevelInfo.containsKey(id)) {
      final category = topLevelInfo[id]!;
      return (
        id: id,
        name: category.name,
        category: category,
        total: total,
        subCategories: subs,
      );
    } else if (topLevelNames.containsKey(id)) {
      // SharedLedger* 兜底:有 name 但 db.Category 为 null,UI 用 name fallback
      return (
        id: id,
        name: topLevelNames[id]!,
        category: null,
        total: total,
        subCategories: subs,
      );
    } else {
      return (
        id: id,
        name: '未分类',
        category: null,
        total: total,
        subCategories: subs,
      );
    }
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return result;
}

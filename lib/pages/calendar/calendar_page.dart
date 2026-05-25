import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../widgets/ui/ui.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/biz/transaction_list_item.dart';
import '../../widgets/category_icon.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../utils/currencies.dart';
import '../../providers.dart';
import '../../providers/calendar_providers.dart';
import '../../l10n/app_localizations.dart';
import '../transaction/transaction_editor_page.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late DateTime _focusedMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = now;

    // 同步到 Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
      ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
    });
    ref.read(calendarSelectedDateProvider.notifier).state = selectedDay;
  }

  void _onPageChanged(DateTime focusedMonth) {
    setState(() {
      _focusedMonth = focusedMonth;
      // 切换月份时，清空选中日期
      _selectedDay = null;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = null;
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
    ref.read(calendarSelectedMonthProvider.notifier).state = _focusedMonth;
    ref.read(calendarSelectedDateProvider.notifier).state = _selectedDay;
  }

  Future<void> _addTransactionForSelectedDate() async {
    // 优先使用当前选中日期，未选中时回退到今天。
    // 把时间锁到中午,避开 UTC 边界导致跨日的问题(交易列表按日期分组,
    // 凌晨 00:00 在某些时区可能被算作前一天)。
    final base = _selectedDay ?? DateTime.now();
    final initialDate = DateTime(base.year, base.month, base.day, 12, 0, 0);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditorPage(
          initialKind: 'expense',
          quickAdd: true,
          initialDate: initialDate,
        ),
      ),
    );

    // 编辑器关闭后,主动刷新日历的统计与当日交易列表
    // (FutureProvider 不会因 Drift 写入自动重算)
    if (mounted) {
      ref.read(calendarRefreshProvider.notifier).state++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final ledgerAsync = ref.watch(currentLedgerProvider);
    final primaryColor = ref.watch(primaryColorProvider);
    final currencySymbol = ledgerAsync.maybeWhen(
      data: (ledger) => ledger?.currency ?? 'CNY',
      orElse: () => 'CNY',
    );

    // 监听数据刷新
    ref.watch(calendarRefreshProvider);

    // 获取当月统计数据
    print('🔍 查询参数: ledgerId=$ledgerId, month=$_focusedMonth');
    final dailyTotalsAsync = ref.watch(
      dailyTotalsByMonthProvider((ledgerId: ledgerId, month: _focusedMonth)),
    );

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // Header
          PrimaryHeader(
            title: l10n.calendarTitle,
            showBack: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton(
                  onPressed: _jumpToToday,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(
                    l10n.calendarToday,
                    style: TextStyle(
                      color: BeeTokens.textPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 日历主体
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // 日历视图
                SectionCard(
                  margin: EdgeInsets.zero,
                  child: dailyTotalsAsync.when(
                    // 记账等触发 calendarRefreshProvider 时不切到 loading,
                    // 旧统计保留,等新数据来无缝替换 — 避免日历整页 spinner 闪烁
                    skipLoadingOnReload: true,
                    data: (dailyTotals) =>
                        _buildCalendar(context, dailyTotals, primaryColor),
                    loading: () => _buildCalendarSkeleton(context),
                    error: (err, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Error: $err'),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 12.0.scaled(context, ref)),

                // 选中日期的交易列表（无日期标题和统计）
                if (_selectedDay != null)
                  _buildDateTransactionsList(context, ledgerId, _selectedDay!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    Map<String, (double, double)> dailyTotals,
    Color primaryColor,
  ) {
    final locale = Localizations.localeOf(context);

    print('📊 _buildCalendar 被调用: dailyTotals.length=${dailyTotals.length}');
    print('📊 locale=${locale.toString()}');
    if (dailyTotals.isNotEmpty) {
      print('📊 数据样例:');
      dailyTotals.entries.take(5).forEach((e) {
        print('  ${e.key}: 收入=${e.value.$1}, 支出=${e.value.$2}');
      });
    }

    return TableCalendar(
      locale: locale.toString(),
      firstDay: DateTime(2020, 1, 1),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _focusedMonth,
      selectedDayPredicate: (day) {
        return _selectedDay != null && isSameDay(_selectedDay, day);
      },
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.horizontalSwipe,

      // 设置行高以适应内容
      rowHeight: 68,
      daysOfWeekHeight: 30,

      // Header 样式
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        leftChevronIcon: Icon(Icons.chevron_left, color: primaryColor),
        rightChevronIcon: Icon(Icons.chevron_right, color: primaryColor),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: BeeTokens.textPrimary(context),
        ),
      ),

      // 日历样式
      calendarStyle: CalendarStyle(
        // 今天样式
        todayDecoration: BoxDecoration(
          color: primaryColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),

        // 选中样式
        selectedDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),

        // 日期文字样式
        defaultTextStyle: TextStyle(
          color: BeeTokens.textPrimary(context),
        ),
        outsideTextStyle: TextStyle(
          color: BeeTokens.textTertiary(context).withOpacity(0.3),
        ),

        // 周末样式
        weekendTextStyle: TextStyle(
          color: BeeTokens.textPrimary(context),
        ),

        // 标记样式
        markersAlignment: Alignment.bottomCenter,
        markerDecoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
      ),

      // 星期标题样式
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: BeeTokens.textSecondary(context),
          fontSize: 12,
        ),
        weekendStyle: TextStyle(
          color: BeeTokens.textSecondary(context),
          fontSize: 12,
        ),
      ),

      // 日期标记构建器
      calendarBuilders: CalendarBuilders(
        // 自定义默认日期单元格
        defaultBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, false, false);
        },
        // 自定义今天日期单元格
        todayBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, true, false, false);
        },
        // 自定义选中日期单元格
        selectedBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, true, false);
        },
        // 自定义非当前月日期
        outsideBuilder: (context, day, focusedDay) {
          return _buildDateCell(
              context, day, dailyTotals, primaryColor, false, false, true);
        },
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime day,
    Map<String, (double, double)> dailyTotals,
    Color primaryColor,
    bool isToday,
    bool isSelected,
    bool isOutside,
  ) {
    final dateKey = _formatDate(day);
    final totals = dailyTotals[dateKey];
    final (income, expense) = totals ?? (0.0, 0.0);
    final hasTransaction = income > 0 || expense > 0;

    // 调试：打印前3天的数据
    if (day.day <= 3 && day.month == _focusedMonth.month) {
      print('📅 _buildDateCell: day=${day.day}, dateKey=$dateKey');
      print(
          '   totals=$totals, income=$income, expense=$expense, hasTransaction=$hasTransaction');
      print('   isOutside=$isOutside');
    }

    // 文字颜色
    Color textColor;
    if (isSelected) {
      textColor = Colors.white;
    } else if (isToday) {
      textColor = primaryColor;
    } else if (isOutside) {
      textColor = BeeTokens.textTertiary(context).withOpacity(0.3);
    } else {
      textColor = BeeTokens.textPrimary(context);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 日期数字（带圆形背景）
          Container(
            width: 32,
            height: 32,
            decoration: isSelected
                ? BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  )
                : isToday
                    ? BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      )
                    : null,
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                height: 1.0,
              ),
            ),
          ),
          // 收入和支出（在圆形外面）
          if (!isOutside && hasTransaction) ...[
            const SizedBox(height: 2),
            // 支出
            if (expense > 0)
              Text(
                expense >= 10000
                    ? '-${(expense / 10000).toStringAsFixed(1)}w'
                    : expense >= 1000
                        ? '-${(expense / 1000).toStringAsFixed(1)}k'
                        : '-${expense.toInt()}',
                style: TextStyle(
                  color: BeeTokens.expenseColor(context, ref),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
            // 收入
            if (income > 0)
              Text(
                income >= 10000
                    ? '+${(income / 10000).toStringAsFixed(1)}w'
                    : income >= 1000
                        ? '+${(income / 1000).toStringAsFixed(1)}k'
                        : '+${income.toInt()}',
                style: TextStyle(
                  color: BeeTokens.incomeColor(context, ref),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
          ],
        ],
      ),
    );
  }

  // 构建选中日期的交易列表（上方含"日期 + 在该日记账"紧凑头）
  Widget _buildDateTransactionsList(BuildContext context, int ledgerId, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final localeName = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.MMMMd(localeName).format(date);
    final weekdayLabel = DateFormat.E(localeName).format(date);

    final transactionsAsync = ref.watch(
      transactionsByDateProvider((ledgerId: ledgerId, date: date)),
    );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  dateLabel,
                  style: TextStyle(
                    color: BeeTokens.textPrimary(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  weekdayLabel,
                  style: TextStyle(
                    color: BeeTokens.textTertiary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _addTransactionForSelectedDate,
              child: Ink(
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        l10n.calendarAddTransaction,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final card = SectionCard(
      margin: EdgeInsets.zero,
      child: transactionsAsync.when(
        // 同上:bump 刷新触发的 reload 不切到 loading 分支,旧列表保持显示
        skipLoadingOnReload: true,
        data: (transactions) {
          if (transactions.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24.0.scaled(context, ref)),
              child: Center(
                child: Text(
                  l10n.calendarNoTransactions,
                  style: TextStyle(
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            );
          }

          // 直接显示交易列表
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final item = transactions[index];
              final category = item.category;
              final isExpense = item.t.type == 'expense';
              final isTransfer = item.t.type == 'transfer';

              // 分类名称
              final categoryName = category?.name ?? l10n.commonUncategorized;

              // 备注作为副标题
              final subtitle = item.t.note ?? '';

              // 标签列表
              final tagsList = item.tags
                  .map((tag) => (id: tag.id, name: tag.name, color: tag.color))
                  .toList();

              return TransactionListItem(
                icon: getCategoryIconData(category: category, categoryName: categoryName),
                category: category,
                title: isTransfer
                    ? (subtitle.isNotEmpty ? subtitle : l10n.transferTitle)
                    : (subtitle.isNotEmpty ? subtitle : categoryName),
                categoryName: isTransfer
                    ? null
                    : (subtitle.isNotEmpty ? categoryName : null),
                amount: item.t.amount,
                isExpense: isExpense,
                isTransfer: isTransfer,
                happenedAt: item.t.happenedAt,
                accountName: item.account?.name,
                tags: tagsList.isNotEmpty ? tagsList : null,
                attachmentCount: item.attachments.length,
                onTap: () async {
                  await TransactionEditUtils.editTransaction(
                    context,
                    ref,
                    item.t,
                    item.category,
                  );
                },
              );
            },
          );
        },
        loading: () => _buildTransactionsSkeleton(context),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Error: $err')),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [header, card],
    );
  }

  // 构建当月交易列表（不显示日期和统计）
  Widget _buildMonthTransactionsList(
      BuildContext context, int ledgerId, DateTime month) {
    final l10n = AppLocalizations.of(context);

    // 使用 Provider 查询当月交易
    final startDate = DateTime(month.year, month.month, 1);
    final endDate = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final transactionsAsync = ref.watch(
      monthTransactionsProvider(
          (ledgerId: ledgerId, startDate: startDate, endDate: endDate)),
    );

    return SectionCard(
      margin: EdgeInsets.zero,
      child: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24.0.scaled(context, ref)),
              child: Center(
                child: Text(
                  l10n.calendarNoTransactions,
                  style: TextStyle(
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            );
          }

          // 直接显示交易列表
          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final item = transactions[index];
              final category = item.category;
              final isExpense = item.t.type == 'expense';
              final isTransfer = item.t.type == 'transfer';

              // 分类名称
              final categoryName = category?.name ?? l10n.commonUncategorized;

              // 备注作为副标题
              final subtitle = item.t.note ?? '';

              // 标签列表
              final tagsList = item.tags
                  .map((tag) => (id: tag.id, name: tag.name, color: tag.color))
                  .toList();

              return TransactionListItem(
                icon: getCategoryIconData(category: category, categoryName: categoryName),
                category: category,
                title: isTransfer
                    ? (subtitle.isNotEmpty ? subtitle : l10n.transferTitle)
                    : (subtitle.isNotEmpty ? subtitle : categoryName),
                categoryName: isTransfer
                    ? null
                    : (subtitle.isNotEmpty ? categoryName : null),
                amount: item.t.amount,
                isExpense: isExpense,
                isTransfer: isTransfer,
                happenedAt: item.t.happenedAt,
                accountName: item.account?.name,
                tags: tagsList.isNotEmpty ? tagsList : null,
                attachmentCount: item.attachments.length,
                onTap: () async {
                  await TransactionEditUtils.editTransaction(
                    context,
                    ref,
                    item.t,
                    item.category,
                  );
                },
              );
            },
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // 日历整页骨架(模拟 6 周 × 7 天 的灰格,接近真实日历高度)
  // 占位等高:rowHeight 68 × 6 + daysOfWeekHeight 30 + header 50 ≈ 488
  Widget _buildCalendarSkeleton(BuildContext context) {
    return DelayedSkeleton(
      placeholder: const SizedBox(height: 488),
      child: PulseSkeleton(
        child: SizedBox(
          height: 488,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const SkeletonBar(height: 18, widthFactor: 0.4),
                const SizedBox(height: 14),
                for (int row = 0; row < 6; row++)
                  Row(
                    children: List.generate(
                      7,
                      (_) => const Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4, vertical: 4),
                          child: SkeletonBar(height: 56),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 当日交易列表骨架(3 条 ListTile 风格占位)
  Widget _buildTransactionsSkeleton(BuildContext context) {
    return const DelayedSkeleton(
      placeholder: SizedBox(height: 200),
      child: PulseSkeleton(
        child: Column(
          children: [
            SkeletonListTile(),
            SkeletonListTile(),
            SkeletonListTile(),
          ],
        ),
      ),
    );
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../utils/month_range.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/posters/annual_report_poster.dart';
import '../../data/db.dart';
import '../../services/export/share_poster_types.dart';
import '../../services/export/share_poster_service.dart';
import '../../services/data/category_service.dart';

/// 年度账单数据
class AnnualReportData {
  final int year;
  final int totalDays;
  final int totalRecords;
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final List<CategoryTotal> topExpenseCategories;
  final List<({int month, double income, double expense})> monthlyData;
  final Transaction? largestExpense;
  final Transaction? largestIncome;
  final Transaction? firstRecord;
  final Category? largestExpenseCategory;
  final Category? largestIncomeCategory;
  final Category? firstRecordCategory;
  final int maxConsecutiveDays;

  const AnnualReportData({
    required this.year,
    required this.totalDays,
    required this.totalRecords,
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.topExpenseCategories,
    required this.monthlyData,
    this.largestExpense,
    this.largestIncome,
    this.firstRecord,
    this.largestExpenseCategory,
    this.largestIncomeCategory,
    this.firstRecordCategory,
    this.maxConsecutiveDays = 0,
  });
}

/// 年度账单数据 Provider
final annualReportDataProvider =
    FutureProvider.family<AnnualReportData?, int>((ref, year) async {
  final ledgerId = ref.watch(currentLedgerIdProvider);
  final repo = ref.watch(repositoryProvider);

  // 获取年度收支总额
  final (income, expense) = await repo.yearlyTotals(ledgerId: ledgerId, year: year);

  if (income == 0 && expense == 0) {
    return null; // 无数据
  }

  // 获取年度交易记录(年 = 12 个自定义周期,design D4;[start, end) 半开)
  final ledger = await repo.getLedgerById(ledgerId);
  final sd = (ledger?.monthStartDay ?? 1).clamp(1, 28);
  final yr = yearRangeFor(year, sd);
  final startDate = yr.start;
  final endDate = yr.end;
  final transactions = await repo.getTransactionsByLedgerInRange(
    ledgerId: ledgerId,
    start: startDate,
    end: endDate,
  );

  // 计算记账天数
  final uniqueDays = <String>{};
  for (final tx in transactions) {
    uniqueDays.add(DateFormat('yyyy-MM-dd').format(tx.happenedAt));
  }
  final totalDays = uniqueDays.length;

  // 获取分类统计
  final categoryTotals = await repo.totalsByCategory(
    ledgerId: ledgerId,
    type: 'expense',
    start: startDate,
    end: endDate,
  );

  // 计算总支出用于百分比
  final totalExpenseForPercent = categoryTotals.fold<double>(0, (sum, c) => sum + c.total);

  // 转换为 CategoryTotal 列表
  final topCategories = categoryTotals.take(5).map((c) {
    return CategoryTotal(
      id: c.id,
      name: c.name,
      icon: c.icon,
      total: c.total,
      percentage: totalExpenseForPercent > 0 ? c.total / totalExpenseForPercent : 0,
    );
  }).toList();

  // 获取月度数据
  final monthlyData = <({int month, double income, double expense})>[];
  for (int m = 1; m <= 12; m++) {
    final (monthIncome, monthExpense) = await repo.monthlyTotals(
      ledgerId: ledgerId,
      month: DateTime(year, m),
    );
    monthlyData.add((month: m, income: monthIncome, expense: monthExpense));
  }

  // 找出最大支出、最大收入、首笔记录
  Transaction? largestExpense;
  Transaction? largestIncome;
  Transaction? firstRecord;

  for (final tx in transactions) {
    if (tx.type == 'expense') {
      if (largestExpense == null || tx.amount > largestExpense.amount) {
        largestExpense = tx;
      }
    } else if (tx.type == 'income') {
      if (largestIncome == null || tx.amount > largestIncome.amount) {
        largestIncome = tx;
      }
    }
    if (firstRecord == null || tx.happenedAt.isBefore(firstRecord.happenedAt)) {
      firstRecord = tx;
    }
  }

  // 获取分类信息
  Category? largestExpenseCategory;
  Category? largestIncomeCategory;
  Category? firstRecordCategory;

  if (largestExpense?.categoryId != null) {
    largestExpenseCategory = await repo.getCategoryById(largestExpense!.categoryId!);
  }
  if (largestIncome?.categoryId != null) {
    largestIncomeCategory = await repo.getCategoryById(largestIncome!.categoryId!);
  }
  if (firstRecord?.categoryId != null) {
    firstRecordCategory = await repo.getCategoryById(firstRecord!.categoryId!);
  }

  // 计算最长连续记账天数
  final sortedDays = uniqueDays.toList()..sort();
  int maxConsecutive = 0;
  int currentConsecutive = 1;

  for (int i = 1; i < sortedDays.length; i++) {
    final prev = DateTime.parse(sortedDays[i - 1]);
    final curr = DateTime.parse(sortedDays[i]);
    if (curr.difference(prev).inDays == 1) {
      currentConsecutive++;
      if (currentConsecutive > maxConsecutive) {
        maxConsecutive = currentConsecutive;
      }
    } else {
      currentConsecutive = 1;
    }
  }
  if (sortedDays.length == 1) maxConsecutive = 1;

  return AnnualReportData(
    year: year,
    totalDays: totalDays,
    totalRecords: transactions.length,
    totalIncome: income,
    totalExpense: expense,
    netSavings: income - expense,
    topExpenseCategories: topCategories,
    monthlyData: monthlyData,
    largestExpense: largestExpense,
    largestIncome: largestIncome,
    firstRecord: firstRecord,
    largestExpenseCategory: largestExpenseCategory,
    largestIncomeCategory: largestIncomeCategory,
    firstRecordCategory: firstRecordCategory,
    maxConsecutiveDays: maxConsecutive,
  );
});

/// 年度账单页面
class AnnualReportPage extends ConsumerStatefulWidget {
  final int? initialYear;

  const AnnualReportPage({super.key, this.initialYear});

  @override
  ConsumerState<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends ConsumerState<AnnualReportPage> {
  late PageController _pageController;
  int _currentPage = 0;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // 如果传入了初始年份则使用，否则使用当前年份
    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final dataAsync = ref.watch(annualReportDataProvider(_selectedYear));

    return Scaffold(
      backgroundColor: primaryColor,
      body: dataAsync.when(
        loading: () => _buildLoading(l10n),
        error: (e, _) => _buildError(l10n, e.toString()),
        data: (data) {
          if (data == null) {
            return _buildNoData(l10n);
          }
          return _buildContent(context, data);
        },
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          Text(
            l10n.annualReportGenerating,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            '${l10n.commonError}: $error',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonBack, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoData(AppLocalizations l10n) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(l10n),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    l10n.annualReportNoData(_selectedYear),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  _buildYearSelector(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          _buildYearSelector(),
          const Spacer(),
          const SizedBox(width: 48), // Balance the close button
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButton<int>(
        value: _selectedYear,
        dropdownColor: ref.watch(primaryColorProvider),
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        items: years.map((year) {
          return DropdownMenuItem(
            value: year,
            child: Text('$year'),
          );
        }).toList(),
        onChanged: (year) {
          if (year != null) {
            setState(() => _selectedYear = year);
          }
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(l10n),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _buildPage1Overview(context, data),
                _buildPageInsights(context, data), // 年度洞察
                _buildPageIncomeVsExpense(context, data), // 收支对比
                _buildPage2Categories(context, data),
                _buildPage3MonthlyTrend(context, data),
                _buildPage4SpecialMoments(context, data),
                _buildPage5Achievements(context, data),
              ],
            ),
          ),
          _buildPageIndicator(7), // 7页
          const SizedBox(height: 16),
          _buildBottomActions(l10n),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildBottomActions(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _generatePoster,
          icon: const Icon(Icons.share),
          label: Text(l10n.annualReportShareButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: ref.watch(primaryColorProvider),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePoster() async {
    final dataAsync = ref.read(annualReportDataProvider(_selectedYear));
    final data = dataAsync.valueOrNull;
    if (data == null) return;

    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.annualReportGenerating,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      // Precache logo image
      await precacheImage(const AssetImage('assets/logo2.png'), context);

      // Create poster widget
      final posterKey = GlobalKey();
      final poster = RepaintBoundary(
        key: posterKey,
        child: AnnualReportPoster(
          data: data,
          primaryColor: primaryColor,
        ),
      );

      // Render to image using offscreen rendering
      final pngBytes = await _renderPosterToImage(poster, posterKey);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show preview dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => _AnnualReportPosterPreview(
          initialImageBytes: pngBytes,
          data: data,
          primaryColor: primaryColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showToast(context, '${l10n.commonError}: $e');
    }
  }

  Future<Uint8List> _renderPosterToImage(Widget poster, GlobalKey key) async {
    // Use a temporary overlay to render the widget
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000, // Off-screen
        child: Material(
          color: Colors.transparent,
          child: poster,
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Wait for the widget to be laid out and images to load
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to find render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      overlayEntry.remove();
    }
  }

  // ==================== Page 1: Overview ====================
  Widget _buildPage1Overview(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            l10n.annualReportPage1Title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualReportPage1Subtitle(data.year),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // 记账天数和笔数
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.calendar_today_rounded,
                  label: l10n.annualReportTotalDays,
                  value: '${data.totalDays}',
                  unit: '天',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.edit_note_rounded,
                  label: l10n.annualReportTotalRecords,
                  value: '${data.totalRecords}',
                  unit: '笔',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 收支卡片
          _buildAmountCard(
            icon: Icons.trending_up_rounded,
            label: l10n.annualReportTotalIncome,
            amount: data.totalIncome,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(height: 12),
          _buildAmountCard(
            icon: Icons.trending_down_rounded,
            label: l10n.annualReportTotalExpense,
            amount: data.totalExpense,
            color: const Color(0xFFFF5252),
          ),
          const SizedBox(height: 12),
          _buildAmountCard(
            icon: data.netSavings >= 0 ? Icons.savings_rounded : Icons.warning_rounded,
            label: l10n.annualReportNetSavings,
            amount: data.netSavings,
            color: data.netSavings >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
            showSign: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard({
    required IconData icon,
    required String label,
    required double amount,
    required Color color,
    bool showSign = false,
  }) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final sign = showSign ? (amount >= 0 ? '+' : '-') : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF666666),
            ),
          ),
          const Spacer(),
          Text(
            '$sign¥${formatter.format(amount.abs())}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 年度洞察页 ====================
  Widget _buildPageInsights(BuildContext context, AnnualReportData data) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final primaryColor = ref.watch(primaryColorProvider);

    // 计算各种洞察数据
    final avgExpensePerRecord = data.totalRecords > 0
        ? data.totalExpense / data.totalRecords
        : 0.0;

    // 计算年度总天数：过去年份用全年天数，当前年份用截至今天的天数
    final now = DateTime.now();
    final sd = ref.watch(currentMonthStartDayProvider);
    final yr = yearRangeFor(data.year, sd);
    final isCurrentYear =
        !now.isBefore(yr.start) && now.isBefore(yr.end);
    final yearEnd =
        isCurrentYear ? now : yr.end.subtract(const Duration(days: 1));
    final yearStart = yr.start;
    final totalCalendarDays = yearEnd.difference(yearStart).inDays + 1;

    final dailyAvg = totalCalendarDays > 0 ? data.totalExpense / totalCalendarDays : 0;
    final monthlyAvg = data.totalExpense / 12;

    // 找出记账最多的月份
    int busiestMonth = 1;
    double maxMonthlyTotal = 0;
    for (final m in data.monthlyData) {
      final total = m.income + m.expense;
      if (total > maxMonthlyTotal) {
        maxMonthlyTotal = total;
        busiestMonth = m.month;
      }
    }

    // 储蓄率
    final savingsRate = data.totalIncome > 0
        ? (data.netSavings / data.totalIncome * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '年度洞察',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '从数据中发现你的消费习惯',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 洞察卡片
          _buildInsightItem(
            icon: Icons.receipt_long_rounded,
            title: '平均每笔消费',
            value: '¥${formatter.format(avgExpensePerRecord)}',
            description: '你每次记账的平均金额',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          _buildInsightItem(
            icon: Icons.schedule_rounded,
            title: '日均支出',
            value: '¥${formatter.format(dailyAvg)}',
            description: '平均每天花费金额',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          _buildInsightItem(
            icon: Icons.date_range_rounded,
            title: '月均支出',
            value: '¥${formatter.format(monthlyAvg)}',
            description: '平均每月花费金额',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          _buildInsightItem(
            icon: Icons.calendar_month_rounded,
            title: '最活跃月份',
            value: '$busiestMonth月',
            description: '记账活动最频繁的月份',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          _buildInsightItem(
            icon: Icons.category_rounded,
            title: '消费分类数',
            value: '${data.topExpenseCategories.length}个',
            description: '你使用过的消费分类数量',
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),

          // 储蓄率（仅在有收入数据时显示）
          if (data.totalIncome > 0)
            _buildInsightItem(
              icon: Icons.savings_rounded,
              title: '储蓄率',
              value: '${savingsRate.toStringAsFixed(1)}%',
              description: savingsRate >= 0 ? '今年你攒下了收入的这个比例' : '今年支出超过了收入',
              primaryColor: savingsRate >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required String value,
    required String description,
    required Color primaryColor,
  }) {
    // 判断是否使用特殊颜色（红/绿）
    final isSpecialColor = primaryColor == const Color(0xFF4CAF50) ||
        primaryColor == const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isSpecialColor ? primaryColor : Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 收支对比页 ====================
  Widget _buildPageIncomeVsExpense(BuildContext context, AnnualReportData data) {
    final formatter = NumberFormat('#,##0', 'zh_CN');

    // 找出最高和最低月份
    double maxIncome = 0;
    double maxExpense = 0;
    int maxIncomeMonth = 1;
    int maxExpenseMonth = 1;

    for (final m in data.monthlyData) {
      if (m.income > maxIncome) {
        maxIncome = m.income;
        maxIncomeMonth = m.month;
      }
      if (m.expense > maxExpense) {
        maxExpense = m.expense;
        maxExpenseMonth = m.month;
      }
    }

    final maxValue = maxIncome > maxExpense ? maxIncome : maxExpense;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '收支对比',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '每月收入与支出的对比',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '收入',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 24),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '支出',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 月度对比条形图
          ...data.monthlyData.map((m) {
            final incomeRatio = maxValue > 0 ? m.income / maxValue : 0.0;
            final expenseRatio = maxValue > 0 ? m.expense / maxValue : 0.0;
            final isMaxIncome = m.month == maxIncomeMonth;
            final isMaxExpense = m.month == maxExpenseMonth;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 月份标签
                  Row(
                    children: [
                      Text(
                        '${m.month}月',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isMaxIncome)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '收入最高',
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (isMaxExpense)
                        Container(
                          margin: EdgeInsets.only(left: isMaxIncome ? 6 : 0),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '支出最高',
                            style: TextStyle(
                              color: Color(0xFFFF5252),
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 收入条
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: incomeRatio.clamp(0.0, 1.0),
                              child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '¥${formatter.format(m.income)}',
                          style: const TextStyle(
                            color: Color(0xFF4CAF50),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 支出条
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: expenseRatio.clamp(0.0, 1.0),
                              child: Container(
                                height: 16,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5252),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          '¥${formatter.format(m.expense)}',
                          style: const TextStyle(
                            color: Color(0xFFFF5252),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Page 2: Categories ====================
  Widget _buildPage2Categories(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualReportPage2Title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualReportPage2Subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // TOP 分类列表
          ...data.topExpenseCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final rankColors = [
              const Color(0xFFFFD700),
              const Color(0xFFC0C0C0),
              const Color(0xFFCD7F32),
              Colors.white.withValues(alpha: 0.6),
              Colors.white.withValues(alpha: 0.6),
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    // 排名
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: rankColors[index],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: index < 3 ? Colors.white : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 图标
                    if (category.icon != null)
                      Icon(
                        CategoryService.getCategoryIcon(category.icon),
                        color: Colors.white,
                        size: 24,
                      ),
                    const SizedBox(width: 12),
                    // 名称
                    Expanded(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // 金额和占比
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${formatter.format(category.total)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${(category.percentage * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== Page 3: Monthly Trend ====================
  Widget _buildPage3MonthlyTrend(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat('#,##0', 'zh_CN');

    // 找出最高和最低支出月份
    double maxExpense = 0;
    double minExpense = double.infinity;
    int maxMonth = 1;
    int minMonth = 1;

    for (final m in data.monthlyData) {
      if (m.expense > maxExpense) {
        maxExpense = m.expense;
        maxMonth = m.month;
      }
      if (m.expense < minExpense && m.expense > 0) {
        minExpense = m.expense;
        minMonth = m.month;
      }
    }

    // 如果没有支出，重置最小值
    if (minExpense == double.infinity) minExpense = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualReportPage3Title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualReportPage3Subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 最高/最低月份
          Row(
            children: [
              Expanded(
                child: _buildHighlightCard(
                  label: l10n.annualReportHighestMonth,
                  value: '$maxMonth月',
                  subValue: '¥${formatter.format(maxExpense)}',
                  color: const Color(0xFFFF5252),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHighlightCard(
                  label: l10n.annualReportLowestMonth,
                  value: '$minMonth月',
                  subValue: '¥${formatter.format(minExpense)}',
                  color: const Color(0xFF4CAF50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 简易柱状图
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // 柱状图
                SizedBox(
                  height: 200,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.monthlyData.map((m) {
                      final heightRatio = maxExpense > 0 ? m.expense / maxExpense : 0.0;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 160 * heightRatio,
                                decoration: BoxDecoration(
                                  color: m.month == maxMonth
                                      ? const Color(0xFFFF5252)
                                      : m.month == minMonth
                                          ? const Color(0xFF4CAF50)
                                          : Colors.white.withValues(alpha: 0.6),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${m.month}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required String label,
    required String value,
    required String subValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF666666),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subValue,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Page 4: Special Moments ====================
  Widget _buildPage4SpecialMoments(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);
    final dateFormatter = DateFormat('MM月dd日');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualReportPage4Title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualReportPage4Subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // 最大支出
          if (data.largestExpense != null)
            _buildMomentCard(
              icon: Icons.arrow_downward_rounded,
              label: l10n.annualReportLargestExpense,
              amount: data.largestExpense!.amount,
              note: data.largestExpense!.note ?? data.largestExpenseCategory?.name ?? '',
              date: dateFormatter.format(data.largestExpense!.happenedAt),
              color: const Color(0xFFFF5252),
            ),

          if (data.largestIncome != null) ...[
            const SizedBox(height: 16),
            _buildMomentCard(
              icon: Icons.arrow_upward_rounded,
              label: l10n.annualReportLargestIncome,
              amount: data.largestIncome!.amount,
              note: data.largestIncome!.note ?? data.largestIncomeCategory?.name ?? '',
              date: dateFormatter.format(data.largestIncome!.happenedAt),
              color: const Color(0xFF4CAF50),
            ),
          ],

          if (data.firstRecord != null) ...[
            const SizedBox(height: 16),
            _buildMomentCard(
              icon: Icons.flag_rounded,
              label: l10n.annualReportFirstRecord,
              amount: data.firstRecord!.amount,
              note: data.firstRecord!.note ?? data.firstRecordCategory?.name ?? '',
              date: dateFormatter.format(data.firstRecord!.happenedAt),
              color: ref.watch(primaryColorProvider),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMomentCard({
    required IconData icon,
    required String label,
    required double amount,
    required String note,
    required String date,
    required Color color,
  }) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '¥${formatter.format(amount)}',
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  // ==================== Page 5: Achievements ====================
  Widget _buildPage5Achievements(BuildContext context, AnnualReportData data) {
    final l10n = AppLocalizations.of(context);

    // 定义成就
    final achievements = <({String title, String desc, IconData icon, bool unlocked})>[
      (
        title: l10n.annualReportAchievementConsistent,
        desc: l10n.annualReportAchievementConsistentDesc(data.maxConsecutiveDays),
        icon: Icons.local_fire_department_rounded,
        unlocked: data.maxConsecutiveDays >= 7,
      ),
      (
        title: l10n.annualReportAchievementSaver,
        desc: l10n.annualReportAchievementSaverDesc,
        icon: Icons.savings_rounded,
        unlocked: data.netSavings > 0,
      ),
      (
        title: l10n.annualReportAchievementDetail,
        desc: l10n.annualReportAchievementDetailDesc(data.totalRecords),
        icon: Icons.auto_awesome_rounded,
        unlocked: data.totalRecords >= 100,
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.annualReportPage5Title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.annualReportPage5Subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),

          // 成就列表
          ...achievements.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildAchievementCard(
                  icon: a.icon,
                  title: a.title,
                  desc: a.desc,
                  unlocked: a.unlocked,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAchievementCard({
    required IconData icon,
    required String title,
    required String desc,
    required bool unlocked,
  }) {
    final primaryColor = ref.watch(primaryColorProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: unlocked ? primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: unlocked ? primaryColor : Colors.grey,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: unlocked ? Colors.black87 : Colors.grey,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: unlocked ? Colors.grey[600] : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Icon(
              Icons.check_circle,
              color: primaryColor,
              size: 28,
            )
          else
            Icon(
              Icons.lock_outline,
              color: Colors.grey[400],
              size: 24,
            ),
        ],
      ),
    );
  }
}

/// 年度账单海报预览对话框
class _AnnualReportPosterPreview extends StatefulWidget {
  final Uint8List initialImageBytes;
  final AnnualReportData data;
  final Color primaryColor;

  const _AnnualReportPosterPreview({
    required this.initialImageBytes,
    required this.data,
    required this.primaryColor,
  });

  @override
  State<_AnnualReportPosterPreview> createState() => _AnnualReportPosterPreviewState();
}

class _AnnualReportPosterPreviewState extends State<_AnnualReportPosterPreview> {
  late Uint8List _imageBytes;
  bool _hideIncome = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
  }

  Future<void> _toggleHideIncome() async {
    setState(() {
      _hideIncome = !_hideIncome;
      _isGenerating = true;
    });

    try {
      // 重新生成海报
      final posterKey = GlobalKey();
      final poster = RepaintBoundary(
        key: posterKey,
        child: AnnualReportPoster(
          data: widget.data,
          primaryColor: widget.primaryColor,
          hideIncome: _hideIncome,
        ),
      );

      final pngBytes = await _renderPosterToImage(poster, posterKey);

      if (mounted) {
        setState(() {
          _imageBytes = pngBytes;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        showToast(context, AppLocalizations.of(context).commonError);
      }
    }
  }

  Future<Uint8List> _renderPosterToImage(Widget poster, GlobalKey key) async {
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        child: Material(
          color: Colors.transparent,
          child: poster,
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to find render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } finally {
      overlayEntry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 海报预览
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 3.0,
                        child: Image.memory(
                          _imageBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                      // 生成中的加载指示器
                      if (_isGenerating)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      // 隐藏收入切换按钮
                      if (!_isGenerating)
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleHideIncome,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _hideIncome
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _hideIncome ? l10n.sharePosterShowIncome : l10n.sharePosterHideIncome,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
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
                ),
              ),
              const SizedBox(height: 16),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 保存按钮
                  _buildActionButton(
                    context: context,
                    icon: Icons.save_alt,
                    label: l10n.sharePosterSave,
                    onTap: _isGenerating ? null : () => _savePoster(context),
                    isPrimary: true,
                  ),
                  const SizedBox(width: 16),
                  // 分享按钮
                  _buildActionButton(
                    context: context,
                    icon: Icons.share,
                    label: l10n.sharePosterShare,
                    onTap: _isGenerating ? null : () => _sharePoster(context),
                    isPrimary: false,
                  ),
                ],
              ),
            ],
          ),
          // 右上角关闭按钮
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
  }) {
    final isDisabled = onTap == null;
    final bgColor = isPrimary ? widget.primaryColor : Colors.white;
    final fgColor = isPrimary ? Colors.white : widget.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: fgColor,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _savePoster(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await SharePosterService.savePosterToGallery(_imageBytes);

    if (!context.mounted) return;

    switch (result) {
      case SavePosterResult.success:
        showToast(context, l10n.annualReportSaveSuccess);
        Navigator.pop(context);
        break;
      case SavePosterResult.accessDenied:
        showToast(context, l10n.commonFailed);
        break;
      case SavePosterResult.failed:
        showToast(context, l10n.commonFailed);
        break;
    }
  }

  Future<void> _sharePoster(BuildContext context) async {
    await SharePosterService.sharePoster(_imageBytes);
  }
}

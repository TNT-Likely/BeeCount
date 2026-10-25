import 'package:beecount_business_ui/annual_report.dart';
import 'package:beecount_ui/beecount_ui.dart';
import '../../presentation/v4/bindings/annual_report_sections.dart';
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

/// 年度账单数据
class AnnualReportData {
  final int year;
  final String currencyCode;
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
    this.currencyCode = 'CNY',
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
  final (income, expense) =
      await repo.yearlyTotals(ledgerId: ledgerId, year: year);

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
  final totalExpenseForPercent =
      categoryTotals.fold<double>(0, (sum, c) => sum + c.total);

  // 转换为 CategoryTotal 列表
  final topCategories = categoryTotals.take(5).map((c) {
    return CategoryTotal(
      id: c.id,
      name: c.name,
      icon: c.icon,
      total: c.total,
      percentage:
          totalExpenseForPercent > 0 ? c.total / totalExpenseForPercent : 0,
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

  // 「最大单笔」按折算值(nativeAmount)比较,否则多币种下 5000 JPY(≈250 CNY)
  // 会因原币数字大被误判为比 300 CNY 更大的支出。展示仍是各笔原币金额。
  double conv(Transaction t) => t.nativeAmount ?? t.amount;
  for (final tx in transactions) {
    if (tx.type == 'expense') {
      if (largestExpense == null || conv(tx) > conv(largestExpense)) {
        largestExpense = tx;
      }
    } else if (tx.type == 'income') {
      if (largestIncome == null || conv(tx) > conv(largestIncome)) {
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
    largestExpenseCategory =
        await repo.getCategoryById(largestExpense!.categoryId!);
  }
  if (largestIncome?.categoryId != null) {
    largestIncomeCategory =
        await repo.getCategoryById(largestIncome!.categoryId!);
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
    currencyCode: ledger?.currency.toUpperCase() ?? 'CNY',
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

/// 年度账单页面。数据与原生导出保留 App 绑定。
class AnnualReportPage extends ConsumerStatefulWidget {
  final int? initialYear;
  const AnnualReportPage({super.key, this.initialYear});
  @override
  ConsumerState<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends ConsumerState<AnnualReportPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  late int _selectedYear;
  bool _generatingPoster = false;
  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cards = BeeCardTheme.of(context);
    final dataAsync = ref.watch(annualReportDataProvider(_selectedYear));
    final currentYear = DateTime.now().year;
    final years = {...List.generate(5, (i) => currentYear - i), _selectedYear}
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return Scaffold(
        backgroundColor: cards.canvas,
        body: SafeArea(
            child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 17, 5),
              child: Row(children: [
                BeeIconButton(
                    key: const ValueKey('annual-close'),
                    label: l.commonClose,
                    onPressed: () => Navigator.maybePop(context),
                    icon: const BeeLineIcon('X', size: 22)),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(l.annualReportTitle,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600))),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                        color: cards.surface,
                        borderRadius: BorderRadius.circular(13)),
                    child: DropdownButton<int>(
                        key: const ValueKey('annual-year'),
                        value: _selectedYear,
                        underline: const SizedBox.shrink(),
                        dropdownColor: cards.surface,
                        borderRadius: BorderRadius.circular(16),
                        items: [
                          for (final year in years)
                            DropdownMenuItem(
                                value: year,
                                child: Text('$year',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)))
                        ],
                        onChanged: (year) {
                          if (year != null) {
                            setState(() => _selectedYear = year);
                          }
                        })),
              ])),
          Expanded(
              child: dataAsync.when(
                  loading: () => Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(l.annualReportGenerating)
                      ])),
                  error: (e, _) => Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const BeeLineIcon('CircleAlert', size: 40),
                            const SizedBox(height: 16),
                            Text('${l.commonError}: $e',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextButton(
                                onPressed: () => ref.invalidate(
                                    annualReportDataProvider(_selectedYear)),
                                child: Text(l.helpCenterRetry))
                          ]))),
                  data: (data) {
                    if (data == null) {
                      return Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const BeeLineIcon('Inbox', size: 48),
                                    const SizedBox(height: 16),
                                    Text(l.annualReportNoData(_selectedYear),
                                        textAlign: TextAlign.center)
                                  ])));
                    }
                    return Column(children: [
                      Expanded(
                          child: PageView(
                              controller: _pageController,
                              onPageChanged: (page) =>
                                  setState(() => _currentPage = page),
                              children: annualReportSections(context, data,
                                  monthStartDay: ref
                                      .watch(currentMonthStartDayProvider)))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(17, 10, 17, 5),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < 7; i++)
                                  Semantics(
                                      label: '${i + 1} / 7',
                                      selected: i == _currentPage,
                                      child: GestureDetector(
                                          onTap: () => _pageController.animateToPage(i,
                                              duration: const Duration(
                                                  milliseconds: 200),
                                              curve: Curves.easeOut),
                                          child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 4, vertical: 9),
                                              child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  width: i == _currentPage
                                                      ? 24
                                                      : 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                      color: i == _currentPage
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .primary
                                                          : Theme.of(context).hintColor.withValues(alpha: .2),
                                                      borderRadius: BorderRadius.circular(4))))))
                              ])),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(17, 0, 17, 14),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  key: const ValueKey('annual-generate-poster'),
                                  onPressed: _generatingPoster
                                      ? null
                                      : _generatePoster,
                                  icon: const BeeLineIcon('Share', size: 18),
                                  label: Text(l.annualReportShareButton))))
                    ]);
                  })),
        ])));
  }

  Future<void> _generatePoster() async {
    if (_generatingPoster) return;
    final dataAsync = ref.read(annualReportDataProvider(_selectedYear));
    final data = dataAsync.valueOrNull;
    if (data == null) return;

    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.read(primaryColorProvider);
    final monthStartDay = ref.read(currentMonthStartDayProvider);

    setState(() => _generatingPoster = true);

    // Track cancellation so a late render never pops the underlying page.
    bool loadingShown = true;
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
    ).whenComplete(() => loadingShown = false);

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
          monthStartDay: monthStartDay,
        ),
      );

      // Render to image using offscreen rendering
      final pngBytes = await _renderPosterToImage(poster, posterKey);

      if (!mounted || !loadingShown) return;
      loadingShown = false;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      // Show preview dialog
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => _AnnualReportPosterPreview(
          initialImageBytes: pngBytes,
          data: data,
          primaryColor: primaryColor,
          monthStartDay: monthStartDay,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (loadingShown) {
        loadingShown = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
      showToast(context, '${l10n.commonError}: $e');
    } finally {
      if (mounted) setState(() => _generatingPoster = false);
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
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to find render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      overlayEntry.remove();
    }
  }
}

/// 年度账单海报预览对话框
class _AnnualReportPosterPreview extends StatefulWidget {
  final Uint8List initialImageBytes;
  final AnnualReportData data;
  final Color primaryColor;
  final int monthStartDay;

  const _AnnualReportPosterPreview({
    required this.initialImageBytes,
    required this.data,
    required this.primaryColor,
    required this.monthStartDay,
  });

  @override
  State<_AnnualReportPosterPreview> createState() =>
      _AnnualReportPosterPreviewState();
}

class _AnnualReportPosterPreviewState
    extends State<_AnnualReportPosterPreview> {
  late Uint8List _imageBytes;
  bool _hideIncome = false;
  bool _isGenerating = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _imageBytes = widget.initialImageBytes;
  }

  Future<void> _toggleHideIncome() async {
    if (_isGenerating || _isExporting) return;
    final previousHideIncome = _hideIncome;
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
          monthStartDay: widget.monthStartDay,
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
        setState(() {
          _isGenerating = false;
          _hideIncome = previousHideIncome;
        });
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
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Failed to find render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      overlayEntry.remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return BeeAnnualPosterPreview(
        title: l.annualReportTitle,
        closeLabel: l.commonClose,
        privacyLabel:
            _hideIncome ? l.sharePosterShowIncome : l.sharePosterHideIncome,
        saveLabel: l.sharePosterSave,
        shareLabel: l.sharePosterShare,
        preview: Image.memory(_imageBytes, fit: BoxFit.contain),
        busy: _isGenerating || _isExporting,
        hideIncome: _hideIncome,
        onPrivacy: _toggleHideIncome,
        onSave: () => _savePoster(context),
        onShare: () => _sharePoster(context),
        onClose: () => Navigator.pop(context));
  }

  Future<void> _savePoster(BuildContext context) async {
    if (_isGenerating || _isExporting) return;
    setState(() => _isExporting = true);
    final l = AppLocalizations.of(context);
    try {
      final result = await SharePosterService.savePosterToGallery(_imageBytes);
      if (!context.mounted) return;
      switch (result) {
        case SavePosterResult.success:
          showToast(context, l.annualReportSaveSuccess);
          Navigator.pop(context);
          break;
        case SavePosterResult.accessDenied:
          showToast(context, l.sharePosterPermissionDenied);
          break;
        case SavePosterResult.failed:
          showToast(context, l.sharePosterSaveFailed);
          break;
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sharePoster(BuildContext context) async {
    if (_isGenerating || _isExporting) return;
    setState(() => _isExporting = true);
    try {
      await SharePosterService.sharePoster(_imageBytes);
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}

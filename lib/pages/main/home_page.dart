import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../../providers/budget_providers.dart';
import '../budget/budget_page.dart';
import '../../providers.dart';
import '../settings/personalize_page.dart' show headerStyleProvider;
import '../../data/db.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/biz/bee_icon.dart';
import '../../styles/tokens.dart';
import '../transaction/search_page.dart';
import '../ai/ai_chat_page.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/logger_service.dart';
import '../../utils/format_utils.dart';
import '../../services/export/share_poster_service.dart';
import '../report/annual_report_page.dart';
import '../calendar/calendar_page.dart';
import '../../widgets/biz/ledger_picker_sheet.dart';
import '../../widgets/biz/home_budget_summary.dart';
import '../../providers/shared_ledger_providers.dart';

// 优化版首页 - 使用FlutterListView实现精准定位和丝滑跳转
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late FlutterListViewController _listController;
  bool _isJumping = false;
  final GlobalKey<TransactionListState> _transactionListKey =
      GlobalKey<TransactionListState>();

  // 可见性管理
  final Set<String> _visibleHeaders = {}; // 当前可见的日期头部
  Timer? _debounceTimer;

  // StreamBuilder 刷新计数器
  int _streamBuilderKey = 0;
  int? _lastLedgerId;

  // 月初提醒状态
  bool _showLastMonthReminder = false;
  static const String _reminderDismissedKey = 'last_month_reminder_dismissed';

  // 年度账单提醒状态（12月15日 - 次年1月31日显示）
  bool _showAnnualReportReminder = false;
  static const String _annualReportDismissedKey =
      'annual_report_reminder_dismissed';

  // 预算设置引导卡片状态
  bool _showBudgetSetupHint = false;
  static const String _budgetSetupHintDismissedKey =
      'budget_setup_hint_dismissed';

  @override
  void initState() {
    super.initState();
    _listController = FlutterListViewController();
    _checkLastMonthReminder();
    _checkAnnualReportReminder();
    _checkBudgetSetupHint();
  }

  // 检查是否应该显示上月报告提醒
  Future<void> _checkLastMonthReminder() async {
    final now = DateTime.now();
    // 只在每月前7天显示提醒
    if (now.day > 7) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissedMonth = prefs.getString(_reminderDismissedKey);
    final currentMonth = '${now.year}-${now.month}';

    // 如果当月已经关闭过，不再显示
    if (dismissedMonth == currentMonth) return;

    if (mounted) {
      setState(() {
        _showLastMonthReminder = true;
      });
    }
  }

  // 关闭上月报告提醒
  Future<void> _dismissLastMonthReminder() async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reminderDismissedKey, currentMonth);

    if (mounted) {
      setState(() {
        _showLastMonthReminder = false;
      });
    }
  }

  // 检查是否应该显示年度账单提醒（12月15日 - 次年1月31日）
  Future<void> _checkAnnualReportReminder() async {
    final now = DateTime.now();

    // 判断是否在提醒时间范围内：12月15日 - 次年1月31日
    final isInRange = (now.month == 12 && now.day >= 15) || now.month == 1;
    if (!isInRange) return;

    // 确定要展示的年度（12月展示当年，1月展示上一年）
    final reportYear = now.month == 1 ? now.year - 1 : now.year;

    final prefs = await SharedPreferences.getInstance();
    final dismissedYear = prefs.getInt(_annualReportDismissedKey);

    // 如果这个年度已经关闭过，不再显示
    if (dismissedYear == reportYear) return;

    if (mounted) {
      setState(() {
        _showAnnualReportReminder = true;
      });
    }
  }

  // 关闭年度账单提醒
  Future<void> _dismissAnnualReportReminder() async {
    final now = DateTime.now();
    final reportYear = now.month == 1 ? now.year - 1 : now.year;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_annualReportDismissedKey, reportYear);

    if (mounted) {
      setState(() {
        _showAnnualReportReminder = false;
      });
    }
  }

  // 检查是否应该显示预算设置引导卡片
  Future<void> _checkBudgetSetupHint() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_budgetSetupHintDismissedKey) ?? false;
    if (dismissed) return;

    if (mounted) {
      setState(() {
        _showBudgetSetupHint = true;
      });
    }
  }

  // 关闭预算设置引导卡片（永不再显示）
  Future<void> _dismissBudgetSetupHint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_budgetSetupHintDismissedKey, true);

    if (mounted) {
      setState(() {
        _showBudgetSetupHint = false;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _listController.dispose();
    super.dispose();
  }

  // 精准月份跳转 - 使用TransactionList组件的跳转功能
  Future<void> _jumpToTargetMonth(DateTime targetMonth) async {
    if (_isJumping) return; // 防止重复跳转

    setState(() {
      _isJumping = true;
    });

    try {
      // 使用TransactionList组件的跳转方法
      final transactionListState = _transactionListKey.currentState;
      if (transactionListState != null && mounted) {
        transactionListState.jumpToMonth(targetMonth);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJumping = false;
        });
      }
    }
  }

  // 日期头部可见性变化
  void _onHeaderVisibilityChanged(String dateKey, bool isVisible) {
    if (_isJumping) return;

    if (isVisible) {
      _visibleHeaders.add(dateKey);
    } else {
      _visibleHeaders.remove(dateKey);
    }

    // 防抖更新月份
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _updateCurrentMonth();
    });
  }

  // 更新当前月份
  void _updateCurrentMonth() {
    if (_isJumping || !mounted || _visibleHeaders.isEmpty) return;

    try {
      // 获取最顶部的可见日期头部（按日期排序，取最新的）
      final sortedDates = _visibleHeaders.toList()
        ..sort((a, b) => b.compareTo(a));
      final topDateKey = sortedDates.first;

      final dateParts = topDateKey.split('-');
      if (dateParts.length != 3) return;

      final year = int.parse(dateParts[0]);
      final month = int.parse(dateParts[1]);
      final detectedMonth = DateTime(year, month, 1);

      // 更新选中月份
      final currentSelected = ref.read(selectedMonthProvider);
      if (currentSelected.year != detectedMonth.year ||
          currentSelected.month != detectedMonth.month) {
        ref.read(selectedMonthProvider.notifier).state = detectedMonth;
      }
    } catch (e) {
      // 忽略错误，继续正常运行
    }
  }

  // FlutterListView不需要手动计算偏移量，直接使用jumpToIndex即可！

  // 日期选择处理
  Future<void> _handleDateSelection() async {
    final month = ref.read(selectedMonthProvider);
    final res = await showWheelDatePicker(
      context,
      initial: month,
      mode: WheelDatePickerMode.ym,
      maxDate: DateTime.now(),
    );

    if (res != null) {
      final targetMonth = DateTime(res.year, res.month, 1);
      ref.read(selectedMonthProvider.notifier).state = targetMonth;

      // 使用FlutterListView的精准跳转
      await _jumpToTargetMonth(targetMonth);
    }
  }

  // 构建月初提醒卡片
  Widget _buildLastMonthReminderCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final monthFormat = DateFormat.MMMM(l10n.localeName);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 左侧装饰条
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: primaryColor,
              ),
            ),
            // 主体内容
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  // 文案
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: monthFormat.format(lastMonth),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ${l10n.homeLastMonthReportSubtitle}',
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 查看按钮（查看后本次隐藏，下次打开app还会显示）
                  GestureDetector(
                    onTap: () {
                      SharePosterService.showPosterCarouselPreview(
                        context,
                        year: lastMonth.year,
                        month: lastMonth.month,
                      );
                      // 只临时隐藏，不保存到 prefs
                      setState(() {
                        _showLastMonthReminder = false;
                      });
                    },
                    child: Text(
                      l10n.homeLastMonthReportView,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 关闭按钮（关闭后当月不再显示）
                  GestureDetector(
                    onTap: _dismissLastMonthReminder,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 年度账单提醒卡片（样式与月初提醒一致）
  Widget _buildAnnualReportReminderCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final reportYear = now.month == 1 ? now.year - 1 : now.year;
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 左侧装饰条
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: primaryColor,
              ),
            ),
            // 主体内容
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  // 文案
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_graph_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.homeAnnualReportReminder(reportYear),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 查看按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AnnualReportPage(initialYear: reportYear),
                        ),
                      );
                      // 临时隐藏
                      setState(() {
                        _showAnnualReportReminder = false;
                      });
                    },
                    child: Text(
                      l10n.homeAnnualReportView,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 关闭按钮
                  GestureDetector(
                    onTap: _dismissAnnualReportReminder,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 预算设置引导卡片（无预算时显示，样式与月初提醒一致）
  Widget _buildBudgetSetupHintCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // 左侧装饰条
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: primaryColor,
              ),
            ),
            // 主体内容
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  // 图标 + 文案
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.pie_chart_outline_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.budgetSetupHint,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 去设置按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BudgetPage()),
                      );
                    },
                    child: Text(
                      l10n.budgetSetupAction,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 关闭按钮
                  GestureDetector(
                    onTap: _dismissBudgetSetupHint,
                    behavior: HitTestBehavior.opaque,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark ? Colors.white38 : Colors.black26,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    // 预加载数据（含标签、附件、账户，仅前 N 条）
    final cachedFullData = ref.watch(cachedTransactionsProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final hide = ref.watch(hideAmountsProvider);
    final aiEnabledAsync = ref.watch(aiAssistantEnabledProvider);
    final aiEnabled = aiEnabledAsync.asData?.value ?? true; // 默认开启

    // 检测账本切换，强制刷新 StreamBuilder 并清空缓存
    if (_lastLedgerId != null && _lastLedgerId != ledgerId) {
      _streamBuilderKey++;
      // 清空缓存，避免显示旧账本数据
      Future.microtask(() {
        ref.read(cachedTransactionsProvider.notifier).state = null;
      });
      logger.info('HomePage',
          '账本切换: $_lastLedgerId → $ledgerId, 刷新StreamBuilder (key=$_streamBuilderKey)');
    }
    _lastLedgerId = ledgerId;

    // 监听滚动到顶部的信号
    ref.listen<int>(homeScrollToTopProvider, (previous, next) {
      if (previous != next) {
        // 滚动到列表顶部
        _transactionListKey.currentState?.jumpToTop();
      }
    });

    // 监听切换到 Stream 模式的信号
    ref.listen<int>(homeSwitchToStreamProvider, (previous, next) {
      if (previous != next) {
        _transactionListKey.currentState?.switchToStreamMode();
      }
    });

    // D 方案后:Drift JOIN + SharedLedger* table-watch 已经在 Repository 层
    // 自动响应共享资源变化(分类 / 账户),tx stream 会重 emit 出带新 name
    // 的记录。不再需要在 HomePage 强制 _streamBuilderKey++ / invalidate
    // accountForTxProvider 这种激进刷新 — 那会让 Editor 编辑 tx 的本地
    // push-pull 循环触发整个 StreamBuilder 子树重建("首页全局刷新"症状)。
    // 如果有 forceStreamModeImmediate 的语义需要(强制把 preloaded 切到
    // live stream),可以单独 listen sharedResourceRefreshProvider 处理,
    // 但 StreamBuilder key 重建保持不动。
    ref.listen<int>(sharedResourceRefreshProvider, (previous, next) {
      if (previous != next) {
        _transactionListKey.currentState?.forceStreamModeImmediate();
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ⭐ 自适应背景色
      body: Column(
        children: [
          Consumer(builder: (context, ref, _) {
            ref.watch(headerStyleProvider);
            final hide = ref.watch(hideAmountsProvider);
            return PrimaryHeader(
              title: '',
              showTitleSection: false,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 头部 - 左: BeeIcon + 账本切换, 右: 操作按钮
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        // 左侧：BeeIcon + 标题 + 账本切换胶囊（用 Expanded 包住，
                        // 标题在空间富余时显示自然宽度，仅在不够时 ellipsis）
                        BeeIcon(
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Row(
                            children: [
                              // 标题取自然宽度,溢出时优先压缩账本名而不是 app 名
                              Text(
                                AppLocalizations.of(context).homeAppTitle,
                                maxLines: 1,
                                softWrap: false,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Consumer(builder: (context, ref, _) {
                                    final currentLedger =
                                        ref.watch(currentLedgerProvider);
                                    return currentLedger.when(
                                      data: (ledger) => GestureDetector(
                                        onTap: () => showLedgerPicker(context),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                        .brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                    .withValues(alpha: 0.1)
                                                : Colors.black
                                                    .withValues(alpha: 0.05),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  ledger?.name == null
                                                      ? ''
                                                      : translateLedgerName(
                                                          context,
                                                          ledger!.name),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  softWrap: false,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.color,
                                                  ),
                                                ),
                                              ),
                                              // v24 共享账本:header 也显示 🤝 角标 + 成员数
                                              if (ledger != null && ledger.isShared) ...[
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.handshake,
                                                  size: 12,
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.color
                                                      ?.withOpacity(0.7),
                                                ),
                                                const SizedBox(width: 1),
                                                Text(
                                                  '${ledger.memberCount}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color
                                                        ?.withOpacity(0.7),
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 16,
                                                color: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.color
                                                    ?.withOpacity(0.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      loading: () => const SizedBox.shrink(),
                                      error: (_, __) => const SizedBox.shrink(),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 右侧操作按钮
                        if (aiEnabled)
                          IconButton(
                            tooltip: AppLocalizations.of(context).aiChatTitle,
                            padding: const EdgeInsets.all(8),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                            ),
                            onPressed: () {
                              _transactionListKey.currentState
                                  ?.switchToStreamMode();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AIChatPage(),
                                ),
                              );
                            },
                            icon: Icon(
                              Icons.auto_awesome_outlined,
                              size: 20,
                              color: Theme.of(context).iconTheme.color,
                            ),
                          ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).calendarTitle,
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CalendarPage(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.calendar_month_outlined,
                            size: 20,
                            color: Theme.of(context).iconTheme.color,
                          ),
                        ),
                        IconButton(
                          tooltip: AppLocalizations.of(context).homeSearch,
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            minimumSize: Size.zero,
                          ),
                          onPressed: () {
                            _transactionListKey.currentState
                                ?.switchToStreamMode();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const SearchPage(),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.search,
                            size: 20,
                            color: Theme.of(context).iconTheme.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 第二行 - 月份显示和统计
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _isJumping ? null : _handleDateSelection,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                AppLocalizations.of(context)
                                    .homeYear(month.year),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withOpacity(0.6), // ⭐ 自适应次要文字颜色
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context).homeMonth(
                                      month.month.toString().padLeft(2, '0')),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color, // ⭐ 自适应主文字颜色
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                // 月份旁边的向下三角形（日期选择）
                                _isJumping
                                    ? SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color, // ⭐ 自适应颜色
                                        ),
                                      )
                                    : Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withOpacity(0.6), // ⭐ 自适应次要颜色
                                      ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 36,
                        color: Theme.of(context).dividerTheme.color ??
                            Theme.of(context).dividerColor, // ⭐ 自适应分割线颜色
                      ),
                      const Expanded(child: _HeaderCenterSummary()),
                    ],
                  ),
                ],
              ),
              bottom: const HomeBudgetSummary(),
            );
          }),
          const SizedBox(height: 0),
          // 月初提醒卡片
          if (_showLastMonthReminder) _buildLastMonthReminderCard(context),
          // 年度账单提醒卡片（12月15日 - 次年1月31日）
          if (_showAnnualReportReminder)
            _buildAnnualReportReminderCard(context),
          // 预算设置引导卡片（无预算 + 未关闭过）
          Consumer(builder: (context, ref, _) {
            final overviewAsync = ref.watch(budgetOverviewProvider);
            final hasBudget = overviewAsync.when(
              data: (overview) =>
                  overview != null && overview.totalBudget != null,
              loading: () => true, // loading 时不显示引导
              error: (_, __) => true, // 出错时不显示引导
            );
            if (!hasBudget && _showBudgetSetupHint) {
              return _buildBudgetSetupHintCard(context);
            }
            return const SizedBox.shrink();
          }),
          Expanded(
            child: StreamBuilder<List<({Transaction t, Category? category, Account? account, Account? toAccount})>>(
              key: ValueKey('transactions_$_streamBuilderKey'), // 使用递增key强制重建
              stream: repo.transactionsWithCategoryAll(ledgerId: ledgerId),
              builder: (context, snapshot) {
                // Stream 数据到来前，使用预加载数据；到来后使用 Stream 数据
                final streamData = snapshot.data;
                final hasStreamData =
                    streamData != null && streamData.isNotEmpty;

                // 如果 Stream 没数据，从预加载数据构建基础列表
                final transactions = hasStreamData
                    ? streamData
                    : (cachedFullData
                            ?.map((item) => (
                                  t: item.t,
                                  category: item.category,
                                  account: item.account,
                                  toAccount: item.toAccount,
                                ))
                            .toList() ??
                        []);

                return TransactionList(
                  key: _transactionListKey,
                  transactions: transactions,
                  // 传入预加载数据供详情使用（标签、附件、账户）
                  transactionsWithDetails: cachedFullData,
                  hideAmounts: hide,
                  enableVisibilityTracking: true,
                  onDateVisibilityChanged: _onHeaderVisibilityChanged,
                  controller: _listController,
                  emptyWidget: AppEmpty(
                    text: AppLocalizations.of(context).homeNoRecords,
                    subtext: AppLocalizations.of(context).homeNoRecordsSubtext,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCenterSummary extends ConsumerWidget {
  const _HeaderCenterSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final params = (ledgerId: ledgerId, month: month);

    ref.watch(monthlyTotalsProvider(params));
    final cachedTotals = ref.watch(lastMonthlyTotalsProvider(params));
    final (income, expense) = cachedTotals ?? (0.0, 0.0);
    final balance = income - expense;

    final amountStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ) ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        );

    Widget item(String title, double value) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                textAlign: TextAlign.left, style: BeeTextTokens.label(context)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AmountText(
                value: value,
                signed: false,
                decimals: 2,
                style: amountStyle,
              ),
            ),
          ],
        );
    return Row(
      children: [
        Expanded(child: item(AppLocalizations.of(context).homeIncome, income)),
        const SizedBox(width: 4),
        Expanded(
            child: item(AppLocalizations.of(context).homeExpense, expense)),
        const SizedBox(width: 4),
        Expanded(
            child: item(AppLocalizations.of(context).homeBalance, balance)),
      ],
    );
  }
}

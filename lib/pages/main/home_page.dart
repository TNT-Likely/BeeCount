import '../../presentation/v4/bindings/page_scaffold.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../presentation/v4/gallery/component_gallery_page.dart';
import '../../presentation/v4/bindings/home_reminders.dart';
import '../../presentation/v4/bindings/home_overview.dart';
import '../../presentation/v4/bindings/home_journal.dart';
import '../../presentation/v4/bindings/home_transaction_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'dart:async';
import '../budget/budget_page.dart';
import '../../providers.dart';
import '../../presentation/v4/bindings/home_header.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../transaction/search_page.dart';
import '../ai/ai_chat_page.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/month_range.dart';
import '../../services/export/share_poster_service.dart';
import '../report/annual_report_page.dart';
import '../calendar/calendar_page.dart';
import '../../widgets/biz/ledger_picker_sheet.dart';
import 'ledgers_page_new.dart';
import '../../providers/shared_ledger_providers.dart';
import '../../providers/home_startup_preview_provider.dart';

// 优化版首页 - 使用FlutterListView实现精准定位和丝滑跳转
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late FlutterListViewController _listController;
  HomeStartupPreview? _startupPreview;
  final _pageScrollController = ScrollController();
  // The note keyboard can move Home across BeeHomeLayout's compact boundary.
  // Keep the journal subtree (and its single-subscription stream) mounted when
  // its parent changes between the fixed and scrolling layouts.
  final _journalFrameKey = GlobalKey();
  bool _isJumping = false;
  final GlobalKey<TransactionListState> _transactionListKey =
      GlobalKey<TransactionListState>();

  // 可见性管理
  final Set<String> _visibleHeaders = {}; // 当前可见的日期头部
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _listController = FlutterListViewController();
    _startupPreview = ref
        .read(homeStartupPreviewHandoffProvider)
        .take(ref.read(repositoryProvider), ref.read(currentLedgerIdProvider));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The first child build has received the handoff. A later subtree
      // remount must read fresh data instead of replaying these startup rows.
      _startupPreview = null;
    });
  }

  void _openAIChat() {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AIChatPage()),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _listController.dispose();
    _pageScrollController.dispose();
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
        transactionListState.jumpToMonth(
          targetMonth,
          startDay: ref.read(currentMonthStartDayProvider),
        );
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
    if (!mounted || _isJumping) return;

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
      final day = int.parse(dateParts[2]);
      // 交易日期 → 它所属周期的标签月(startDay>1 时月初几天属上个标签月)
      final sd = ref.read(currentMonthStartDayProvider);
      final detectedMonth = labelForDate(DateTime(year, month, day), sd);

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

  void _openJournalSearch({bool batch = false, bool filters = false}) {
    _transactionListKey.currentState?.switchToStreamMode();
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SearchPage(
                initialBatchMode: batch, initialOpenFilter: filters)));
  }

  void _openHomeTool(String value) {
    final month = ref.read(selectedMonthProvider);
    switch (value) {
      case 'calendar':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const CalendarPage()));
      case 'annual':
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    AnnualReportPage(initialYear: DateTime.now().year)));
      case 'share':
        SharePosterService.showPosterCarouselPreview(context,
            year: month.year, month: month.month);
      case 'ledgers':
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LedgersPageNew()));
      case 'components':
        if (kDebugMode) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ComponentGalleryPage()));
        }
      case 'theme':
        if (kDebugMode) {
          final current = ref.read(themeModeProvider);
          ref.read(themeModeProvider.notifier).state =
              current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
        }
      case 'brand':
        unawaited(
            setHomeBrandVisible(ref, !ref.read(homeBrandVisibleProvider)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final hide = ref.watch(hideAmountsProvider);
    final initialPreview =
        _startupPreview?.matches(ref.watch(repositoryProvider), ledgerId) ==
                true
            ? _startupPreview
            : null;

    // 监听滚动到顶部的信号
    ref.listen<int>(homeScrollToTopProvider, (previous, next) {
      if (previous != next) {
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
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

    return V4PageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ⭐ 自适应背景色
      body: BeeHomeLayout(
        controller: _pageScrollController,
        header: HomeHeaderBinding(
            jumping: _isJumping,
            onMonth: _handleDateSelection,
            onAI: _openAIChat,
            onSearch: _openJournalSearch,
            onTool: _openHomeTool,
            onLedger: () {
              final ledger = ref.read(currentLedgerProvider).valueOrNull;
              if (ledger == null) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            const LedgersPageNew(autoOpenCreateDialog: true)));
              } else {
                showLedgerPicker(context);
              }
            }),
        reminders: HomeReminders(
            onMonthly: (month) => SharePosterService.showPosterCarouselPreview(
                context,
                year: month.year,
                month: month.month),
            onAnnual: (year) => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AnnualReportPage(initialYear: year))),
            onBudget: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BudgetPage()))),
        journal: HomeJournalFrame(
            key: _journalFrameKey,
            initialPreview: initialPreview?.preview,
            onCalendar: () => _openHomeTool('calendar'),
            onFilter: () => _openJournalSearch(filters: true),
            onBatch: () => _openJournalSearch(batch: true),
            childBuilder: (onPreviewReady) => HomeTransactionFeed(
                  startupPreview: initialPreview,
                  onPreviewReady: onPreviewReady,
                  ledgerId: ledgerId,
                  hideAmounts: hide,
                  listKey: _transactionListKey,
                  controller: _listController,
                  onDateVisibilityChanged: _onHeaderVisibilityChanged,
                  emptyWidget: BeeEmptyState(
                    title: AppLocalizations.of(context).homeNoRecords,
                    message: AppLocalizations.of(context).homeNoRecordsSubtext,
                  ),
                )),
      ),
    );
  }
}

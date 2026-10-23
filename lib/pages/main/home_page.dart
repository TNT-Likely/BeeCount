import 'package:flutter/foundation.dart' show kDebugMode;
import '../../presentation/v4/gallery/component_gallery_page.dart';
import '../../presentation/v4/bindings/home_reminders.dart';
import '../../presentation/v4/bindings/home_overview.dart';
import '../../presentation/v4/bindings/home_journal.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'dart:async';
import '../budget/budget_page.dart';
import '../../providers.dart';
import '../settings/personalize_page.dart' show headerStyleProvider;
import '../../data/db.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../transaction/search_page.dart';
import '../ai/ai_chat_page.dart';
import '../../l10n/app_localizations.dart';
import '../../services/system/logger_service.dart';
import '../../utils/month_range.dart';
import '../../services/export/share_poster_service.dart';
import '../report/annual_report_page.dart';
import '../calendar/calendar_page.dart';
import '../../widgets/biz/ledger_picker_sheet.dart';
import 'ledgers_page_new.dart';
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

  // home build 缓存的 tx stream。repo.transactionsWithCategoryAll 内部每次调
  // 都 new StreamController,如果在 build 里直接调,只要 home 因任何 setState
  // (例如主题或金额隐私偏好变化)重 build,
  // StreamBuilder 看到 stream 引用变了就重新订阅 → snapshot.data 短暂为 null
  // → fallback 到 cachedFullData(只有前 20 条预加载)→ 等 Drift 推数据 → 切回
  // 完整列表,视觉上"整页闪一下"。这里把 stream 缓存到 State,只在 ledgerId
  // 变化时重建,无关 setState 重 build 时复用同一 stream 引用。
  Stream<
      List<
          ({
            Transaction t,
            Category? category,
            Account? account,
            Account? toAccount
          })>>? _txStream;
  int? _txStreamLedgerId;

  @override
  void initState() {
    super.initState();
    _listController = FlutterListViewController();
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
    final repo = ref.watch(repositoryProvider);
    // 预加载数据（含标签、附件、账户，仅前 N 条）
    final cachedFullData = ref.watch(cachedTransactionsProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
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
            return PrimaryHeader(
              title: '',
              showTitleSection: false,
              padding: const EdgeInsets.fromLTRB(17, 6, 17, 8),
              content: HomeOverview(
                jumping: _isJumping,
                onMonthTap: _handleDateSelection,
                onLedgerTap: () {
                  final ledger = ref.read(currentLedgerProvider).valueOrNull;
                  if (ledger == null) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LedgersPageNew(
                                autoOpenCreateDialog: true)));
                  } else {
                    showLedgerPicker(context);
                  }
                },
                actions: [
                  if (aiEnabled)
                    Tooltip(
                        message: AppLocalizations.of(context).aiChatTitle,
                        child: TextButton.icon(
                            onPressed: _openAIChat,
                            style: TextButton.styleFrom(
                                minimumSize: const Size(40, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                foregroundColor: Color.lerp(
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.onSurface,
                                    .4)),
                            icon: const BeeLineIcon('Sparkles', size: 18),
                            label: const Text('AI',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)))),
                  BeeIconButton(
                      label: AppLocalizations.of(context).homeSearch,
                      icon: const BeeLineIcon('Search', size: 21),
                      onPressed: _openJournalSearch),
                  BeePopupMenu(
                      tooltip: AppLocalizations.of(context).commonMore,
                      icon: const BeeLineIcon('Ellipsis', size: 21),
                      items: [
                        BeeMenuItem.action(
                            value: 'calendar',
                            icon: Icons.calendar_month_outlined,
                            label: AppLocalizations.of(context).calendarTitle),
                        BeeMenuItem.action(
                            value: 'share',
                            icon: Icons.image_outlined,
                            label:
                                AppLocalizations.of(context).v4HomeMonthShare),
                        BeeMenuItem.action(
                            value: 'annual',
                            icon: Icons.insights_outlined,
                            label:
                                AppLocalizations.of(context).annualReportTitle),
                        BeeMenuItem.action(
                            value: 'ledgers',
                            icon: Icons.menu_book_outlined,
                            label:
                                AppLocalizations.of(context).homeManageLedgers),
                        BeeMenuItem.action(
                            value: 'brand',
                            icon: Icons.hive_outlined,
                            label: ref.watch(homeBrandVisibleProvider)
                                ? AppLocalizations.of(context).v4HomeBrandHide
                                : AppLocalizations.of(context).v4HomeBrandShow),
                        if (kDebugMode &&
                            const bool.fromEnvironment(
                                'BEECOUNT_V4_RECORDING')) ...[
                          const BeeMenuItem.divider(),
                          const BeeMenuItem.action(
                              value: 'components',
                              icon: Icons.widgets_outlined,
                              label: 'V4 组件验收'),
                          const BeeMenuItem.action(
                              value: 'theme',
                              icon: Icons.brightness_6_outlined,
                              label: '切换深浅色'),
                        ],
                      ],
                      onSelected: _openHomeTool),
                ],
              ),
            );
          }),
          HomeReminders(
              onMonthly: (month) =>
                  SharePosterService.showPosterCarouselPreview(context,
                      year: month.year, month: month.month),
              onAnnual: (year) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AnnualReportPage(initialYear: year))),
              onBudget: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BudgetPage()))),
          Expanded(
            child: HomeJournalFrame(
                onCalendar: () => _openHomeTool('calendar'),
                onFilter: () => _openJournalSearch(filters: true),
                onBatch: () => _openJournalSearch(batch: true),
                child: StreamBuilder<
                    List<
                        ({
                          Transaction t,
                          Category? category,
                          Account? account,
                          Account? toAccount
                        })>>(
                  key: ValueKey(
                      'transactions_$_streamBuilderKey'), // 使用递增key强制重建
                  stream: () {
                    // ledgerId 变了或第一次进来才重建 stream;无关 setState(预算
                    // 提示卡片、月度提醒等)的 home rebuild 复用同一 stream 引用,
                    // StreamBuilder 不会重新订阅,不会闪到 fallback 数据。
                    if (_txStream == null || _txStreamLedgerId != ledgerId) {
                      _txStream =
                          repo.transactionsWithCategoryAll(ledgerId: ledgerId);
                      _txStreamLedgerId = ledgerId;
                    }
                    return _txStream;
                  }(),
                  builder: (context, snapshot) {
                    // Stream 数据到来前，使用预加载数据；到来后使用 Stream 数据
                    final streamData = snapshot.data;
                    final hasStreamData = streamData != null;

                    // 如果 Stream 没数据，从预加载数据构建基础列表
                    final transactions = hasStreamData
                        ? streamData
                        : (cachedFullData
                                ?.where((item) => item.t.ledgerId == ledgerId)
                                .map((item) => (
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
                      flatSurface: true,
                      enableVisibilityTracking: true,
                      onDateVisibilityChanged: _onHeaderVisibilityChanged,
                      controller: _listController,
                      emptyWidget: AppEmpty(
                        text: AppLocalizations.of(context).homeNoRecords,
                        subtext:
                            AppLocalizations.of(context).homeNoRecordsSubtext,
                      ),
                    );
                  },
                )),
          ),
        ],
      ),
    );
  }
}

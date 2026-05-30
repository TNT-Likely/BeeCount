import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart' as db;
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/biz.dart';
import '../../styles/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../utils/currencies.dart';
import '../../widgets/category_icon.dart';
import '../../utils/account_type_utils.dart';
import '../../widgets/charts/account_category_pie_chart.dart';
import '../transaction/transaction_editor_page.dart';
import 'account_edit_page.dart';

// ============================================
// Providers
// ============================================

/// 分页交易状态
class AccountTransactionsPaginationState {
  final List<db.Transaction> transactions;
  final bool isLoading;
  final bool hasMore;

  const AccountTransactionsPaginationState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
  });

  AccountTransactionsPaginationState copyWith({
    List<db.Transaction>? transactions,
    bool? isLoading,
    bool? hasMore,
  }) {
    return AccountTransactionsPaginationState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class AccountTransactionsPaginationNotifier
    extends StateNotifier<AccountTransactionsPaginationState> {
  final Ref ref;
  final int accountId;
  static const _pageSize = 50;

  AccountTransactionsPaginationNotifier(this.ref, this.accountId)
      : super(const AccountTransactionsPaginationState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions =
          await repo.getAccountTransactions(accountId, limit: _pageSize, offset: 0);
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions = await repo.getAccountTransactions(
        accountId,
        limit: _pageSize,
        offset: state.transactions.length,
      );
      state = state.copyWith(
        transactions: [...state.transactions, ...transactions],
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    state = const AccountTransactionsPaginationState(isLoading: true);
    try {
      final repo = ref.read(repositoryProvider);
      final transactions =
          await repo.getAccountTransactions(accountId, limit: _pageSize, offset: 0);
      state = AccountTransactionsPaginationState(
        transactions: transactions,
        isLoading: false,
        hasMore: transactions.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

final accountTransactionsPaginatedProvider = StateNotifierProvider.family
    .autoDispose<AccountTransactionsPaginationNotifier,
        AccountTransactionsPaginationState, int>(
  (ref, accountId) => AccountTransactionsPaginationNotifier(ref, accountId),
);

/// 分类统计 Provider
final accountCategoryStatsProvider = FutureProvider.family
    .autoDispose<List<({int? id, String name, String? icon, double total})>,
        ({int accountId, String type})>((ref, params) async {
  final repo = ref.watch(repositoryProvider);
  return repo.getAccountCategoryStats(params.accountId, type: params.type);
});

// ============================================
// Page
// ============================================

/// 账户详情页面
class AccountDetailPage extends ConsumerStatefulWidget {
  final db.Account account;

  const AccountDetailPage({
    super.key,
    required this.account,
  });

  @override
  ConsumerState<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends ConsumerState<AccountDetailPage> {
  final ScrollController _scrollController = ScrollController();
  /// 详情页图表 tab: 0=支出分布, 1=收入分布
  int _detailChartTab = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(accountTransactionsPaginatedProvider(widget.account.id).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final statsAsync = ref.watch(accountStatsProvider(widget.account.id));
    final paginationState =
        ref.watch(accountTransactionsPaginatedProvider(widget.account.id));
    // 货币符号跟随账户(每个账户有自己的 currency 字段),不是账本 —
    // 用户在一个 CNY 账本里可能有 USD 账户,详情页应显示账户自己的 $。
    final currencyCode = widget.account.currency;
    final categoriesAsync = ref.watch(categoriesProvider);

    // 分类统计数据
    final expenseStatsAsync = ref.watch(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'expense')));
    final incomeStatsAsync = ref.watch(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'income')));

    final account = widget.account;
    final isDark = BeeTokens.isDark(context);
    final typeColor = getColorForAccountType(account.type, primaryColor);
    final isValuation = isValuationOnlyType(account.type);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          // ======== 简洁头部 ========
          PrimaryHeader(
            title: account.name,
            subtitle: getAccountTypeLabel(context, account.type),
            showBack: true,
            compact: true,
            actions: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: BeeTokens.iconPrimary(context),
                  size: 20,
                ),
                onPressed: () async {
                  final currentLedger = ref.read(currentLedgerProvider).asData?.value;
                  if (currentLedger == null) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AccountEditPage(
                        account: account,
                        ledgerId: currentLedger.id,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            ],
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                if (isValuation) ...[
                  // 估值账户：显示估值卡片
                  _buildValuationCard(context, ref, account, statsAsync, currencyCode, primaryColor, l10n),
                ] else ...[
                  // 可交易账户：余额/收入/支出统计卡片
                  _buildStatsCard(context, ref, account, statsAsync, currencyCode, l10n),
                  SizedBox(height: 4.0.scaled(context, ref)),
                  // 账户概览卡片（合并 metadata + 类型统计）
                  _buildOverviewCard(
                    context, ref, account, statsAsync,
                    currencyCode, primaryColor, typeColor, l10n,
                  ),

                  SizedBox(height: 8.0.scaled(context, ref)),

                  // 图表区域（支出分布/收入分布 切换）
                  _buildDetailChartSection(
                    context, ref, l10n, primaryColor,
                    expenseStatsAsync, incomeStatsAsync, typeColor,
                  ),

                  SizedBox(height: 12.0.scaled(context, ref)),

                  // 交易列表（分页）
                  _buildTransactionList(
                    context,
                    paginationState,
                    currencyCode,
                    primaryColor,
                    categoriesAsync.asData?.value ?? [],
                    l10n,
                    typeColor,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 余额/收入/支出统计卡片
  Widget _buildStatsCard(
    BuildContext context,
    WidgetRef ref,
    db.Account account,
    AsyncValue<({double balance, double income, double expense})> statsAsync,
    String currencyCode,
    AppLocalizations l10n,
  ) {
    return SectionCard(
      margin: EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
      child: statsAsync.when(
        data: (stats) => Row(
          children: [
            Expanded(
              child: _DetailStatCell(
                label: account.type == 'credit_card'
                    ? l10n.creditCardOwed
                    : l10n.accountBalance,
                value: stats.balance,
                currencyCode: currencyCode,
              ),
            ),
            Container(
              width: 1,
              height: 36.0.scaled(context, ref),
              color: BeeTokens.divider(context),
            ),
            Expanded(
              child: _DetailStatCell(
                label: l10n.homeIncome,
                value: stats.income,
                currencyCode: currencyCode,
              ),
            ),
            Container(
              width: 1,
              height: 36.0.scaled(context, ref),
              color: BeeTokens.divider(context),
            ),
            Expanded(
              child: _DetailStatCell(
                label: l10n.homeExpense,
                value: stats.expense,
                currencyCode: currencyCode,
              ),
            ),
          ],
        ),
        loading: () => SizedBox(
          height: 60.0.scaled(context, ref),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  /// 估值账户专属卡片
  Widget _buildValuationCard(
    BuildContext context,
    WidgetRef ref,
    db.Account account,
    AsyncValue<({double balance, double income, double expense})> statsAsync,
    String currencyCode,
    Color primaryColor,
    AppLocalizations l10n,
  ) {
    final isLiability = isLiabilityType(account.type);
    final valueLabel = isLiability ? l10n.valuationCurrentDebt : l10n.valuationCurrentValue;
    final updateLabel = isLiability ? l10n.valuationUpdateDebt : l10n.valuationUpdateValue;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20.0.scaled(context, ref)),
          child: Column(
            children: [
              // 类型图标
              AccountTypeIcon(
                type: account.type,
                size: 48.0.scaled(context, ref),
              ),
              SizedBox(height: 12.0.scaled(context, ref)),
              // 标签
              Text(
                valueLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: BeeTokens.textSecondary(context),
                ),
              ),
              SizedBox(height: 6.0.scaled(context, ref)),
              // 金额
              statsAsync.when(
                data: (stats) => AmountText(
                  value: isLiability ? stats.balance.abs() : stats.balance,
                  signed: false,
                  showCurrency: true,
                  useCompactFormat: ref.watch(compactAmountProvider),
                  currencyCode: currencyCode,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                loading: () => SizedBox(
                  height: 36.0.scaled(context, ref),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const Text('-'),
              ),
              SizedBox(height: 8.0.scaled(context, ref)),
              // 上次更新时间
              if (account.updatedAt != null)
                Text(
                  l10n.valuationLastUpdated(
                    '${account.updatedAt!.year}-${account.updatedAt!.month.toString().padLeft(2, '0')}-${account.updatedAt!.day.toString().padLeft(2, '0')}',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              // 备注
              if (account.note != null && account.note!.isNotEmpty) ...[
                SizedBox(height: 8.0.scaled(context, ref)),
                Text(
                  account.note!,
                  style: TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: 16.0.scaled(context, ref)),
              // 更新估值按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showUpdateValuationDialog(
                    context, ref, account, isLiability, currencyCode, l10n,
                  ),
                  icon: Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                  label: Text(updateLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 12.0.scaled(context, ref)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 更新估值弹窗
  Future<void> _showUpdateValuationDialog(
    BuildContext context,
    WidgetRef ref,
    db.Account account,
    bool isLiability,
    String currencyCode,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController(
      text: account.initialBalance.abs().toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) {
        final primaryColor = ref.watch(primaryColorProvider);
        return AlertDialog(
          title: Text(isLiability ? l10n.valuationUpdateDebt : l10n.valuationUpdateValue),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              prefixText: '${getCurrencySymbol(currencyCode)} ',
              hintText: isLiability ? l10n.valuationDebtHint : l10n.valuationAccountHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                final value = double.tryParse(controller.text.trim());
                if (value != null) {
                  Navigator.pop(ctx, value);
                }
              },
              style: TextButton.styleFrom(foregroundColor: primaryColor),
              child: Text(l10n.commonOk),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result != null) {
      final repo = ref.read(repositoryProvider);
      // 贷款存储为负数
      final storedValue = isLiability ? -result.abs() : result;
      await repo.updateAccountValuation(account.id, storedValue);

      if (mounted) {
        // 刷新数据
        ref.invalidate(accountStatsProvider(account.id));
        showToast(context, l10n.commonSave);
        // 返回上一页刷新数据
        Navigator.pop(context, true);
      }
    }
  }

  /// 账户概览卡片（合并 metadata + 类型统计信息）
  Widget _buildOverviewCard(
    BuildContext context,
    WidgetRef ref,
    db.Account account,
    AsyncValue<({double balance, double expense, double income})> statsAsync,
    String currencyCode,
    Color primaryColor,
    Color typeColor,
    AppLocalizations l10n,
  ) {
    final hasMetadata = _hasMetadata(account);
    final hasTypeStats = account.type == 'credit_card';

    if (!hasMetadata && !hasTypeStats) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(12.0.scaled(context, ref)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // metadata 行
              if (hasMetadata) ...[
                _buildMetadataInline(context, account),
                if (hasTypeStats)
                  Divider(height: 20, color: BeeTokens.divider(context)),
              ],
              // 类型专属统计
              if (hasTypeStats)
                statsAsync.when(
                  data: (stats) => _buildTypeStatsInline(
                    context, ref, account, stats, currencyCode, primaryColor, typeColor, l10n,
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// metadata 内联显示
  Widget _buildMetadataInline(BuildContext context, db.Account account) {
    final parts = <String>[];
    if (account.bankName != null && account.bankName!.isNotEmpty) {
      parts.add(account.bankName!);
    }
    if (account.cardLastFour != null && account.cardLastFour!.isNotEmpty) {
      parts.add('**** ${account.cardLastFour!}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join(' · '),
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        if (account.note != null && account.note!.isNotEmpty) ...[
          if (parts.isNotEmpty) const SizedBox(height: 4),
          Text(
            account.note!,
            style: TextStyle(
              fontSize: 12,
              color: BeeTokens.textTertiary(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  /// 类型专属统计内联显示
  Widget _buildTypeStatsInline(
    BuildContext context,
    WidgetRef ref,
    db.Account account,
    ({double balance, double expense, double income}) stats,
    String currencyCode,
    Color primaryColor,
    Color typeColor,
    AppLocalizations l10n,
  ) {
    if (account.type == 'credit_card' && account.creditLimit != null) {
      final creditLimit = account.creditLimit!;
      final usedAmount = stats.balance < 0 ? -stats.balance : 0.0;
      final usageRate = creditLimit > 0 ? (usedAmount / creditLimit).clamp(0.0, 1.0) : 0.0;

      // 计算距还款日天数
      final hasBillingInfo = account.billingDay != null && account.paymentDueDay != null;
      int? daysUntilPayment;
      if (account.paymentDueDay != null) {
        final now = DateTime.now();
        final today = now.day;
        final dueDay = account.paymentDueDay!;
        if (today <= dueDay) {
          daysUntilPayment = dueDay - today;
        } else {
          // 已过本月还款日，算到下月
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          daysUntilPayment = daysInMonth - today + dueDay;
        }
      }

      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _OverviewStatCell(label: l10n.creditLimit, value: creditLimit)),
              Expanded(child: _OverviewStatCell(label: l10n.creditUsed, value: usedAmount)),
              Expanded(child: _OverviewStatCell(label: l10n.creditAvailable, value: creditLimit - usedAmount)),
            ],
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: usageRate,
              backgroundColor: BeeTokens.divider(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                usageRate < 0.5 ? BeeTokens.success(context)
                    : usageRate < 0.8 ? BeeTokens.warning(context)
                    : BeeTokens.error(context),
              ),
              minHeight: 4,
            ),
          ),
          // 账单日/还款日信息
          if (hasBillingInfo || account.paymentDueDay != null) ...[
            SizedBox(height: 10.0.scaled(context, ref)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 10.0.scaled(context, ref),
              ),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8.0.scaled(context, ref)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: primaryColor,
                  ),
                  SizedBox(width: 8.0.scaled(context, ref)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasBillingInfo)
                          Text(
                            l10n.creditCardBillingInfo(account.billingDay!, account.paymentDueDay!),
                            style: TextStyle(
                              fontSize: 12,
                              color: BeeTokens.textSecondary(context),
                            ),
                          ),
                        if (daysUntilPayment != null) ...[
                          if (hasBillingInfo) SizedBox(height: 2.0.scaled(context, ref)),
                          Text(
                            daysUntilPayment == 0
                                ? l10n.creditCardPaymentDueToday
                                : l10n.creditCardDaysUntilPayment(daysUntilPayment),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: daysUntilPayment <= 3
                                  ? BeeTokens.error(context)
                                  : daysUntilPayment <= 7
                                      ? BeeTokens.warning(context)
                                      : primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 8.0.scaled(context, ref)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _quickTransfer(
                context, account,
                toAccountId: account.id,
              ),
              icon: Icon(Icons.payment, size: 16, color: primaryColor),
              label: Text(l10n.creditCardQuickRepay),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// 详情页图表区域（支出分布/收入分布 切换）
  Widget _buildDetailChartSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Color primaryColor,
    AsyncValue<List<({int? id, String name, String? icon, double total})>> expenseStatsAsync,
    AsyncValue<List<({int? id, String name, String? icon, double total})>> incomeStatsAsync,
    Color typeColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0.scaled(context, ref)),
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(12.0.scaled(context, ref)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分段切换器
              Row(
                children: [
                  _DetailChartTab(
                    label: l10n.homeExpense,
                    isSelected: _detailChartTab == 0,
                    primaryColor: primaryColor,
                    onTap: () => setState(() => _detailChartTab = 0),
                  ),
                  SizedBox(width: 6.0.scaled(context, ref)),
                  _DetailChartTab(
                    label: l10n.homeIncome,
                    isSelected: _detailChartTab == 1,
                    primaryColor: primaryColor,
                    onTap: () => setState(() => _detailChartTab = 1),
                  ),
                ],
              ),
              SizedBox(height: 12.0.scaled(context, ref)),
              // 图表内容
              if (_detailChartTab == 0)
                expenseStatsAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return SizedBox(
                        height: 180,
                        child: Center(
                          child: Text('-', style: TextStyle(color: BeeTokens.textTertiary(context))),
                        ),
                      );
                    }
                    return AccountCategoryPieChart(
                      expenseData: data,
                      incomeData: const [],
                      accentColor: primaryColor,
                      embedded: true,
                    );
                  },
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const SizedBox(height: 180),
                )
              else
                incomeStatsAsync.when(
                  data: (data) {
                    if (data.isEmpty) {
                      return SizedBox(
                        height: 180,
                        child: Center(
                          child: Text('-', style: TextStyle(color: BeeTokens.textTertiary(context))),
                        ),
                      );
                    }
                    return AccountCategoryPieChart(
                      expenseData: const [],
                      incomeData: data,
                      accentColor: primaryColor,
                      embedded: true,
                    );
                  },
                  loading: () => const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const SizedBox(height: 180),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasMetadata(db.Account account) {
    return (account.bankName != null && account.bankName!.isNotEmpty) ||
        (account.cardLastFour != null && account.cardLastFour!.isNotEmpty) ||
        (account.note != null && account.note!.isNotEmpty);
  }

  Widget _buildTransactionList(
    BuildContext context,
    AccountTransactionsPaginationState state,
    String currencyCode,
    Color primaryColor,
    List<db.Category> categories,
    AppLocalizations l10n,
    Color typeColor,
  ) {
    final transactions = state.transactions;

    if (transactions.isEmpty && !state.isLoading) {
      return SectionCard(
        child: Padding(
          padding: EdgeInsets.all(32.0.scaled(context, ref)),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48.0.scaled(context, ref),
                  color: BeeTokens.textTertiary(context),
                ),
                SizedBox(height: 8.0.scaled(context, ref)),
                Text(
                  l10n.accountNoTransactions,
                  style: TextStyle(
                    fontSize: 14,
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12.0.scaled(context, ref)),
            child: Row(
              children: [
                Text(
                  l10n.accountTransactionHistory,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (transactions.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.0.scaled(context, ref),
                      vertical: 2.0.scaled(context, ref),
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(10.0.scaled(context, ref)),
                    ),
                    child: Text(
                      '${transactions.length}${state.hasMore ? '+' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...transactions.asMap().entries.map((entry) {
            final index = entry.key;
            final tx = entry.value;

            return Column(
              children: [
                if (index > 0) BeeTokens.cardDivider(context),
                _TransactionTile(
                  transaction: tx,
                  currencyCode: currencyCode,
                  primaryColor: primaryColor,
                  ledgers:
                      ref.watch(ledgersStreamProvider).asData?.value ?? [],
                  categories: categories,
                  currentAccountId: widget.account.id,
                  onTap: () => _editTransaction(context, ref, tx),
                ),
              ],
            );
          }),
          // 加载指示器
          if (state.isLoading)
            Padding(
              padding: EdgeInsets.all(16.0.scaled(context, ref)),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child:
                      CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!state.hasMore && transactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(12.0.scaled(context, ref)),
              child: Center(
                child: Text(
                  l10n.accountNoMoreData,
                  style: TextStyle(
                    fontSize: 12,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editTransaction(
      BuildContext context, WidgetRef ref, db.Transaction tx) async {
    final categoryAsync = tx.categoryId != null
        ? await ref.read(categoriesProvider.future)
        : null;
    final category = categoryAsync?.cast<db.Category?>().firstWhere(
          (c) => c?.id == tx.categoryId,
          orElse: () => null,
        );

    if (!context.mounted) return;
    await TransactionEditUtils.editTransaction(context, ref, tx, category);

    // 刷新数据
    ref.invalidate(accountStatsProvider(widget.account.id));
    ref
        .read(
            accountTransactionsPaginatedProvider(widget.account.id).notifier)
        .refresh();
    ref.invalidate(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'expense')));
    ref.invalidate(accountCategoryStatsProvider(
        (accountId: widget.account.id, type: 'income')));
  }

  void _quickTransfer(
    BuildContext context,
    db.Account account, {
    int? toAccountId,
    int? fromAccountId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditorPage(
          initialKind: 'transfer',
          initialAccountId: fromAccountId,
          initialToAccountId: toAccountId,
          quickAdd: true,
        ),
      ),
    );
  }

}

// ============================================
// 概览统计单元格（新版，用于合并的概览卡片）
// ============================================

class _OverviewStatCell extends ConsumerWidget {
  final String label;
  final double value;

  const _OverviewStatCell({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        AmountText(
          value: value,
          signed: false,
          showCurrency: false,
          useCompactFormat: ref.watch(compactAmountProvider),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: BeeTokens.textPrimary(context),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
      ],
    );
  }
}

// ============================================
// 详情页图表 Tab 切换按钮
// ============================================

class _DetailChartTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _DetailChartTab({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryColor : BeeTokens.border(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? primaryColor : BeeTokens.textSecondary(context),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ============================================
// 时段切换芯片
// ============================================

// ============================================
// Hero 统计单元格（头部用，白色文字）
// ============================================

class _DetailStatCell extends ConsumerWidget {
  final String label;
  final double value;
  final String currencyCode;

  const _DetailStatCell({
    required this.label,
    required this.value,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: BeeTokens.textTertiary(context),
          ),
        ),
        SizedBox(height: 4.0.scaled(context, ref)),
        AmountText(
          value: value,
          signed: false,
          showCurrency: true,
          useCompactFormat: ref.watch(compactAmountProvider),
          currencyCode: currencyCode,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: BeeTokens.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

// ============================================
// 交易列表项
// ============================================

class _TransactionTile extends ConsumerWidget {
  final db.Transaction transaction;
  final String currencyCode;
  final Color primaryColor;
  final List<db.Ledger> ledgers;
  final List<db.Category> categories;
  final VoidCallback onTap;
  final int? currentAccountId;

  const _TransactionTile({
    required this.transaction,
    required this.currencyCode,
    required this.primaryColor,
    required this.ledgers,
    required this.categories,
    required this.onTap,
    this.currentAccountId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color amountColor;
    final l10n = AppLocalizations.of(context);
    final transferCategory = ref.watch(transferCategoryProvider).valueOrNull;

    bool isTransferOut = false;
    bool isTransferIn = false;
    if (transaction.type == 'transfer' && currentAccountId != null) {
      isTransferOut = transaction.accountId == currentAccountId;
      isTransferIn = transaction.toAccountId == currentAccountId;
    }

    switch (transaction.type) {
      case 'income':
        amountColor = BeeTokens.incomeColor(context, ref);
        break;
      case 'expense':
        amountColor = BeeTokens.expenseColor(context, ref);
        break;
      case 'transfer':
        amountColor = isTransferOut
            ? BeeTokens.expenseColor(context, ref)
            : BeeTokens.incomeColor(context, ref);
        break;
      default:
        amountColor = BeeTokens.textPrimary(context);
    }

    final category = transaction.type == 'transfer'
        ? transferCategory
        : (transaction.categoryId != null
            ? categories.cast<db.Category?>().firstWhere(
                  (c) => c?.id == transaction.categoryId,
                  orElse: () => null,
                )
            : null);

    String displayTitle;
    String? displaySubtitle;
    String? noteSuffix; // 非转账时，备注接在分类名后面（对齐首页）

    if (transaction.type == 'transfer') {
      if (transaction.note?.isNotEmpty == true) {
        displayTitle = transaction.note!;
      } else {
        displayTitle = l10n.transferTitle;
      }

      if (isTransferOut && transaction.toAccountId != null) {
        final toAccountAsync =
            ref.watch(accountByIdProvider(transaction.toAccountId!));
        final toAccountName = toAccountAsync.value?.name;
        if (toAccountName != null) {
          displaySubtitle = '${l10n.transferToPrefix} $toAccountName';
        }
      } else if (isTransferIn && transaction.accountId != null) {
        final fromAccountAsync =
            ref.watch(accountByIdProvider(transaction.accountId!));
        final fromAccountName = fromAccountAsync.value?.name;
        if (fromAccountName != null) {
          displaySubtitle = '${l10n.transferFromPrefix} $fromAccountName';
        }
      }
    } else {
      // 分类名常驻，备注接在分类名后面（对齐首页 / TransactionListItem）
      displayTitle = category != null
          ? category.name
          : (transaction.type == 'income' ? l10n.homeIncome : l10n.homeExpense);
      if (transaction.note?.isNotEmpty == true && transaction.note != displayTitle) {
        noteSuffix = transaction.note;
      }
    }

    final ledger = ledgers.cast<db.Ledger?>().firstWhere(
          (l) => l?.id == transaction.ledgerId,
          orElse: () => null,
        );
    String ledgerName = ledger?.name ?? '';
    if (ledgerName == 'Default Ledger') {
      ledgerName = l10n.ledgersDefaultLedgerName;
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12.0.scaled(context, ref),
          vertical: 12.0.scaled(context, ref),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: CategoryIconWidget(
                category: category,
                size: 18,
              ),
            ),
            SizedBox(width: 12.0.scaled(context, ref)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            text: displayTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: BeeTokens.textPrimary(context),
                            ),
                            children: [
                              if (noteSuffix != null)
                                TextSpan(
                                  text: '  ($noteSuffix)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: BeeTokens.textSecondary(context),
                                  ),
                                ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (ledgerName.isNotEmpty) ...[
                        SizedBox(width: 6.0.scaled(context, ref)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.0.scaled(context, ref),
                            vertical: 2.0.scaled(context, ref),
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                                4.0.scaled(context, ref)),
                          ),
                          child: Text(
                            ledgerName,
                            style: TextStyle(
                              fontSize: 11,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (displaySubtitle != null)
                    Padding(
                      padding:
                          EdgeInsets.only(top: 2.0.scaled(context, ref)),
                      child: Text(
                        displaySubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        EdgeInsets.only(top: 2.0.scaled(context, ref)),
                    child: Text(
                      _formatDate(transaction.happenedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AmountText(
              value: transaction.type == 'expense'
                  ? -transaction.amount
                  : transaction.type == 'transfer'
                      ? (isTransferOut
                          ? -transaction.amount
                          : transaction.amount)
                      : transaction.amount,
              signed: true,
              showCurrency: false,
              currencyCode: currencyCode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

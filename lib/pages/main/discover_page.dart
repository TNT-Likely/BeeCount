import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/budget_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/data/category_service.dart';
import '../../styles/tokens.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../utils/website_urls.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/ledger_picker_sheet.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/ui/ui.dart';
import '../account/accounts_page.dart';
import '../ai/ai_settings_page.dart';
import '../budget/budget_page.dart';
import '../category/category_manage_page.dart';
import '../data/export_page.dart';
import '../data/import_page.dart';
import '../settings/config_import_export_page.dart';
import '../automation/auto_billing_settings_page.dart';
import '../tag/tag_manage_page.dart';

/// 发现页
///
/// 包含预算管理和账户总览功能入口
class DiscoverPage extends ConsumerWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final primaryColor = ref.watch(primaryColorProvider);
    final currentLedger = ref.watch(currentLedgerProvider);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.discoverTitle,
            showBack: false,
            actions: [
              currentLedger.when(
                data: (ledger) => GestureDetector(
                  onTap: () => showLedgerPicker(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.0.scaled(context, ref),
                      vertical: 6.0.scaled(context, ref),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 14,
                          color: BeeTokens.textPrimary(context),
                        ),
                        SizedBox(width: 4.0.scaled(context, ref)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 80),
                          child: Text(
                            ledger?.name ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: BeeTokens.textPrimary(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 2.0.scaled(context, ref)),
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 14,
                          color: BeeTokens.textPrimary(context)
                              .withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: 12.0.scaled(context, ref),
                vertical: 8.0.scaled(context, ref),
              ),
              children: [
                // 预算管理卡片
                _BudgetCard(primaryColor: primaryColor),
                SizedBox(height: 10.0.scaled(context, ref)),

                // 账户总览卡片
                _AccountsCard(primaryColor: primaryColor),
                SizedBox(height: 10.0.scaled(context, ref)),

                // 快捷记账入口
                _QuickActionsCard(primaryColor: primaryColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 预算卡片组件
class _BudgetCard extends ConsumerWidget {
  final Color primaryColor;

  const _BudgetCard({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overviewAsync = ref.watch(budgetOverviewProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BudgetPage()),
        );
      },
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.0.scaled(context, ref)),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pie_chart_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10.0.scaled(context, ref)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.discoverBudget,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: BeeTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.discoverBudgetSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: BeeTokens.iconTertiary(context),
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 12.0.scaled(context, ref)),
            // 预算内容区域
            overviewAsync.when(
              data: (overview) {
                if (overview == null || overview.totalBudget == null) {
                  return _buildEmptyState(context, ref, l10n);
                }
                return _buildBudgetContent(context, ref, overview, l10n);
              },
              loading: () => _buildEmptyState(context, ref, l10n),
              error: (_, __) => _buildEmptyState(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.0.scaled(context, ref)),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 36,
            color: primaryColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          Text(
            l10n.discoverBudgetEmpty,
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetContent(
    BuildContext context,
    WidgetRef ref,
    BudgetOverview overview,
    AppLocalizations l10n,
  ) {
    final budget = overview.totalBudget!;
    final rate =
        budget.budget > 0 ? (budget.used / budget.budget).clamp(0.0, 1.0) : 0.0;
    final progressColor = _getProgressColor(context, rate);
    final hideAmounts = ref.watch(hideAmountsProvider);

    return Container(
      padding: EdgeInsets.all(12.0.scaled(context, ref)),
      decoration: BoxDecoration(
        color: BeeTokens.scaffoldBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 金额和进度
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              hideAmounts
                  ? Text(
                      '¥****',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: BeeTokens.textPrimary(context),
                      ),
                    )
                  : Text(
                      '¥${budget.used.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: BeeTokens.textPrimary(context),
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: hideAmounts
                    ? Text(
                        ' / ****',
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textTertiary(context),
                        ),
                      )
                    : Text(
                        ' / ¥${budget.budget.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8.0.scaled(context, ref),
                  vertical: 2.0.scaled(context, ref),
                ),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(rate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: progressColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(progressColor),
              minHeight: 6,
            ),
          ),
          SizedBox(height: 6.0.scaled(context, ref)),
          // 剩余天数
          Text(
            l10n.budgetDaysRemaining(overview.daysRemaining),
            style: TextStyle(
              fontSize: 11,
              color: BeeTokens.textTertiary(context),
            ),
          ),
          // 分类预算（最多显示3个）
          if (overview.categoryBudgets.isNotEmpty) ...[
            SizedBox(height: 10.0.scaled(context, ref)),
            _buildCategoryBudgets(context, ref, overview.categoryBudgets),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryBudgets(
    BuildContext context,
    WidgetRef ref,
    List<CategoryBudgetUsage> categoryBudgets,
  ) {
    // 只显示前3个
    final displayBudgets = categoryBudgets.take(3).toList();

    return Column(
      children: [
        for (var i = 0; i < displayBudgets.length; i++) ...[
          if (i > 0) SizedBox(height: 6.0.scaled(context, ref)),
          _buildCategoryBudgetItem(context, ref, displayBudgets[i]),
        ],
        if (categoryBudgets.length > 3) ...[
          SizedBox(height: 4.0.scaled(context, ref)),
          Text(
            '+${categoryBudgets.length - 3}',
            style: TextStyle(
              fontSize: 11,
              color: BeeTokens.textTertiary(context),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryBudgetItem(
    BuildContext context,
    WidgetRef ref,
    CategoryBudgetUsage usage,
  ) {
    final rate = usage.usage.budget > 0
        ? (usage.usage.used / usage.usage.budget).clamp(0.0, 1.0)
        : 0.0;
    final color = _getProgressColor(context, rate);
    final hideAmounts = ref.watch(hideAmountsProvider);

    return Row(
      children: [
        Container(
          width: 24.0.scaled(context, ref),
          height: 24.0.scaled(context, ref),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            CategoryService.getCategoryIcon(usage.categoryIcon),
            size: 14.0.scaled(context, ref),
            color: primaryColor,
          ),
        ),
        SizedBox(width: 8.0.scaled(context, ref)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    usage.categoryName,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  hideAmounts
                      ? Text(
                          '****',
                          style: TextStyle(
                            fontSize: 11,
                            color: BeeTokens.textSecondary(context),
                          ),
                        )
                      : Text(
                          '¥${usage.usage.used.toStringAsFixed(0)}/${usage.usage.budget.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                ],
              ),
              SizedBox(height: 3.0.scaled(context, ref)),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: rate,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(BuildContext context, double rate) {
    if (rate >= 1.0) return BeeTokens.error(context);
    if (rate >= 0.9) return BeeTokens.error(context);
    if (rate >= 0.7) return BeeTokens.warning(context);
    return BeeTokens.success(context);
  }
}

/// 账户总览卡片组件
class _AccountsCard extends ConsumerWidget {
  final Color primaryColor;

  const _AccountsCard({required this.primaryColor});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;
      case 'bank_card':
        return Icons.credit_card;
      case 'credit_card':
        return Icons.credit_score;
      case 'alipay':
        return Icons.currency_yuan;
      case 'wechat':
        return Icons.chat;
      case 'other':
        return Icons.account_balance_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'alipay':
        return const Color(0xFF1677FF);
      case 'wechat':
        return const Color(0xFF07C160);
      case 'cash':
        return Colors.orange;
      case 'bank_card':
        return const Color(0xFF1890FF);
      case 'credit_card':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accountsAsync = ref.watch(allAccountsStreamProvider);
    final allStatsAsync = ref.watch(allAccountStatsProvider);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccountsPage()),
        );
      },
      child: SectionCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题行
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.0.scaled(context, ref)),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10.0.scaled(context, ref)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.discoverAccounts,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: BeeTokens.textPrimary(context),
                        ),
                      ),
                      Text(
                        l10n.accountsManageDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: BeeTokens.iconTertiary(context),
                  size: 20,
                ),
              ],
            ),
            SizedBox(height: 12.0.scaled(context, ref)),
            // 账户内容区域
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return _buildEmptyState(context, ref, l10n);
                }
                return allStatsAsync.when(
                  data: (accountStats) => _buildAccountsContent(
                    context,
                    ref,
                    accounts,
                    accountStats,
                    l10n,
                  ),
                  loading: () => _buildLoadingState(context, ref),
                  error: (_, __) => _buildEmptyState(context, ref, l10n),
                );
              },
              loading: () => _buildLoadingState(context, ref),
              error: (_, __) => _buildEmptyState(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.0.scaled(context, ref)),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 20.0.scaled(context, ref)),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 36,
            color: primaryColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: 8.0.scaled(context, ref)),
          Text(
            l10n.discoverAccountsEmpty,
            style: TextStyle(
              fontSize: 13,
              color: BeeTokens.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsContent(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> accounts,
    Map<int, ({double balance, double expense, double income})> accountStats,
    AppLocalizations l10n,
  ) {
    final useCompact = ref.watch(compactAmountProvider);
    final currencyBalances = _calculateCurrencyBalances(accounts, accountStats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 总余额区域
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12.0.scaled(context, ref),
            vertical: 8.0.scaled(context, ref),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.discoverAccountsTotal,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                  SizedBox(height: 2.0.scaled(context, ref)),
                  _buildCurrencyTotalText(
                    context,
                    currencyBalances,
                    useCompact,
                  ),
                ],
              ),
              Text(
                l10n.discoverAccountsCount(accounts.length),
                style: TextStyle(
                  fontSize: 11,
                  color: BeeTokens.textTertiary(context),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.0.scaled(context, ref)),
        // 账户卡片横向滑动
        SizedBox(
          height: 72.0.scaled(context, ref),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 8.0.scaled(context, ref)),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              final stats = accountStats[account.id];
              final balance = stats?.balance ?? account.initialBalance ?? 0.0;
              return Padding(
                padding: EdgeInsets.only(right: 10.0.scaled(context, ref)),
                child: _buildAccountCard(context, ref, account, balance),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, double> _calculateCurrencyBalances(
    List<dynamic> accounts,
    Map<int, ({double balance, double expense, double income})> accountStats,
  ) {
    final result = <String, double>{};

    for (final account in accounts) {
      final balance = accountStats[account.id]?.balance ?? account.initialBalance ?? 0.0;
      final currencyCode = (account.currency as String?) ?? 'CNY';
      result[currencyCode] = (result[currencyCode] ?? 0.0) + balance;
    }

    return result;
  }

  Widget _buildCurrencyTotalText(
    BuildContext context,
    Map<String, double> currencyBalances,
    bool useCompact,
  ) {
    if (currencyBalances.length <= 1) {
      final entry = currencyBalances.entries.isNotEmpty
          ? currencyBalances.entries.first
          : const MapEntry('CNY', 0.0);
      return AmountText(
        value: entry.value,
        signed: false,
        showCurrency: true,
        useCompactFormat: useCompact,
        currencyCode: entry.key,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: entry.value >= 0 ? BeeTokens.textPrimary(context) : Colors.red,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: currencyBalances.entries
          .map(
            (entry) => AmountText(
              value: entry.value,
              signed: false,
              showCurrency: true,
              useCompactFormat: useCompact,
              currencyCode: entry.key,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: entry.value >= 0
                    ? BeeTokens.textPrimary(context)
                    : Colors.red,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    WidgetRef ref,
    dynamic account,
    double balance,
  ) {
    final useCompact = ref.watch(compactAmountProvider);
    final typeColor = _getColorForType(account.type);

    return Container(
      width: 140.0.scaled(context, ref),
      padding: EdgeInsets.all(12.0.scaled(context, ref)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeColor,
            typeColor.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 账户名和图标
          Row(
            children: [
              Icon(
                _getIconForType(account.type),
                size: 16.0.scaled(context, ref),
                color: Colors.white.withValues(alpha: 0.9),
              ),
              SizedBox(width: 6.0.scaled(context, ref)),
              Expanded(
                child: Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 余额
          AmountText(
            value: balance,
            signed: false,
            showCurrency: true,
            useCompactFormat: useCompact,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷入口卡片
class _QuickActionsCard extends ConsumerWidget {
  final Color primaryColor;

  const _QuickActionsCard({required this.primaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 常用功能标题
          Text(
            l10n.discoverCommonFeatures,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BeeTokens.textPrimary(context),
            ),
          ),
          SizedBox(height: 12.0.scaled(context, ref)),
          // 第一行：导入、导出、分类管理、标签管理
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.file_download_outlined,
                  label: l10n.discoverImport,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ImportPage()),
                  ),
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.file_upload_outlined,
                  label: l10n.discoverExport,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ExportPage()),
                  ),
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.category_outlined,
                  label: l10n.discoverCategory,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CategoryManagePage()),
                  ),
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.label_outlined,
                  label: l10n.discoverTags,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TagManagePage()),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.0.scaled(context, ref)),
          // 第二行：AI设置、使用帮助、配置管理、自动记账
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.psychology_outlined,
                  label: l10n.discoverAISettings,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AISettingsPage()),
                  ),
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.help_outline,
                  label: l10n.discoverHelp,
                  onTap: () async {
                    final locale = Localizations.localeOf(context);
                    final uri = Uri.parse(WebsiteUrls.docs(locale));
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.settings_backup_restore,
                  label: l10n.discoverConfigManagement,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConfigImportExportPage()),
                  ),
                ),
              ),
              Expanded(
                child: _buildActionButton(
                  context,
                  ref,
                  icon: Icons.auto_fix_high,
                  label: l10n.discoverAutoBilling,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AutoBillingSettingsPage()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48.0.scaled(context, ref),
            height: 48.0.scaled(context, ref),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24.0.scaled(context, ref),
              color: primaryColor,
            ),
          ),
          SizedBox(height: 6.0.scaled(context, ref)),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: BeeTokens.textSecondary(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/budget_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/biz.dart';
import '../../widgets/ui/ui.dart';
import 'budget_edit_page.dart';
import 'widgets/budget_progress_bar.dart';
import 'widgets/category_budget_tile.dart';

/// 预算管理页面
class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overviewAsync = ref.watch(budgetOverviewProvider);
    // §7 共享账本:Editor 视角下 budget 是 owner-only(预算属账本元数据,
    // 跟改账本名同级权限)。隐藏 + 按钮 + 编辑入口。
    final currentLedger = ref.watch(currentLedgerProvider).asData?.value;
    final isEditorInShared = currentLedger != null &&
        currentLedger.isShared &&
        currentLedger.myRole != 'owner';

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.budgetTitle,
            showBack: true,
            compact: true,
            actions: [
              if (!isEditorInShared)
                IconButton(
                  onPressed: () => _addBudget(context),
                  icon: const Icon(Icons.add),
                ),
            ],
          ),
          Expanded(
            child: overviewAsync.when(
              data: (overview) => _buildContent(context, ref, overview),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, BudgetOverview? overview) {
    final l10n = AppLocalizations.of(context);
    final currencyCode =
        ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY';
    final currencySymbol = getCurrencySymbol(currencyCode);

    if (overview == null || overview.totalBudget == null) {
      return _buildEmptyState(context, ref, l10n);
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: 12.0.scaled(context, ref),
        vertical: 8.0.scaled(context, ref),
      ),
      children: [
        // 总预算概览卡片
        _buildTotalBudgetCard(context, ref, overview, l10n, currencySymbol),
        SizedBox(height: 12.0.scaled(context, ref)),
        // 分类预算列表
        if (overview.categoryBudgets.isNotEmpty)
          _buildCategoryBudgetsCard(
              context, ref, overview.categoryBudgets, l10n, currencySymbol),
        SizedBox(height: 12.0.scaled(context, ref)),
        // 首页显示开关
        _buildSettingsCard(context, ref, l10n),
      ],
    );
  }


  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    // §7 共享账本 Editor 视角:预算空时不显示"添加"CTA(owner-only)
    final currentLedger = ref.watch(currentLedgerProvider).asData?.value;
    final isEditorInShared = currentLedger != null &&
        currentLedger.isShared &&
        currentLedger.myRole != 'owner';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: BeeTokens.textTertiary(context),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.budgetEmptyHint,
            style: TextStyle(
              fontSize: 16,
              color: BeeTokens.textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          if (!isEditorInShared)
            ElevatedButton.icon(
              onPressed: () => _addBudget(context),
              icon: Icon(Icons.add,
                  color: BeeTokens.buttonPrimaryText(context)),
              label: Text(l10n.budgetAddTotal),
              style: ElevatedButton.styleFrom(
                backgroundColor: BeeTokens.buttonPrimary(context),
                foregroundColor: BeeTokens.buttonPrimaryText(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalBudgetCard(
    BuildContext context,
    WidgetRef ref,
    BudgetOverview overview,
    AppLocalizations l10n,
    String currencySymbol,
  ) {
    final budget = overview.totalBudget!;

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.budgetMonthlyBudget,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
              if (!_isEditorInShared(ref))
                TextButton(
                  onPressed: () => _editTotalBudget(context, ref),
                  child: Text(l10n.commonEdit),
                ),
            ],
          ),
          SizedBox(height: 16.0.scaled(context, ref)),
          // 进度条
          BudgetProgressBar(
            used: budget.used,
            budget: budget.budget,
            showLabel: false,
            height: 12,
            currencySymbol: currencySymbol,
          ),
          SizedBox(height: 12.0.scaled(context, ref)),
          // 金额信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.budgetUsed,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                  Text(
                    '$currencySymbol${budget.used.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.budgetRemaining,
                    style: TextStyle(
                      fontSize: 12,
                      color: BeeTokens.textSecondary(context),
                    ),
                  ),
                  Text(
                    '$currencySymbol${budget.remaining.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: budget.remaining >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.0.scaled(context, ref)),
          // 日均可用
          Container(
            padding: EdgeInsets.all(12.0.scaled(context, ref)),
            decoration: BoxDecoration(
              color: BeeTokens.isDark(context)
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.budgetDaysRemaining(overview.daysRemaining),
                  style: TextStyle(
                    fontSize: 14,
                    color: BeeTokens.textSecondary(context),
                  ),
                ),
                Text(
                  l10n.budgetDailyAvailable(
                      '$currencySymbol${overview.dailyAvailable.toStringAsFixed(0)}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBudgetsCard(
    BuildContext context,
    WidgetRef ref,
    List<CategoryBudgetUsage> categoryBudgets,
    AppLocalizations l10n,
    String currencySymbol,
  ) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.budgetCategoryBudgets,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: BeeTokens.textPrimary(context),
                ),
              ),
              if (!_isEditorInShared(ref))
                TextButton(
                  onPressed: () => _addCategoryBudget(context),
                  child: Text(l10n.commonAdd),
                ),
            ],
          ),
          ...categoryBudgets.map(
            (usage) => CategoryBudgetTile(
              usage: usage,
              currencySymbol: currencySymbol,
              onTap: _isEditorInShared(ref)
                  ? null
                  : () => _editCategoryBudget(context, ref, usage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return SectionCard(
      margin: EdgeInsets.zero,
      child: AppListTile(
        leading: Icons.visibility_outlined,
        title: l10n.budgetShowOnHome,
        trailing: Switch.adaptive(
          value: ref.watch(homeBudgetCardEnabledProvider),
          onChanged: (value) {
            ref.read(homeBudgetCardEnabledProvider.notifier).toggle(value);
          },
          activeColor: ref.watch(primaryColorProvider),
        ),
        onTap: () {
          final current = ref.read(homeBudgetCardEnabledProvider);
          ref.read(homeBudgetCardEnabledProvider.notifier).toggle(!current);
        },
      ),
    );
  }

  void _addBudget(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BudgetEditPage()),
    );
  }

  /// §7 共享账本:Editor 视角不允许编辑预算
  bool _isEditorInShared(WidgetRef ref) {
    final l = ref.read(currentLedgerProvider).asData?.value;
    return l != null && l.isShared && l.myRole != 'owner';
  }

  Future<void> _editTotalBudget(BuildContext context, WidgetRef ref) async {
    if (_isEditorInShared(ref)) {
      showToast(context, '只有账本所有者能编辑预算');
      return;
    }
    final budget = await ref.read(totalBudgetProvider.future);
    if (budget != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BudgetEditPage(budget: budget)),
      );
    }
  }

  void _addCategoryBudget(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const BudgetEditPage(isCategory: true),
      ),
    );
  }

  void _editCategoryBudget(
    BuildContext context,
    WidgetRef ref,
    CategoryBudgetUsage usage,
  ) async {
    if (_isEditorInShared(ref)) {
      showToast(context, '只有账本所有者能编辑预算');
      return;
    }
    final allBudgets = await ref.read(allBudgetsProvider.future);
    final budget = allBudgets.where((b) => b.id == usage.budgetId).firstOrNull;
    if (budget != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BudgetEditPage(budget: budget)),
      );
    }
  }
}

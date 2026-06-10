import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../providers/budget_providers.dart';
import '../../services/billing/post_processor.dart';
import '../../services/data/category_service.dart';
import '../../styles/tokens.dart';
import '../../utils/currencies.dart';
import '../../utils/ui_scale_extensions.dart';
import '../../widgets/biz/section_card.dart';
import '../../widgets/ui/ui.dart';

/// 预算编辑页面
class BudgetEditPage extends ConsumerStatefulWidget {
  final Budget? budget;
  final bool isCategory;

  const BudgetEditPage({
    this.budget,
    this.isCategory = false,
    super.key,
  });

  @override
  ConsumerState<BudgetEditPage> createState() => _BudgetEditPageState();
}

class _BudgetEditPageState extends ConsumerState<BudgetEditPage> {
  final _amountController = TextEditingController();
  late String _type;
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedCategoryIcon;
  int _startDay = 1;
  bool _isLoading = false;
  bool _hasTotalBudget = false; // 是否已存在总预算

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _type = widget.budget!.type;
      _amountController.text = widget.budget!.amount.toStringAsFixed(0);
      _selectedCategoryId = widget.budget!.categoryId;
      _startDay = widget.budget!.startDay;
    } else {
      _type = widget.isCategory ? 'category' : 'total';
      // 检查是否已存在总预算
      _checkTotalBudgetExists();
    }
  }

  Future<void> _checkTotalBudgetExists() async {
    final totalBudget = await ref.read(totalBudgetProvider.future);
    if (mounted && totalBudget != null) {
      setState(() {
        _hasTotalBudget = true;
        // 如果已存在总预算，默认选择分类预算
        if (_type == 'total') {
          _type = 'category';
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyCode =
        ref.watch(currentLedgerProvider).asData?.value?.currency ?? 'CNY';
    final currencySymbol = getCurrencySymbol(currencyCode);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: _isEditing ? l10n.budgetEditTitle : l10n.budgetAddTitle,
            showBack: true,
            compact: true,
            actions: [
              if (_isEditing)
                IconButton(
                  onPressed: _deleteBudget,
                  icon: const Icon(Icons.delete_outline),
                ),
              TextButton(
                onPressed: _isLoading ? null : _saveBudget,
                child: Text(
                  l10n.commonSave,
                  style: TextStyle(
                    color: BeeTokens.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                // 预算类型选择
                if (!_isEditing) ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.budgetPeriodLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                        SizedBox(height: 12.0.scaled(context, ref)),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTypeOption(
                                context,
                                l10n.budgetTypeTotalLabel,
                                'total',
                                Icons.account_balance_wallet_outlined,
                                disabled: _hasTotalBudget, // 已有总预算时禁用
                              ),
                            ),
                            SizedBox(width: 12.0.scaled(context, ref)),
                            Expanded(
                              child: _buildTypeOption(
                                context,
                                l10n.budgetTypeCategoryLabel,
                                'category',
                                Icons.category_outlined,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.0.scaled(context, ref)),
                ],
                // 分类选择（仅分类预算）
                if (_type == 'category') ...[
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.budgetCategoryLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: BeeTokens.textSecondary(context),
                          ),
                        ),
                        SizedBox(height: 12.0.scaled(context, ref)),
                        _buildCategorySelector(context, l10n),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.0.scaled(context, ref)),
                ],
                // 预算金额
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.budgetAmountLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: BeeTokens.textSecondary(context),
                        ),
                      ),
                      SizedBox(height: 12.0.scaled(context, ref)),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: BeeTokens.textPrimary(context),
                        ),
                        decoration: InputDecoration(
                          prefixText: '$currencySymbol ',
                          prefixStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: BeeTokens.textPrimary(context),
                          ),
                          hintText: l10n.budgetAmountHint,
                          hintStyle: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: BeeTokens.textTertiary(context),
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ],
                  ),
                ),
                // 预算周期跟随「账本设置 → 每月起始日」(period-start-date 设计 D5),
                // 不再提供 per-budget 起始日;独立覆盖若有需求走二期新列。
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(
    BuildContext context,
    String label,
    String type,
    IconData icon, {
    bool disabled = false,
  }) {
    final isSelected = _type == type;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: disabled ? null : () => setState(() => _type = type),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Container(
          padding: EdgeInsets.all(16.0.scaled(context, ref)),
          decoration: BoxDecoration(
            color: isSelected && !disabled
                ? primary.withValues(alpha: 0.1)
                : BeeTokens.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected && !disabled ? primary : BeeTokens.border(context),
              width: isSelected && !disabled ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32.0.scaled(context, ref),
                color: isSelected && !disabled ? primary : BeeTokens.iconSecondary(context),
              ),
              SizedBox(height: 8.0.scaled(context, ref)),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected && !disabled ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected && !disabled ? primary : BeeTokens.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(BuildContext context, AppLocalizations l10n) {
    return InkWell(
      onTap: _selectCategory,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.all(12.0.scaled(context, ref)),
        decoration: BoxDecoration(
          color: BeeTokens.surface(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BeeTokens.border(context)),
        ),
        child: Row(
          children: [
            if (_selectedCategoryId != null) ...[
              Container(
                width: 36.0.scaled(context, ref),
                height: 36.0.scaled(context, ref),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  CategoryService.getCategoryIcon(_selectedCategoryIcon),
                  size: 20.0.scaled(context, ref),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: 12.0.scaled(context, ref)),
              Expanded(
                child: Text(
                  _selectedCategoryName ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
              ),
            ] else ...[
              Icon(
                Icons.add_circle_outline,
                size: 24.0.scaled(context, ref),
                color: BeeTokens.iconTertiary(context),
              ),
              SizedBox(width: 12.0.scaled(context, ref)),
              Expanded(
                child: Text(
                  l10n.budgetCategoryHint,
                  style: TextStyle(
                    fontSize: 16,
                    color: BeeTokens.textTertiary(context),
                  ),
                ),
              ),
            ],
            Icon(
              Icons.chevron_right,
              color: BeeTokens.iconTertiary(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCategory() async {
    final repo = ref.read(repositoryProvider);
    final categories = await repo.getAllCategories();

    // 只显示支出类父分类
    final expenseCategories = categories
        .where((c) => c.kind == 'expense' && c.parentId == null)
        .toList();

    if (!mounted) return;

    final selected = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeTokens.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context).budgetCategoryLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: expenseCategories.length,
                itemBuilder: (context, index) {
                  final category = expenseCategories[index];
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        CategoryService.getCategoryIcon(category.icon),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(category.name),
                    trailing: _selectedCategoryId == category.id
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(context, category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedCategoryId = selected.id;
        _selectedCategoryName = selected.name;
        _selectedCategoryIcon = selected.icon;
      });
    }
  }

  Future<void> _saveBudget() async {
    final l10n = AppLocalizations.of(context);
    final amountText = _amountController.text.trim();

    if (amountText.isEmpty) {
      showToast(context, l10n.budgetAmountHint);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      showToast(context, l10n.budgetAmountHint);
      return;
    }

    if (_type == 'category' && _selectedCategoryId == null) {
      showToast(context, l10n.budgetCategoryHint);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);

      if (_isEditing) {
        await repo.updateBudget(
          widget.budget!.id,
          amount: amount,
          startDay: _startDay,
        );
      } else {
        await repo.createBudget(
          ledgerId: ledgerId,
          type: _type,
          categoryId: _selectedCategoryId,
          amount: amount,
          startDay: _startDay,
        );
      }

      // 刷新预算数据
      ref.read(budgetRefreshProvider.notifier).state++;

      // 触发一次 sync:预算变更走 changeTracker 已经记在表里了,但
      // PostProcessor.sync 只在 tx 写入时才调。如果用户只改预算不加交易,
      // 那条 change 会压在本地没 push 出去 → B 端 / web 看不到。这里手动
      // 推一下,不阻塞 UI。
      unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));

      if (mounted) {
        showToast(context, l10n.budgetSaveSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBudget() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.commonDelete),
        content: Text(l10n.budgetDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(repositoryProvider);
      final ledgerId = ref.read(currentLedgerIdProvider);
      await repo.deleteBudget(widget.budget!.id);

      // 刷新预算数据
      ref.read(budgetRefreshProvider.notifier).state++;

      // 跟保存路径一样:删预算也要 flush 一次 sync,否则 B 端 / web 永远
      // 看到幽灵预算。
      unawaited(PostProcessor.sync(ref, ledgerId: ledgerId));

      if (mounted) {
        showToast(context, l10n.budgetDeleteSuccess);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showToast(context, e.toString());
      }
    }
  }
}

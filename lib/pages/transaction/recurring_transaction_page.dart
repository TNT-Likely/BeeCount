import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers.dart';
import '../../widgets/ui/ui.dart';
import '../../widgets/biz/amount_text.dart';
import '../../widgets/biz/section_card.dart';
import '../../data/db.dart';
import '../../l10n/app_localizations.dart';
import '../../services/data/recurring_transaction_service.dart';
import '../../utils/category_utils.dart';
import '../../styles/tokens.dart';
import 'recurring_transaction_edit_page.dart';

class RecurringTransactionPage extends ConsumerWidget {
  const RecurringTransactionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringTransactionsAsync =
        ref.watch(allRecurringTransactionsProvider);

    return Scaffold(
      body: Column(
        children: [
          PrimaryHeader(
            title: AppLocalizations.of(context)!.recurringTransactionTitle,
            showBack: true,
            actions: [
              IconButton(
                onPressed: () => _addRecurringTransaction(context, ref),
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.recurringTransactionAdd,
              ),
            ],
          ),
          Expanded(
            child: recurringTransactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('Error: $error'),
              ),
              data: (recurringTransactions) {
                if (recurringTransactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 64,
                          color: BeeTokens.textTertiary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!
                              .recurringTransactionEmpty,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: BeeTokens.textSecondary(context),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!
                              .recurringTransactionEmptyHint,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: BeeTokens.textTertiary(context),
                                  ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: recurringTransactions.length +
                      1, // +1 for usage guide card
                  itemBuilder: (context, index) {
                    // 第一个显示使用说明卡片
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _UsageGuideCard(),
                      );
                    }
                    // 后续显示周期记账卡片
                    final recurring = recurringTransactions[index - 1];
                    return _RecurringTransactionCard(recurring: recurring);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _addRecurringTransaction(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const RecurringTransactionEditPage(),
      ),
    );
    // 如果返回 true，表示数据已更改，强制刷新列表
    if (result == true) {
      ref.invalidate(allRecurringTransactionsProvider);
    }
  }
}

class _RecurringTransactionCard extends ConsumerWidget {
  final RecurringTransaction recurring;

  const _RecurringTransactionCard({required this.recurring});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final primaryColor = ref.watch(primaryColorProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: BeeTokens.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: BeeTokens.isDark(context)
            ? Border.all(
                color: recurring.enabled
                    ? primaryColor.withValues(alpha: 0.3)
                    : BeeTokens.border(context),
                width: 1,
              )
            : null,
        boxShadow: BeeTokens.isDark(context)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) =>
                    RecurringTransactionEditPage(recurring: recurring),
              ),
            );
            // 如果返回 true，表示数据已更改，强制刷新列表
            if (result == true) {
              ref.invalidate(allRecurringTransactionsProvider);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 左侧：类型指示条
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: recurring.type == 'expense'
                        ? BeeTokens.error(context)
                        : recurring.type == 'income'
                            ? BeeTokens.success(context)
                            : primaryColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 12),
                // 中间：信息区域
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 第一行：分类名称
                      recurring.type == 'transfer'
                          ? Text(
                              AppLocalizations.of(context)!.transferTitle,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: BeeTokens.textPrimary(context),
                              ),
                            )
                          : FutureBuilder<Category?>(
                              future: _getCategory(ref, recurring.categoryId),
                              builder: (context, snapshot) {
                                final categoryName = snapshot.data?.name ?? '';
                                return Text(
                                  CategoryUtils.getDisplayName(
                                      categoryName, context),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: BeeTokens.textPrimary(context),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 6),
                      // 第二行：账本 + 频率 + 时间
                      Row(
                        children: [
                          // 账本
                          FutureBuilder<Ledger?>(
                            future: _getLedger(ref, recurring.ledgerId),
                            builder: (context, snapshot) {
                              final ledgerName = snapshot.data?.name ?? '';
                              return Text(
                                ledgerName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                              '·',
                              style: TextStyle(
                                fontSize: 12,
                                color: BeeTokens.textTertiary(context),
                              ),
                            ),
                          ),
                          // 频率
                          Text(
                            _getFrequencyDescription(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: BeeTokens.textTertiary(context),
                            ),
                          ),
                          // 下次生成时间（如果有）
                          if (recurring.lastGeneratedDate != null) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BeeTokens.textTertiary(context),
                                ),
                              ),
                            ),
                            Icon(
                              Icons.access_time,
                              size: 11,
                              color: primaryColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat.Md()
                                  .format(recurring.lastGeneratedDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // 备注（如果有）
                      if (recurring.note != null &&
                          recurring.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          recurring.note!,
                          style: TextStyle(
                            fontSize: 11,
                            color: BeeTokens.textSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // 右侧：金额 + 开关
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 金额
                    AmountText(
                      value: recurring.type == 'expense'
                          ? -recurring.amount
                          : recurring.amount,
                      signed: recurring.type != 'transfer',
                      decimals: 2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: recurring.type == 'expense'
                            ? BeeTokens.error(context)
                            : recurring.type == 'income'
                                ? BeeTokens.success(context)
                                : BeeTokens.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 开关
                    Transform.scale(
                      scale: 0.65,
                      alignment: Alignment.centerRight,
                      child: Switch(
                        value: recurring.enabled,
                        onChanged: (value) async {
                          print(
                              '🔧 [周期记账] 开关点击: id=${recurring.id}, newValue=$value, repo类型=${repo.runtimeType}');

                          try {
                            await repo.toggleRecurringTransaction(
                                recurring.id, value);
                            print('✅ [周期记账] toggleRecurringTransaction 完成');

                            // 给Realtime一点时间触发更新
                            await Future.delayed(
                                const Duration(milliseconds: 100));

                            ref.invalidate(allRecurringTransactionsProvider);
                            print('✅ [周期记账] Provider已invalidate');
                          } catch (e, stackTrace) {
                            print('❌ [周期记账] 切换失败: $e');
                            print('堆栈: $stackTrace');
                          }
                        },
                        activeColor: primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFrequencyDescription(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final frequency = RecurringFrequency.fromString(recurring.frequency);
    final interval = recurring.interval;

    if (interval == 1) {
      switch (frequency) {
        case RecurringFrequency.daily:
          return l10n.recurringTransactionDaily;
        case RecurringFrequency.weekly:
          return l10n.recurringTransactionWeekly;
        case RecurringFrequency.monthly:
          return l10n.recurringTransactionMonthly;
        case RecurringFrequency.yearly:
          return l10n.recurringTransactionYearly;
      }
    } else {
      switch (frequency) {
        case RecurringFrequency.daily:
          return l10n.recurringTransactionEveryNDays(interval);
        case RecurringFrequency.weekly:
          return l10n.recurringTransactionEveryNWeeks(interval);
        case RecurringFrequency.monthly:
          return l10n.recurringTransactionEveryNMonths(interval);
        case RecurringFrequency.yearly:
          return l10n.recurringTransactionEveryNYears(interval);
      }
    }
  }

  Future<Category?> _getCategory(WidgetRef ref, int? categoryId) async {
    if (categoryId == null) return null;
    final repo = ref.read(repositoryProvider);
    return await repo.getCategoryById(categoryId);
  }

  Future<Ledger?> _getLedger(WidgetRef ref, int ledgerId) async {
    final repo = ref.read(repositoryProvider);
    return await repo.getLedgerById(ledgerId);
  }
}

/// 使用说明卡片
class _UsageGuideCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final primaryColor = ref.watch(primaryColorProvider);

    return SectionCard(
      margin: EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.recurringTransactionUsageTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BeeTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.recurringTransactionUsageContent,
                  style: TextStyle(
                    fontSize: 13,
                    color: BeeTokens.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

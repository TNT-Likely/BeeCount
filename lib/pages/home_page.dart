import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider, PersonalizePage;
import '../data/db.dart';
import '../widgets/primary_header.dart';
import 'import_page.dart';
import 'analytics_page.dart';
import 'ledgers_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final view = ref.watch(selectedViewProvider);
    final hide = ref.watch(hideAmountsProvider);
    return Scaffold(
      body: Column(
        children: [
          Consumer(builder: (context, ref, _) {
            ref.watch(headerStyleProvider);
            return PrimaryHeader(
              title: view == 'year'
                  ? '全年'
                  : '${month.month.toString().padLeft(2, '0')}月',
              subtitle: '${month.year}年',
              titleTrailing: InkWell(
                onTap: () async {
                  final choice =
                      await showModalBottomSheet<(String view, DateTime date)>(
                    context: context,
                    builder: (ctx) {
                      String view = 'month';
                      DateTime pick = month;
                      return StatefulBuilder(builder: (ctx, setS) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                const Text('视角：'),
                                ChoiceChip(
                                    label: const Text('按月'),
                                    selected: view == 'month',
                                    onSelected: (_) =>
                                        setS(() => view = 'month')),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                    label: const Text('按年'),
                                    selected: view == 'year',
                                    onSelected: (_) =>
                                        setS(() => view = 'year')),
                                const Spacer(),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('取消')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, (view, pick)),
                                    child: const Text('确定')),
                              ]),
                              const SizedBox(height: 12),
                              if (view == 'month')
                                CalendarDatePicker(
                                  initialDate: pick,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  onDateChanged: (d) => setS(() => pick = d),
                                )
                              else
                                SizedBox(
                                  height: 240,
                                  child: YearPicker(
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    selectedDate: pick,
                                    onChanged: (d) => setS(
                                        () => pick = DateTime(d.year, 1, 1)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      });
                    },
                  );
                  if (choice != null) {
                    final (v, date) = choice;
                    ref.read(selectedViewProvider.notifier).state = v;
                    final target = v == 'year'
                        ? DateTime(date.year, 1, 1)
                        : DateTime(date.year, date.month, 1);
                    ref.read(selectedMonthProvider.notifier).state = target;
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 2),
                  child:
                      Icon(Icons.calendar_month, color: Colors.black, size: 18),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: hide ? '显示金额' : '隐藏金额',
                  onPressed: () {
                    final cur = ref.read(hideAmountsProvider);
                    ref.read(hideAmountsProvider.notifier).state = !cur;
                  },
                  icon: Icon(
                    hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.black,
                  ),
                ),
              ],
            );
          }),
          // 顶部与内容之间的过渡条，避免在 Android 上出现重叠阴影或分层
          Container(height: 8, color: Colors.white),
          Expanded(
            child: StreamBuilder<List<({Transaction t, Category? category})>>(
              stream: view == 'year'
                  ? repo.transactionsWithCategoryInYear(
                      ledgerId: ledgerId, year: month.year)
                  : repo.transactionsWithCategoryInMonth(
                      ledgerId: ledgerId, month: month),
              builder: (context, snapshot) {
                final joined = snapshot.data ?? [];
                return FutureBuilder<(double income, double expense)>(
                  future: view == 'year'
                      ? repo.yearlyTotals(ledgerId: ledgerId, year: month.year)
                      : repo.monthlyTotals(ledgerId: ledgerId, month: month),
                  builder: (context, totalSnap) {
                    final income = (totalSnap.data?.$1) ?? 0.0;
                    final expense = (totalSnap.data?.$2) ?? 0.0;
                    final balance = income - expense;
                    // 分组：按天
                    final dateFmt = DateFormat('yyyy-MM-dd');
                    final groups =
                        <String, List<({Transaction t, Category? category})>>{};
                    for (final item in joined) {
                      final dt = item.t.happenedAt.toLocal();
                      final key =
                          dateFmt.format(DateTime(dt.year, dt.month, dt.day));
                      groups.putIfAbsent(key, () => []).add(item);
                    }
                    // 排序：日期降序
                    final sortedKeys = groups.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    return ListView.builder(
                      itemCount: 1 + // 顶部统计卡
                          (sortedKeys.isEmpty
                              ? 1 // 空态
                              : sortedKeys
                                  .map((k) =>
                                      1 + groups[k]!.length) // 每组1个分组头+N条
                                  .reduce((a, b) => a + b)),
                      itemBuilder: (context, index) {
                        // 0 位置放顶部统计卡
                        if (index == 0) {
                          return Column(
                            children: [
                              _HeaderCard(
                                income: income,
                                expense: expense,
                                balance: balance,
                                hide: hide,
                              ),
                              const SizedBox(height: 8),
                              _QuickActionsRow(
                                onImport: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const ImportPage()),
                                ),
                                onAnalytics: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const AnalyticsPage()),
                                ),
                                onLedgers: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LedgersPage()),
                                ),
                                onPersonalize: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const PersonalizePage()),
                                ),
                              ),
                            ],
                          );
                        }

                        if (sortedKeys.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: Text('暂无数据，点击右下角记一笔')),
                          );
                        }

                        // 将 index-1 映射到分组和分组内的行
                        var idx = index - 1;
                        for (final key in sortedKeys) {
                          final list = groups[key]!;
                          if (idx == 0) {
                            // 分组头
                            // 计算当日小计（支出/收入）
                            double dayIncome = 0, dayExpense = 0;
                            for (final it in list) {
                              if (it.t.type == 'income') {
                                dayIncome += it.t.amount;
                              }
                              if (it.t.type == 'expense') {
                                dayExpense += it.t.amount;
                              }
                            }
                            return _DayHeader(
                              dateText: key,
                              income: dayIncome,
                              expense: dayExpense,
                              hide: hide,
                            );
                          }
                          idx--;
                          if (idx < list.length) {
                            final it = list[idx];
                            final isExpense = it.t.type == 'expense';
                            final amountPrefix = isExpense ? '-' : '+';
                            final categoryName = it.category?.name ?? '未分类';
                            final subtitle = it.t.note ?? '';
                            return Dismissible(
                              key: ValueKey(it.t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(color: Colors.transparent),
                              secondaryBackground: Container(
                                  color: Colors.red[100],
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 16),
                                  child: const Icon(Icons.delete_outline,
                                      color: Colors.red)),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                                title: const Text('删除这条记账？'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child: const Text('取消')),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child: const Text('删除'))
                                                ])) ??
                                    false;
                              },
                              onDismissed: (_) async {
                                final db = ref.read(databaseProvider);
                                await (db.delete(db.transactions)
                                      ..where((t) => t.id.equals(it.t.id)))
                                    .go();
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已删除')));
                              },
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isExpense
                                          ? Colors.red[50]
                                          : Colors.green[50],
                                      child: Icon(
                                        isExpense
                                            ? Icons.south_east
                                            : Icons.north_east,
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    title: Text(categoryName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: subtitle.isEmpty
                                        ? null
                                        : Text(subtitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                    trailing: Text(
                                      hide
                                          ? '****'
                                          : '$amountPrefix${it.t.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onTap: () async {
                                      final amountController =
                                          TextEditingController(
                                              text: it.t.amount
                                                  .toStringAsFixed(2));
                                      final noteController =
                                          TextEditingController(
                                              text: it.t.note ?? '');
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(16)),
                                        ),
                                        builder: (ctx) => Padding(
                                          padding: EdgeInsets.only(
                                            bottom: MediaQuery.of(ctx)
                                                .viewInsets
                                                .bottom,
                                            left: 16,
                                            right: 16,
                                            top: 20,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(categoryName,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .titleLarge),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: amountController,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: '金额',
                                                        prefixIcon: Icon(Icons
                                                            .currency_yuan)),
                                              ),
                                              const SizedBox(height: 8),
                                              TextField(
                                                controller: noteController,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText: '备注（可选）'),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(children: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text('取消'),
                                                ),
                                                const Spacer(),
                                                Consumer(
                                                    builder: (context, ref, _) {
                                                  return FilledButton(
                                                    onPressed: () async {
                                                      final repo = ref.read(
                                                          repositoryProvider);
                                                      final newAmount =
                                                          double.tryParse(
                                                              amountController
                                                                  .text);
                                                      if (newAmount == null) {
                                                        ScaffoldMessenger.of(
                                                                ctx)
                                                            .showSnackBar(
                                                                const SnackBar(
                                                                    content: Text(
                                                                        '请输入有效金额')));
                                                        return;
                                                      }
                                                      await repo
                                                          .updateTransaction(
                                                        id: it.t.id,
                                                        type: it.t.type,
                                                        amount: newAmount,
                                                        categoryId:
                                                            it.t.categoryId,
                                                        note: noteController
                                                                .text.isEmpty
                                                            ? null
                                                            : noteController
                                                                .text,
                                                        happenedAt:
                                                            it.t.happenedAt,
                                                      );
                                                      if (Navigator.of(ctx)
                                                          .canPop())
                                                        Navigator.of(ctx).pop();
                                                    },
                                                    child: const Text('保存'),
                                                  );
                                                })
                                              ]),
                                              const SizedBox(height: 24),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(height: 1),
                                ],
                              ),
                            );
                          }
                          idx -= list.length;
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool hide;
  final Color? labelColor;
  const _StatChip(
      {required this.label,
      required this.value,
      required this.color,
      this.hide = false,
      this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: (Theme.of(context).textTheme.labelMedium)?.copyWith(
            color: labelColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(hide ? '****' : value.toStringAsFixed(2),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String dateText;
  final double income;
  final double expense;
  final bool hide;
  const _DayHeader({
    required this.dateText,
    required this.income,
    required this.expense,
    this.hide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(dateText,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.grey[700])),
          Row(children: [
            Text('支出 ${hide ? '****' : expense.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red[700])),
            const SizedBox(width: 12),
            Text('收入 ${hide ? '****' : income.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.green[700])),
          ])
        ],
      ),
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  final double income;
  final double expense;
  final double balance;
  final bool hide;
  const _HeaderCard({
    required this.income,
    required this.expense,
    required this.balance,
    required this.hide,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    // 简单加深一档作为渐变尾色
    final hsl = HSLColor.fromColor(primary);
    final darker =
        hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, darker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
            label: '收入',
            value: income,
            color: Colors.white,
            labelColor: Colors.white70,
            hide: hide,
          ),
          _StatChip(
            label: '支出',
            value: expense,
            color: Colors.white,
            labelColor: Colors.white70,
            hide: hide,
          ),
          _StatChip(
            label: '结余',
            value: balance,
            color: Colors.white,
            labelColor: Colors.white70,
            hide: hide,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onAnalytics;
  final VoidCallback onLedgers;
  final VoidCallback onPersonalize;

  const _QuickActionsRow({
    required this.onImport,
    required this.onAnalytics,
    required this.onLedgers,
    required this.onPersonalize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionButton(
              icon: Icons.file_upload_outlined, label: '导入', onTap: onImport),
          _ActionButton(
              icon: Icons.pie_chart_outline, label: '图表', onTap: onAnalytics),
          _ActionButton(
              icon: Icons.menu_book_outlined, label: '账本', onTap: onLedgers),
          _ActionButton(
              icon: Icons.color_lens_outlined,
              label: '个性化',
              onTap: onPersonalize),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

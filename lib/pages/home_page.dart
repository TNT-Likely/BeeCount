import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider;
import '../data/db.dart';
import '../widgets/primary_header.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _switching = false;
  double _lastPixels = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_switching) return;
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final delta = pos.pixels - _lastPixels;
    // 上滑：接近底部切换到上一个月（仅按月视角）
    if (pos.maxScrollExtent > 0 &&
        pos.pixels >= pos.maxScrollExtent - 24 &&
        delta > 0) {
      final view = ref.read(selectedViewProvider);
      if (view == 'month') {
        _switching = true;
        final cur = ref.read(selectedMonthProvider);
        final prev = DateTime(cur.year, cur.month - 1, 1);
        ref.read(selectedMonthProvider.notifier).state = prev;
        // 轻微震动反馈
        HapticFeedback.selectionClick();
        // 稍作节流，避免反复触发
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _switching = false;
        });
        // 回到顶部
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }
    }
    // 下拉：在顶部轻微下拉尝试往“下一个月”（不超过当前月）
    if (pos.pixels <= 12 && delta < 0) {
      final view = ref.read(selectedViewProvider);
      if (view == 'month') {
        final cur = ref.read(selectedMonthProvider);
        final next = DateTime(cur.year, cur.month + 1, 1);
        final now = DateTime.now();
        final currentMonth = DateTime(now.year, now.month, 1);
        if (!next.isAfter(currentMonth)) {
          _switching = true;
          ref.read(selectedMonthProvider.notifier).state = next;
          // 轻微震动反馈
          HapticFeedback.selectionClick();
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) _switching = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        }
      }
    }
    _lastPixels = pos.pixels;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final view = ref.watch(selectedViewProvider);
    final hide = ref.watch(hideAmountsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
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
              center: _HeaderCenterSummary(hide: hide),
              bottom: const _HeaderDecor(),
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
          // 顶部与内容之间的过渡条，去除额外空白
          const SizedBox(height: 0),
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
                    // 汇总已移动到 Header 的 center 区域，这里的局部值不再直接渲染
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
                      controller: _scrollController,
                      itemCount: // 不再有顶部额外卡片，仅内容
                          (sortedKeys.isEmpty
                              ? 1 // 空态
                              : sortedKeys
                                  .map((k) =>
                                      1 + groups[k]!.length) // 每组1个分组头+N条
                                  .reduce((a, b) => a + b)),
                      itemBuilder: (context, index) {
                        if (sortedKeys.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Center(child: Text('暂无数据，点击右下角记一笔')),
                          );
                        }

                        // 将 index 映射到分组和分组内的行
                        var idx = index;
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
                            IconData iconFor(String n) {
                              final name = n;
                              if (name.contains('餐') ||
                                  name.contains('饭') ||
                                  name.contains('吃') ||
                                  name.contains('外卖')) {
                                return Icons.restaurant_outlined;
                              }
                              if (name.contains('交通') ||
                                  name.contains('出行') ||
                                  name.contains('打车') ||
                                  name.contains('地铁') ||
                                  name.contains('公交') ||
                                  name.contains('高铁') ||
                                  name.contains('火车') ||
                                  name.contains('飞机')) {
                                return Icons.directions_transit_outlined;
                              }
                              // 车类：未被上面的交通关键词覆盖但名字中明确表示车辆
                              if (name == '车' ||
                                  name.contains('车辆') ||
                                  name.contains('车贷') ||
                                  name.contains('购车') ||
                                  name.contains('爱车')) {
                                return Icons.directions_car_outlined;
                              }
                              if (name.contains('购物') || name.contains('百货')) {
                                return Icons.shopping_bag_outlined;
                              }
                              if (name.contains('服饰') ||
                                  name.contains('衣') ||
                                  name.contains('鞋') ||
                                  name.contains('裤') ||
                                  name.contains('帽')) {
                                return Icons.checkroom_outlined;
                              }
                              if (name.contains('超市') ||
                                  name.contains('生鲜') ||
                                  name.contains('菜') ||
                                  name.contains('粮油') ||
                                  name.contains('蔬菜') ||
                                  name.contains('水果')) {
                                return Icons.local_grocery_store_outlined;
                              }
                              if (name.contains('娱乐') || name.contains('游戏')) {
                                return Icons.sports_esports_outlined;
                              }
                              if (name.contains('居家') ||
                                  name.contains('家') ||
                                  name.contains('家居') ||
                                  name.contains('物业') ||
                                  name.contains('维修')) {
                                return Icons.chair_outlined;
                              }
                              if (name.contains('美妆') ||
                                  name.contains('化妆') ||
                                  name.contains('护肤') ||
                                  name.contains('美容')) {
                                return Icons.brush_outlined;
                              }
                              if (name.contains('通讯') ||
                                  name.contains('话费') ||
                                  name.contains('宽带')) {
                                return Icons.phone_iphone_outlined;
                              }
                              if (name.contains('订阅') ||
                                  name.contains('会员') ||
                                  name.contains('流媒体')) {
                                return Icons.subscriptions_outlined;
                              }
                              if (name.contains('礼物') ||
                                  name.contains('红包') ||
                                  name.contains('礼金')) {
                                return Icons.card_giftcard_outlined;
                              }
                              if (name.contains('水') ||
                                  name.contains('电') ||
                                  name.contains('煤') ||
                                  name.contains('燃气')) {
                                return Icons.water_drop_outlined;
                              }
                              if (name.contains('房') || name.contains('租')) {
                                return Icons.home_outlined;
                              }
                              if (name.contains('房贷') ||
                                  name.contains('按揭') ||
                                  name.contains('贷款')) {
                                return Icons.account_balance_outlined;
                              }
                              if (name.contains('工资') ||
                                  name.contains('收入') ||
                                  name.contains('奖金') ||
                                  name.contains('报销') ||
                                  name.contains('兼职')) {
                                return Icons.attach_money_outlined;
                              }
                              if (name.contains('理财') ||
                                  name.contains('利息') ||
                                  name.contains('基金') ||
                                  name.contains('股票') ||
                                  name.contains('退款')) {
                                return Icons.savings_outlined;
                              }
                              if (name.contains('教育') ||
                                  name.contains('学习') ||
                                  name.contains('培训')) {
                                return Icons.menu_book_outlined;
                              }
                              if (name.contains('医疗') ||
                                  name.contains('医院') ||
                                  name.contains('药')) {
                                return Icons.medical_services_outlined;
                              }
                              if (name.contains('宠物') ||
                                  name.contains('猫') ||
                                  name.contains('狗')) {
                                return Icons.pets_outlined;
                              }
                              if (name.contains('运动') ||
                                  name.contains('健身') ||
                                  name.contains('球')) {
                                return Icons.fitness_center_outlined;
                              }
                              if (name.contains('数码') ||
                                  name.contains('电子') ||
                                  name.contains('手机')) {
                                return Icons.devices_other_outlined;
                              }
                              if (name.contains('旅行') ||
                                  name.contains('旅游') ||
                                  name.contains('出差')) {
                                return Icons.card_travel_outlined;
                              }
                              if (name.contains('酒店') ||
                                  name.contains('住宿') ||
                                  name.contains('民宿')) {
                                return Icons.hotel_outlined;
                              }
                              if (name.contains('烟') ||
                                  name.contains('酒') ||
                                  name.contains('茶')) {
                                return Icons.local_bar_outlined;
                              }
                              if (name.contains('母婴') ||
                                  name.contains('孩子') ||
                                  name.contains('奶粉')) {
                                return Icons.child_friendly_outlined;
                              }
                              if (name.contains('停车') ||
                                  name.contains('加油') ||
                                  name.contains('汽车') ||
                                  name.contains('保养')) {
                                return Icons.local_gas_station_outlined;
                              }
                              if (name.contains('快递') || name.contains('邮寄')) {
                                return Icons.local_shipping_outlined;
                              }
                              if (name.contains('税') ||
                                  name.contains('社保') ||
                                  name.contains('公积金')) {
                                return Icons.receipt_long_outlined;
                              }
                              if (name.contains('捐赠') || name.contains('公益')) {
                                return Icons.volunteer_activism_outlined;
                              }
                              return Icons.circle_outlined;
                            }

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
                                    visualDensity:
                                        const VisualDensity(vertical: -2),
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.grey[200],
                                      child: Icon(
                                        iconFor(categoryName),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 16,
                                      ),
                                    ),
                                    title: Text(
                                      subtitle.isNotEmpty
                                          ? subtitle
                                          : categoryName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 13,
                                              color: Colors.black87),
                                    ),
                                    subtitle: null,
                                    trailing: Text(
                                      hide
                                          ? '****'
                                          : '$amountPrefix${it.t.amount.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 13,
                                              color: Colors.black87),
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
                                  Divider(height: 1, color: Colors.grey[200]),
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

class _HeaderCenterSummary extends ConsumerWidget {
  final bool hide;
  const _HeaderCenterSummary({required this.hide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final ledgerId = ref.watch(currentLedgerIdProvider);
    final month = ref.watch(selectedMonthProvider);
    final view = ref.watch(selectedViewProvider);
    return FutureBuilder<(double income, double expense)>(
      future: view == 'year'
          ? repo.yearlyTotals(ledgerId: ledgerId, year: month.year)
          : repo.monthlyTotals(ledgerId: ledgerId, month: month),
      builder: (context, snap) {
        final income = (snap.data?.$1) ?? 0.0;
        final expense = (snap.data?.$2) ?? 0.0;
        final balance = income - expense;
        Widget item(String title, double value) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.black54, fontSize: 11)),
                const SizedBox(height: 1),
                Text(
                  hide ? '****' : value.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                ),
              ],
            );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            item('收入', income),
            const SizedBox(width: 10),
            item('支出', expense),
            const SizedBox(width: 10),
            item('结余', balance),
          ],
        );
      },
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
    String weekdayZh(String yyyyMMdd) {
      try {
        final dt = DateTime.parse(yyyyMMdd);
        const names = ['一', '二', '三', '四', '五', '六', '日'];
        return '星期${names[dt.weekday - 1]}';
      } catch (_) {
        return '';
      }
    }

    final week = weekdayZh(dateText);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Text(dateText,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.black87)),
            if (week.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(week,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.black54)),
            ]
          ]),
          Row(children: [
            Text('支出 ${hide ? '****' : expense.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(width: 12),
            Text('收入 ${hide ? '****' : income.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.black54)),
          ])
        ],
      ),
    );
  }
}

// 顶部插画/卡片装饰，可按需替换为图片资源
class _HeaderDecor extends StatelessWidget {
  const _HeaderDecor();
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.assessment_outlined, color: Colors.black54, size: 18),
          const SizedBox(width: 8),
          Text('小提示：点击月份可切换按年/按月视图',
              style: text.labelSmall?.copyWith(color: Colors.black54)),
          const Spacer(),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('记账小助手',
                style: text.labelSmall?.copyWith(
                    color: Colors.black87, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// 旧的渐变统计卡与快捷入口行已移除，顶部统计改为白色背景的 _TopSummaryBar。

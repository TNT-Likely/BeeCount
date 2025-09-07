import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider;
import '../data/db.dart';
import '../widgets/primary_header.dart';
import 'category_picker.dart';
import 'package:beecount/widgets/wheel_date_picker.dart';
import 'package:beecount/widgets/measure_size.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _switching = false;
  double _lastPixels = 0;
  // 惰性分段缓存：分组顺序、头/行高度、累积高度与已计算分组数量
  List<String> _sortedKeysCache = [];
  final Map<String, double> _headerHeights = {}; // 默认 48
  final Map<String, List<double>> _rowHeights = {}; // 默认每行 56
  final List<double> _groupEnds = [];
  int _computedGroups = 0;
  static const int _chunkSize = 60;
  DateTime? _pendingScrollMonth; // 选月后待滚动定位

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
    // 上滑：到达底部切换到上一个月（仅按月视角）
    if (pos.atEdge && pos.pixels > 0 && delta > 0) {
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
    // 下拉：在顶部向下继续拉，尝试往“下一个月”（不超过当前月）
    if (pos.atEdge && pos.pixels <= 0 && delta < 0) {
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
    // 需求4：移除“年视角”，固定为按月（不再使用 view 变量）
    final hide = ref.watch(hideAmountsProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Consumer(builder: (context, ref, _) {
            ref.watch(headerStyleProvider);
            return PrimaryHeader(
              // 年在上
              title: '${month.year}年',
              // 月在下
              subtitle: '${month.month.toString().padLeft(2, '0')}月',
              subtitleTrailing: InkWell(
                onTap: () async {
                  final res = await showWheelDatePicker(
                    context,
                    initial: month,
                    mode: WheelDatePickerMode.ym,
                    maxDate: DateTime.now(),
                  );
                  if (res != null) {
                    final target = DateTime(res.year, res.month, 1);
                    ref.read(selectedMonthProvider.notifier).state = target;
                    // 标记等待滚动到该月份
                    setState(() {
                      _pendingScrollMonth = target;
                    });
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
              stream: repo.transactionsWithCategoryAll(ledgerId: ledgerId),
              builder: (context, snapshot) {
                final joined = snapshot.data ?? [];
                return FutureBuilder<(double income, double expense)>(
                  future: repo.monthlyTotals(ledgerId: ledgerId, month: month),
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
                    final sortedKeys = groups.keys.toList()
                      ..sort((a, b) => b.compareTo(a));

                    // 工具：上界二分
                    int upperBound(List<double> arr, double x) {
                      var l = 0, r = arr.length;
                      while (l < r) {
                        final m = (l + r) >> 1;
                        if (arr[m] >= x) {
                          r = m;
                        } else {
                          l = m + 1;
                        }
                      }
                      return l;
                    }

                    // 重置/同步缓存
                    void resetCachesIfNeeded() {
                      final sameLength =
                          _sortedKeysCache.length == sortedKeys.length;
                      final sameOrder = sameLength &&
                          _sortedKeysCache
                              .asMap()
                              .entries
                              .every((e) => e.value == sortedKeys[e.key]);
                      if (!sameOrder) {
                        _sortedKeysCache = List.of(sortedKeys);
                        _headerHeights
                          ..clear()
                          ..addEntries(sortedKeys.map((k) => MapEntry(k, 48)));
                        _rowHeights
                          ..clear()
                          ..addEntries(sortedKeys.map((k) => MapEntry(
                              k, List<double>.filled(groups[k]!.length, 56))));
                        _groupEnds.clear();
                        _computedGroups = 0;
                      } else {
                        // 行数变化（插入/删除）时同步长度
                        for (final k in sortedKeys) {
                          final need = groups[k]!.length;
                          final cur = _rowHeights[k]?.length ?? 0;
                          if (cur != need) {
                            _rowHeights[k] = List<double>.filled(need, 56);
                          }
                        }
                      }
                    }

                    // 段式增量计算 groupEnds（只计算新段）
                    void computeMore(int count) {
                      if (_computedGroups > _sortedKeysCache.length) {
                        _computedGroups = _sortedKeysCache.length;
                      }
                      final until = (_computedGroups + count)
                          .clamp(0, _sortedKeysCache.length);
                      double base;
                      if (_groupEnds.isEmpty) {
                        base = 0;
                      } else {
                        base = _groupEnds.last;
                      }
                      for (int i = _computedGroups; i < until; i++) {
                        final k = _sortedKeysCache[i];
                        base += (_headerHeights[k] ?? 0) +
                            (_rowHeights[k]?.fold<double>(0, (a, b) => a + b) ??
                                0);
                        _groupEnds.add(base);
                      }
                      _computedGroups = until;
                    }

                    // 重建已计算范围的 groupEnds（当高度回填改变时）
                    void rebuildComputedGroupEnds() {
                      _groupEnds.clear();
                      double acc = 0;
                      for (int i = 0; i < _computedGroups; i++) {
                        final k = _sortedKeysCache[i];
                        acc += (_headerHeights[k] ?? 0) +
                            (_rowHeights[k]?.fold<double>(0, (a, b) => a + b) ??
                                0);
                        _groupEnds.add(acc);
                      }
                    }

                    resetCachesIfNeeded();
                    if (_computedGroups == 0) computeMore(_chunkSize);

                    // 若有待滚动月份，则定位
                    if (_pendingScrollMonth != null && sortedKeys.isNotEmpty) {
                      final ym = _pendingScrollMonth!;
                      int idxMonth = 0;
                      for (int i = 0; i < sortedKeys.length; i++) {
                        final dt = DateTime.parse(sortedKeys[i]);
                        if (dt.year == ym.year && dt.month == ym.month) {
                          idxMonth = i;
                          break;
                        }
                      }
                      // 确保该下标已在已计算范围内
                      if (idxMonth >= _computedGroups) {
                        computeMore(
                            ((idxMonth - _computedGroups) ~/ _chunkSize + 1) *
                                _chunkSize);
                      }
                      final target =
                          idxMonth == 0 ? 0.0 : _groupEnds[idxMonth - 1];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(target);
                        }
                      });
                      _pendingScrollMonth = null;
                    }

                    // 真实测量每个分组头和行的高度，构建累积高度表
                    final headerHeights = <String, double>{};
                    final rowHeights = <String, List<double>>{};
                    final groupEnds = <double>[];
                    double acc = 0;
                    for (final key in sortedKeys) {
                      final rows = groups[key]!;
                      final rowsHeights = List<double>.filled(rows.length, 56);
                      rowHeights[key] = rowsHeights;
                      headerHeights[key] = 48;
                      // 先占位，后续通过 MeasureSize 回填再重建 groupEnds
                      acc += headerHeights[key]! +
                          rowsHeights.fold(0, (a, b) => a + b);
                      groupEnds.add(acc);
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification &&
                            _scrollController.positions.isNotEmpty &&
                            sortedKeys.isNotEmpty) {
                          // 二分定位当前分组；若滚过已计算范围则增量扩展
                          final offset = _scrollController.offset;
                          if (_groupEnds.isNotEmpty &&
                              offset > _groupEnds.last &&
                              _computedGroups < _sortedKeysCache.length) {
                            computeMore(_chunkSize);
                          }
                          final idx = upperBound(_groupEnds, offset);
                          if (idx >= 0 && idx < _computedGroups) {
                            final key = sortedKeys[idx];
                            final dt = DateTime.parse(key);
                            final cur = DateTime(dt.year, dt.month, 1);
                            final sel = ref.read(selectedMonthProvider);
                            if (sel.year != cur.year ||
                                sel.month != cur.month) {
                              ref.read(selectedMonthProvider.notifier).state =
                                  cur;
                            }
                          }
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.zero,
                        itemCount: (sortedKeys.isEmpty
                            ? 1
                            : sortedKeys
                                .map((k) => 1 + groups[k]!.length)
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
                              final isFirst = key == sortedKeys.first;
                              return Column(
                                children: [
                                  if (!isFirst)
                                    Divider(height: 1, color: Colors.grey[200]),
                                  MeasureSize(
                                    onChange: (size) {
                                      final old = _headerHeights[key];
                                      if (old != size.height) {
                                        _headerHeights[key] = size.height;
                                        rebuildComputedGroupEnds();
                                      }
                                    },
                                    child: _DayHeader(
                                      dateText: key,
                                      income: dayIncome,
                                      expense: dayExpense,
                                      hide: hide,
                                    ),
                                  ),
                                ],
                              );
                            }
                            idx--;
                            if (idx < list.length) {
                              final rowIndex = idx;
                              final it = list[rowIndex];
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
                                if (name.contains('购物') ||
                                    name.contains('百货')) {
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
                                if (name.contains('娱乐') ||
                                    name.contains('游戏')) {
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
                                if (name.contains('快递') ||
                                    name.contains('邮寄')) {
                                  return Icons.local_shipping_outlined;
                                }
                                if (name.contains('税') ||
                                    name.contains('社保') ||
                                    name.contains('公积金')) {
                                  return Icons.receipt_long_outlined;
                                }
                                if (name.contains('捐赠') ||
                                    name.contains('公益')) {
                                  return Icons.volunteer_activism_outlined;
                                }
                                return Icons.circle_outlined;
                              }

                              final subtitle = it.t.note ?? '';
                              return Dismissible(
                                key: ValueKey(it.t.id),
                                direction: DismissDirection.endToStart,
                                background:
                                    Container(color: Colors.transparent),
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
                                                        child:
                                                            const Text('取消')),
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
                                    MeasureSize(
                                      onChange: (size) {
                                        if (_rowHeights[key] != null &&
                                            rowIndex >= 0 &&
                                            rowIndex <
                                                _rowHeights[key]!.length) {
                                          final old =
                                              _rowHeights[key]![rowIndex];
                                          if (old != size.height) {
                                            _rowHeights[key]![rowIndex] =
                                                size.height;
                                            rebuildComputedGroupEnds();
                                          }
                                        }
                                      },
                                      child: ListTile(
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
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontSize: 14,
                                                  color: Colors.black87),
                                        ),
                                        subtitle: null,
                                        trailing: Text(
                                          hide
                                              ? '****'
                                              : '$amountPrefix${it.t.amount.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontSize: 14,
                                                  color: Colors.black87),
                                        ),
                                        onTap: () async {
                                          // 需求3：点击明细后默认分类+弹出金额备注
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CategoryPickerPage(
                                                initialKind: it.t.type,
                                                quickAdd: true,
                                                initialCategoryId:
                                                    it.t.categoryId,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // 需求2：底部分割线缩短（从分类到金额），颜色略淡
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 56 + 16, right: 16),
                                      child: Divider(
                                          height: 1,
                                          color:
                                              Colors.black12.withOpacity(0.06)),
                                    ),
                                  ],
                                ),
                              );
                            }
                            idx -= list.length;
                          }
                          return const SizedBox.shrink();
                        },
                      ),
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
    // 需求1：头部全灰且字体一致；金额为 0.00 时不展示
    String fmt(double v) => v == 0 ? '' : v.toStringAsFixed(2);
    final grey = Colors.black54;
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
                    .labelMedium
                    ?.copyWith(color: grey, fontSize: 12)),
            if (week.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(week,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            ]
          ]),
          Row(children: [
            if (!hide && fmt(expense).isNotEmpty)
              Text('支出 ${fmt(expense)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
            if (!hide && fmt(expense).isNotEmpty) const SizedBox(width: 12),
            if (!hide && fmt(income).isNotEmpty)
              Text('收入 ${fmt(income)}',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: grey, fontSize: 12)),
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

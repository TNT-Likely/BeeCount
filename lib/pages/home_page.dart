import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import 'personalize_page.dart' show headerStyleProvider;
import '../data/db.dart';
import '../widgets/primary_header.dart';
import 'category_picker.dart';
import '../widgets/wheel_date_picker.dart';
import '../widgets/category_icon.dart';
import '../widgets/common.dart';
import '../styles/design.dart';
import '../styles/colors.dart';
// import 'package:beecount/widgets/wheel_date_picker.dart';
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
            final hide = ref.watch(hideAmountsProvider);
            return PrimaryHeader(
              title: '',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 第一行：中间品牌名，右边小眼睛
                  Row(
                    children: [
                      // 标题左侧放日期选择图标
                      IconButton(
                        tooltip: '选择日期',
                        onPressed: () async {
                          final res = await showWheelDatePicker(
                            context,
                            initial: month,
                            mode: WheelDatePickerMode.ym,
                            maxDate: DateTime.now(),
                          );
                          if (res != null) {
                            ref.read(selectedMonthProvider.notifier).state =
                                DateTime(res.year, res.month, 1);
                            _pendingScrollMonth =
                                DateTime(res.year, res.month, 1);
                          }
                        },
                        icon: const Icon(Icons.calendar_month,
                            size: 18, color: BeeColors.primaryText),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '蜜蜂记账',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: BeeColors.primaryText,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
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
                          size: 18,
                          color: BeeColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 第二行
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左：年/月上下排列，月份旁日期图标
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          final res = await showWheelDatePicker(
                            context,
                            initial: month,
                            mode: WheelDatePickerMode.ym,
                            maxDate: DateTime.now(),
                          );
                          if (res != null) {
                            ref.read(selectedMonthProvider.notifier).state =
                                DateTime(res.year, res.month, 1);
                            _pendingScrollMonth =
                                DateTime(res.year, res.month, 1);
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${month.year}年',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                        color: BeeColors.secondaryText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${month.month.toString().padLeft(2, '0')}月',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: BeeColors.primaryText,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // 细竖线分割
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 1,
                        height: 36,
                        color: Colors.black12,
                      ),
                      // 右：汇总三等分、左对齐
                      Expanded(child: _HeaderCenterSummary(hide: hide)),
                    ],
                  ),
                ],
              ),
              // 去掉头部下方的小提示
              bottom: null,
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
                            return const AppEmpty(text: '暂无数据，点击右下角记一笔');
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
                                    child: DaySectionHeader(
                                        dateText: key,
                                        income: dayIncome,
                                        expense: dayExpense,
                                        hide: hide),
                                  ),
                                ],
                              );
                            }
                            idx--;
                            if (idx < list.length) {
                              final rowIndex = idx;
                              final it = list[rowIndex];
                              final isExpense = it.t.type == 'expense';
                              final categoryName = it.category?.name ?? '未分类';

                              final subtitle = it.t.note ?? '';
                              final isLastInGroup = rowIndex == list.length - 1;
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
                                      child: TransactionListItem(
                                        icon: iconForCategory(categoryName),
                                        title: subtitle.isNotEmpty
                                            ? subtitle
                                            : categoryName,
                                        amount: it.t.amount,
                                        isExpense: isExpense,
                                        hide: hide,
                                        onTap: () async {
                                          await Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CategoryPickerPage(
                                                initialKind: it.t.type,
                                                quickAdd: true,
                                                initialCategoryId:
                                                    it.t.categoryId,
                                                initialAmount: it.t.amount,
                                                initialDate: it.t.happenedAt,
                                                initialNote: it.t.note,
                                                editingTransactionId: it.t.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // 需求2：底部分割线缩短（从分类到金额），颜色略淡
                                    if (!isLastInGroup)
                                      AppDivider.short(
                                          indent: 56 + 16, endIndent: 16),
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
    return FutureBuilder<(double income, double expense)>(
      future: repo.monthlyTotals(ledgerId: ledgerId, month: month),
      builder: (context, snap) {
        final income = (snap.data?.$1) ?? 0.0;
        final expense = (snap.data?.$2) ?? 0.0;
        final balance = income - expense;
        Widget item(String title, double value) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: BeeColors.secondaryText, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  hide ? '****' : value.toStringAsFixed(2),
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: BeeColors.primaryText,
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                      ),
                ),
              ],
            );
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: item('收入', income)),
            const SizedBox(width: 8),
            Expanded(child: item('支出', expense)),
            const SizedBox(width: 8),
            Expanded(child: item('结余', balance)),
          ],
        );
      },
    );
  }
}

// 顶部插画/卡片装饰，可按需替换为图片资源
// _HeaderDecor 已移除

// 旧的渐变统计卡与快捷入口行已移除，顶部统计改为白色背景的 _TopSummaryBar。

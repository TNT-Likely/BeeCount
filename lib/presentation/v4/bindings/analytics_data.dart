import '../../../data/db.dart' as db;
import '../../../utils/month_range.dart';
import '../../../utils/analytics_average.dart';

typedef AnalyticsCategory = ({
  int? id,
  String name,
  db.Category? category,
  double total,
  List<
      ({int id, db.Category category, String name, double total})> subCategories
});

class AnalyticsResult {
  const AnalyticsResult(
      {required this.categories,
      required this.series,
      required this.start,
      required this.end,
      required this.count,
      required this.total,
      required this.average,
      required this.empty});
  final List<AnalyticsCategory> categories;
  final dynamic series;
  final DateTime start, end;
  final int count;
  final double total, average;
  final bool empty;
  List<double> get values => analyticsSeriesValues(series);
}

Future<AnalyticsResult> loadAnalyticsData(dynamic repo,
    {required int ledgerId,
    required String scope,
    required String type,
    required DateTime selMonth,
    required int startDay,
    DateTime? clock}) async {
  // 时间范围
  late DateTime start;
  late DateTime end;
  final now = clock ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final sd = startDay;
  if (scope == 'month') {
    final range = periodForLabel(selMonth.year, selMonth.month, sd);
    start = range.start;
    // 「当前周期」判定用周期标签，不能用自然月相等(6月5日属5月周期)
    final nowLabel = labelForDate(now, sd);
    final isCurrentPeriod =
        selMonth.year == nowLabel.year && selMonth.month == nowLabel.month;
    // 当前周期：只到今天；历史周期：到周期末
    end = isCurrentPeriod ? today.add(const Duration(days: 1)) : range.end;
  } else if (scope == 'year') {
    final range = yearRangeFor(selMonth.year, sd);
    start = range.start;
    // 当前年度周期：只到今天；历史：到年度周期末
    final isCurrentYear = !now.isBefore(range.start) && now.isBefore(range.end);
    end = isCurrentYear ? today.add(const Duration(days: 1)) : range.end;
  } else {
    start = DateTime(1970, 1, 1);
    end = today.add(const Duration(days: 1));
  }

  // 按视角获取序列
  Future<dynamic> seriesFuture;
  Future<dynamic>? incomeSeriesFuture;
  Future<dynamic>? expenseSeriesFuture;

  if (type == 'balance') {
    // 结余模式：同时获取收入和支出数据
    if (scope == 'month') {
      incomeSeriesFuture = repo.totalsByDay(
          ledgerId: ledgerId, type: 'income', start: start, end: end);
      expenseSeriesFuture = repo.totalsByDay(
          ledgerId: ledgerId, type: 'expense', start: start, end: end);
      seriesFuture = Future.value([]); // 占位
    } else if (scope == 'year') {
      incomeSeriesFuture = repo.totalsByMonth(
          ledgerId: ledgerId, type: 'income', year: selMonth.year);
      expenseSeriesFuture = repo.totalsByMonth(
          ledgerId: ledgerId, type: 'expense', year: selMonth.year);
      seriesFuture = Future.value([]);
    } else {
      incomeSeriesFuture =
          repo.totalsByYearSeries(ledgerId: ledgerId, type: 'income');
      expenseSeriesFuture =
          repo.totalsByYearSeries(ledgerId: ledgerId, type: 'expense');
      seriesFuture = Future.value([]);
    }
  } else {
    // 收入或支出模式
    seriesFuture = scope == 'month'
        ? repo.totalsByDay(
            ledgerId: ledgerId, type: type, start: start, end: end)
        : scope == 'year'
            ? repo.totalsByMonth(
                ledgerId: ledgerId, type: type, year: selMonth.year)
            : repo.totalsByYearSeries(ledgerId: ledgerId, type: type);
  }

  final list = type == 'balance'
      ? await _loadBalanceData(repo, ledgerId, start, end, seriesFuture,
          incomeSeriesFuture!, expenseSeriesFuture!)
      : await _loadCategoryData(repo, ledgerId, type, start, end, seriesFuture);
  dynamic seriesRaw;
  final catData = list[0] as List<AnalyticsCategory>;
  final int txCount;
  final double sum;
  if (type == 'balance') {
    seriesRaw = _calculateBalanceSeries(list[3], list[4]);
    txCount = (list[2] as int) + (list[5] as int);
    sum = _getSumFromSeries(list[3]) - _getSumFromSeries(list[4]);
  } else {
    seriesRaw = list[1];
    txCount = list[2] as int;
    sum = catData.fold<double>(0, (a, b) => a + b.total);
  }
  final rawValues = analyticsSeriesValues(seriesRaw);
  final empty = txCount == 0 ||
      (sum == 0 && (rawValues.isEmpty || rawValues.every((v) => v == 0)));
  if (seriesRaw is List<({DateTime month, double total})>) {
    final label = labelForDate(now, sd);
    if (selMonth.year == label.year) {
      seriesRaw = seriesRaw.where((e) => e.month.month <= label.month).toList();
    }
  } else if (seriesRaw is List<({int year, double total})>) {
    seriesRaw = seriesRaw.where((e) => e.year <= now.year).toList();
  }
  return AnalyticsResult(
      categories: catData,
      series: seriesRaw,
      start: start,
      end: end,
      count: txCount,
      total: sum,
      average: computeSeriesAverage(seriesRaw),
      empty: empty);
}

List<double> analyticsSeriesValues(dynamic series) {
  if (series is List<({DateTime day, double total})>) {
    return series.map((e) => e.total).toList();
  }
  if (series is List<({DateTime month, double total})>) {
    return series.map((e) => e.total).toList();
  }
  if (series is List<({int year, double total})>) {
    return series.map((e) => e.total).toList();
  }
  return const [];
}

// 计算结余序列（收入 - 支出）
dynamic _calculateBalanceSeries(dynamic incomeData, dynamic expenseData) {
  if (incomeData is List<({DateTime day, double total})> &&
      expenseData is List<({DateTime day, double total})>) {
    final Map<DateTime, double> incomeMap = {
      for (var e in incomeData) e.day: e.total
    };
    final Map<DateTime, double> expenseMap = {
      for (var e in expenseData) e.day: e.total
    };
    final allDays = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allDays.map((day) {
      final income = incomeMap[day] ?? 0.0;
      final expense = expenseMap[day] ?? 0.0;
      return (day: day, total: income - expense);
    }).toList();
  }
  if (incomeData is List<({DateTime month, double total})> &&
      expenseData is List<({DateTime month, double total})>) {
    final Map<DateTime, double> incomeMap = {
      for (var e in incomeData) e.month: e.total
    };
    final Map<DateTime, double> expenseMap = {
      for (var e in expenseData) e.month: e.total
    };
    final allMonths = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allMonths.map((month) {
      final income = incomeMap[month] ?? 0.0;
      final expense = expenseMap[month] ?? 0.0;
      return (month: month, total: income - expense);
    }).toList();
  }
  if (incomeData is List<({int year, double total})> &&
      expenseData is List<({int year, double total})>) {
    final Map<int, double> incomeMap = {
      for (var e in incomeData) e.year: e.total
    };
    final Map<int, double> expenseMap = {
      for (var e in expenseData) e.year: e.total
    };
    final allYears = {...incomeMap.keys, ...expenseMap.keys}.toList()..sort();
    return allYears.map((year) {
      final income = incomeMap[year] ?? 0.0;
      final expense = expenseMap[year] ?? 0.0;
      return (year: year, total: income - expense);
    }).toList();
  }
  return [];
}

// 从序列数据中计算总和
double _getSumFromSeries(dynamic seriesData) {
  if (seriesData is List<({DateTime day, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  if (seriesData is List<({DateTime month, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  if (seriesData is List<({int year, double total})>) {
    return seriesData.fold<double>(0, (sum, e) => sum + e.total);
  }
  return 0.0;
}

// 加载分类数据并聚合
Future<List<dynamic>> _loadCategoryData(
  dynamic repo,
  int ledgerId,
  String type,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: type, start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: type, start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[3] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [aggregated, results[1], results[2]];
}

// 加载结余数据并聚合
Future<List<dynamic>> _loadBalanceData(
  dynamic repo,
  int ledgerId,
  DateTime start,
  DateTime end,
  Future<dynamic> seriesFuture,
  Future<dynamic> incomeSeriesFuture,
  Future<dynamic> expenseSeriesFuture,
) async {
  final results = await Future.wait<dynamic>([
    repo.totalsByCategoryWithHierarchy(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    seriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'expense', start: start, end: end),
    incomeSeriesFuture,
    expenseSeriesFuture,
    repo.countByTypeInRange(
        ledgerId: ledgerId, type: 'income', start: start, end: end),
    repo.getSharedSyntheticCategoriesForLedger(ledgerId),
  ]);

  final hierarchyData = results[0] as List<
      ({
        int? id,
        String name,
        String? icon,
        int? parentId,
        int level,
        double total
      })>;
  final sharedSynthetic = results[6] as Map<int, db.Category>;
  final aggregated =
      await _aggregateTopLevelCategories(hierarchyData, repo, sharedSynthetic);

  return [
    aggregated,
    results[1],
    results[2],
    results[3],
    results[4],
    results[5]
  ];
}

// 聚合一级分类数据（将二级分类金额聚合到一级分类）
Future<
    List<
        ({
          int? id,
          String name,
          db.Category? category,
          double total,
          List<
              ({
                int id,
                db.Category category,
                String name,
                double total
              })> subCategories
        })>> _aggregateTopLevelCategories(
    List<
            ({
              int? id,
              String name,
              String? icon,
              int? parentId,
              int level,
              double total
            })>
        hierarchyData,
    dynamic repo,
    Map<int, db.Category> sharedSynthetic) async {
  // 1. 先收集所有一级分类的完整信息
  // §7 共享账本:Editor 的 tx 用 SharedLedger* 表(synthetic 负 id),
  // 主表 getCategoryById 查不到。topLevelNames/Icons 兜底从 hierarchyData
  // 直接取,渲染时不再依赖 db.Category 对象。
  final topLevelInfo = <int, db.Category>{};
  final topLevelNames = <int?, String>{};
  final topLevelIcons = <int?, String?>{};
  for (final item in hierarchyData) {
    if (item.level == 1) {
      topLevelNames[item.id] = item.name;
      topLevelIcons[item.id] = item.icon;
      if (item.id != null && item.id! > 0) {
        // 主表正 id:查 db.Category
        final category = await repo.getCategoryById(item.id!);
        if (category != null) {
          topLevelInfo[item.id!] = category;
        }
      } else if (item.id != null && item.id! < 0) {
        // SharedLedger* synthetic 负 id:从 sharedSynthetic 取合成 Category
        // (含 iconType/customIconPath,UI 能正确渲染自定义图标)
        final synthetic = sharedSynthetic[item.id!];
        if (synthetic != null) {
          topLevelInfo[item.id!] = synthetic;
        }
      }
    }
  }

  // 2. 收集所有需要查询的父分类ID（二级分类的父分类，但在topLevelInfo中不存在的）
  final parentIdsToQuery = <int>{};
  for (final item in hierarchyData) {
    if (item.level == 2 &&
        item.parentId != null &&
        !topLevelInfo.containsKey(item.parentId!)) {
      parentIdsToQuery.add(item.parentId!);
    }
  }

  // 3. 查询缺失的父分类信息
  // §7 共享账本:负 id 是 SharedLedger* 的 synthetic id,主表 getCategoryById
  // 查不到 — fallback 到 sharedSynthetic map(已含所有 SharedLedger 分类)。
  // 顺便补 topLevelNames / topLevelIcons,让结果阶段(line 1146+)能正确
  // fallback 渲染 L1 分类名字 / 图标。
  for (final parentId in parentIdsToQuery) {
    if (parentId < 0 && sharedSynthetic.containsKey(parentId)) {
      final synthetic = sharedSynthetic[parentId]!;
      topLevelInfo[parentId] = synthetic;
      topLevelNames[parentId] = synthetic.name;
      topLevelIcons[parentId] = synthetic.icon;
      continue;
    }
    final category = await repo.getCategoryById(parentId);
    if (category != null) {
      topLevelInfo[parentId] = category;
    }
  }

  // 4. 聚合金额，同时收集子分类明细
  final topLevelMap = <int?, double>{};
  final subCategoriesMap = <int?,
      List<({int id, db.Category category, String name, double total})>>{};

  for (final item in hierarchyData) {
    if (item.level == 1) {
      // 一级分类：累加金额
      topLevelMap.update(item.id, (v) => v + item.total,
          ifAbsent: () => item.total);
    } else if (item.level == 2 && item.parentId != null) {
      // 二级分类：累加到父分类
      topLevelMap.update(item.parentId, (v) => v + item.total,
          ifAbsent: () => item.total);
      // 收集子分类明细 — §7 共享账本:负 id 的 L2 走 sharedSynthetic
      // fallback,主表 getCategoryById 查不到。这样点击一级分类才能展开
      // SharedLedger* 的子分类,点击子分类才能进 CategoryDetailPage。
      if (item.id != null) {
        db.Category? subCategory;
        if (item.id! < 0) {
          subCategory = sharedSynthetic[item.id!];
        } else {
          subCategory = await repo.getCategoryById(item.id!);
        }
        if (subCategory != null) {
          subCategoriesMap.putIfAbsent(item.parentId, () => []);
          subCategoriesMap[item.parentId]!.add((
            id: item.id!,
            category: subCategory,
            name: item.name,
            total: item.total,
          ));
        }
      }
    }
  }

  // 5. 对每个父分类的子分类按金额降序排列
  for (final subs in subCategoriesMap.values) {
    subs.sort((a, b) => b.total.compareTo(a.total));
  }

  // 6. 转换为列表并排序
  final result = topLevelMap.entries.map((e) {
    final id = e.key;
    final total = e.value;
    final subs = subCategoriesMap[id] ??
        <({int id, db.Category category, String name, double total})>[];

    // 获取一级分类信息
    if (id != null && topLevelInfo.containsKey(id)) {
      final category = topLevelInfo[id]!;
      return (
        id: id,
        name: category.name,
        category: category,
        total: total,
        subCategories: subs,
      );
    } else if (topLevelNames.containsKey(id)) {
      // SharedLedger* 兜底:有 name 但 db.Category 为 null,UI 用 name fallback
      return (
        id: id,
        name: topLevelNames[id]!,
        category: null,
        total: total,
        subCategories: subs,
      );
    } else {
      return (
        id: id,
        name: '未分类',
        category: null,
        total: total,
        subCategories: subs,
      );
    }
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  return result;
}

/// 净值趋势辅助工具:每日序列降采样为每月末值。
///
/// 净值趋势的原始序列是按天回算的(可能多达数百点),直接画进 sparkline / 全屏图
/// 会过于拥挤。这里按「年-月」聚合,同月后到的条目覆盖前者 —— 由于入参按日期升序,
/// 覆盖结果即每月最后一天的值(月末值),既保留趋势又显著减少点数。
///
/// 净资产卡的 sparkline 与全屏趋势页共用此函数。
List<({DateTime date, double assets, double liabilities, double net})>
    downsampleMonthly(
  List<({DateTime date, double assets, double liabilities, double net})> daily,
) {
  final byMonth =
      <String, ({DateTime date, double assets, double liabilities, double net})>{};
  for (final d in daily) {
    byMonth['${d.date.year}-${d.date.month}'] = d; // 同月后值覆盖 → 月末值
  }
  final list = byMonth.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return list;
}

/// 净值趋势查询的 endDate 锚点:当天 0 点(去掉时分秒微秒)。
///
/// netWorthTrendSeriesProvider 是 FutureProvider.family.autoDispose,family key 是
/// (startDate, endDate) record,按值比较。若直接用 DateTime.now() 当 endDate,每次
/// widget build 微秒都不同 → key 每次变 → 永远新建实例、永远 loading、UI 永不显示
/// (sparkline 一直 shrink、全屏页一直空白)。规整到「日」后同一天内 key 稳定,
/// provider 正常缓存命中。repo 内部本就把 endDate 截断到日级,锚点用 0 点无副作用。
DateTime trendTodayAnchor() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

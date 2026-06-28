/// 洞察页"日均 / 月均 / 年均"的统一求值(issue 修复)。
///
/// 口径:分母用**已发生的单位数**,而不是"有记账的单位数"。
///
/// 调用方传入的 `seriesRaw` 应已按时间范围裁剪到"已发生"区间
/// (见 analytics_page 的 filteredSeriesRaw:当前周期的天序列只到今天、
/// 当前年的月序列只到当前月、年序列只到当前年)——因此本函数直接对其
/// **全长**取平均:零值单位(没花钱的那天/那月)照样计入分母,把均值拉低,
/// 这才是用户期望的"日/月/年平均花费"。旧实现误用"金额>0 的单位数"做分母,
/// 会系统性高估(例如本月过了 30 天、只在 10 天有消费,会按 10 天平均)。
///
/// 支持三种序列形状:按天 / 按月 / 按年(Dart record 结构化匹配)。
/// 空序列返回 0;形状无法识别返回 0。
double computeSeriesAverage(dynamic seriesRaw) {
  if (seriesRaw is List<({DateTime day, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length; // ÷ 已发生天数
  }

  if (seriesRaw is List<({DateTime month, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length; // ÷ 已发生月数
  }

  if (seriesRaw is List<({int year, double total})>) {
    if (seriesRaw.isEmpty) return 0;
    final sum = seriesRaw.fold<double>(0, (a, b) => a + b.total);
    return sum / seriesRaw.length; // ÷ 已发生年数(年份跨度)
  }

  return 0;
}

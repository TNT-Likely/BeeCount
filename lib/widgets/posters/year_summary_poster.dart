/// 年度总结海报Widget
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/export/share_poster_types.dart';
import '../../services/data/category_service.dart';
import '../../l10n/app_localizations.dart';

/// 年度总结海报
class YearSummaryPoster extends StatelessWidget {
  final YearSummaryPosterData data;
  final Color primaryColor;
  final bool hideIncome;

  const YearSummaryPoster({
    super.key,
    required this.data,
    required this.primaryColor,
    this.hideIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 创建渐变背景色
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor.withValues(alpha: 0.95),
        primaryColor.withValues(alpha: 0.85),
        Color.lerp(primaryColor, Colors.black, 0.3)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Container(
      width: 750,
      height: 1334,
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: Stack(
        children: [
          // 背景装饰图案
          ..._buildBackgroundPatterns(),

          // 主要内容
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题区域
                  _buildHeader(context),

                  const SizedBox(height: 35),

                  // 核心数据卡片
                  _buildCoreStatsCard(context),

                  const SizedBox(height: 25),

                  // TOP支出分类
                  _buildCategorySection(context),

                  const SizedBox(height: 25),

                  // 其他数据
                  _buildAdditionalStats(context),

                  const Spacer(),

                  // 底部Logo和slogan
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建背景装饰图案
  List<Widget> _buildBackgroundPatterns() {
    return [
      // 大圆形光晕
      Positioned(
        top: -100,
        right: -100,
        child: Container(
          width: 400,
          height: 400,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
      // 小圆形光晕
      Positioned(
        bottom: 100,
        left: -50,
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// 构建标题区域
  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo、App名称和年份标签放在一行
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(7),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo2.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.sharePosterAppName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 年份标签
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${data.year}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 主标题
              Text(
                l10n.sharePosterYearTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              // 副标题
              Text(
                l10n.sharePosterYearSubtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        // 右侧二维码
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: 'https://github.com/TNT-Likely/BeeCount',
              version: QrVersions.auto,
              size: 98,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.all(4),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建核心统计卡片
  Widget _buildCoreStatsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 记账天数和笔数（合并在一行）
          Row(
            children: [
              Expanded(
                child: _buildMiniStatColumn(
                  icon: Icons.calendar_today_rounded,
                  label: l10n.sharePosterRecordDays,
                  value: '${data.recordDays}',
                  unit: l10n.sharePosterUnitDay,
                  color: primaryColor,
                ),
              ),
              Container(width: 1, height: 55, color: Colors.grey[200]),
              Expanded(
                child: _buildMiniStatColumn(
                  icon: Icons.edit_note_rounded,
                  label: l10n.sharePosterRecordCount,
                  value: '${data.recordCount}',
                  unit: l10n.sharePosterUnitCount,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 总支出
          _buildStatRow(
            icon: Icons.trending_down_rounded,
            label: l10n.sharePosterTotalExpense,
            value: formatter.format(data.totalExpense),
            unit: l10n.sharePosterUnitYuan,
            color: const Color(0xFFFF6B6B),
            isHighlight: true,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 总收入
          _buildStatRow(
            icon: Icons.trending_up_rounded,
            label: l10n.sharePosterTotalIncome,
            value: hideIncome ? '**' : formatter.format(data.totalIncome),
            unit: l10n.sharePosterUnitYuan,
            color: const Color(0xFF51CF66),
            isHighlight: true,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 结余
          _buildBalanceRow(context, hideIncome),
        ],
      ),
    );
  }

  /// 构建统计行
  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    bool isHighlight = false,
  }) {
    return Row(
      children: [
        // 图标
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 18),
        // 标签
        Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        // 数值
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: isHighlight ? color : const Color(0xFF333333),
          ),
        ),
        const SizedBox(width: 6),
        // 单位
        Text(
          unit,
          style: TextStyle(
            fontSize: 18,
            color: Color(0xFF999999),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 构建紧凑的统计列
  Widget _buildMiniStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF999999),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建结余行
  Widget _buildBalanceRow(BuildContext context, bool hideIncome) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final isPositive = data.balance >= 0;
    final balanceColor =
        isPositive ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B);
    final balanceIcon =
        isPositive ? Icons.savings_rounded : Icons.warning_rounded;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: balanceColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(balanceIcon, color: balanceColor, size: 28),
          const SizedBox(width: 12),
          Text(
            isPositive
                ? l10n.sharePosterYearBalance
                : l10n.sharePosterYearDeficit,
            style: TextStyle(
              fontSize: 20,
              color: balanceColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            hideIncome
                ? '**'
                : '${isPositive ? '+' : ''}${formatter.format(data.balance)}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: balanceColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.sharePosterUnitYuan,
            style: TextStyle(
              fontSize: 18,
              color: balanceColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建分类统计区域
  Widget _buildCategorySection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (data.topExpenseCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          l10n.sharePosterTopExpense,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        // 分类列表
        ...data.topExpenseCategories.asMap().entries.map((entry) {
          final index = entry.key;
          final category = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < 2 ? 15 : 0),
            child: _buildCategoryItem(category, index + 1),
          );
        }),
      ],
    );
  }

  /// 构建分类项
  Widget _buildCategoryItem(CategoryTotal category, int rank) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final percentText = '${(category.percentage * 100).toStringAsFixed(1)}%';

    // 排名徽章颜色
    final rankColors = [
      const Color(0xFFFFD700), // 金色
      const Color(0xFFC0C0C0), // 银色
      const Color(0xFFCD7F32), // 铜色
    ];
    final rankColor = rankColors[rank - 1];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 排名徽章
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // 分类图标
          if (category.icon != null)
            Icon(
              CategoryService.getCategoryIcon(category.icon),
              size: 28,
              color: Colors.white,
            ),
          if (category.icon != null) const SizedBox(width: 12),
          // 分类名称
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 金额和占比
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${formatter.format(category.total)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                percentText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建额外统计信息
  Widget _buildAdditionalStats(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // 月均支出
          _buildInfoRow(
            l10n.sharePosterAvgMonthlyExpense,
            '¥${formatter.format(data.avgMonthlyExpense)}',
          ),
          const SizedBox(height: 18),
          // 月均收入
          _buildInfoRow(
            l10n.sharePosterAvgMonthlyIncome,
            '¥${formatter.format(data.avgMonthlyIncome)}',
          ),
          if (data.maxExpenseMonth != null) ...[
            const SizedBox(height: 18),
            // 最高支出月份
            _buildInfoRow(
              l10n.sharePosterMaxExpenseMonth,
              '${DateFormat.MMMM(l10n.localeName).format(DateTime(data.year, data.maxExpenseMonth!))} ¥${formatter.format(data.maxExpenseAmount!)}',
            ),
          ],
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 18,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 构建底部slogan
  Widget _buildFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(
        l10n.sharePosterSlogan,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

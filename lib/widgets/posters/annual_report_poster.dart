/// 年度账单长图海报Widget
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math' as math;

import '../../pages/report/annual_report_page.dart';
import '../../services/data/category_service.dart';
import '../../l10n/app_localizations.dart';

/// 年度账单长图海报
/// 将多个页面内容合并成一张长图用于分享
class AnnualReportPoster extends StatelessWidget {
  final AnnualReportData data;
  final Color primaryColor;
  final bool hideIncome;

  const AnnualReportPoster({
    super.key,
    required this.data,
    required this.primaryColor,
    this.hideIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: 750,
      color: primaryColor,
      child: Stack(
        children: [
          // 背景装饰 - 光晕和几何图形
          _buildBackgroundDecorations(),
          // 网格背景
          _buildGridPattern(),
          // 浮动装饰圆
          _buildFloatingDecorations(),
          // 主内容
          Column(
            children: [
              _buildHeader(context, l10n),
              _buildYearHighlight(context, l10n),
              _buildOverviewSection(context, l10n),
              _buildStatsSummary(context, l10n),
              _buildInsightsSection(context, l10n),
              _buildCategoriesSection(context, l10n),
              _buildMonthlyTrendSection(context, l10n),
              _buildSpecialMomentsSection(context, l10n),
              _buildAchievementsSection(context, l10n),
              _buildFooter(context, l10n),
            ],
          ),
        ],
      ),
    );
  }

  /// 网格背景
  Widget _buildGridPattern() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter:
              _GridPatternPainter(color: Colors.white.withValues(alpha: 0.03)),
        ),
      ),
    );
  }

  /// 浮动装饰 - 星星和几何元素
  Widget _buildFloatingDecorations() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // ===== 星星装饰 =====
            // 大星星 - 右上
            Positioned(
              top: 180,
              right: 60,
              child: _buildStar(size: 24, alpha: 0.6),
            ),
            // 中星星 - 左上
            Positioned(
              top: 320,
              left: 80,
              child: _buildStar(size: 16, alpha: 0.4),
            ),
            // 小星星 - 右侧
            Positioned(
              top: 550,
              right: 40,
              child: _buildStar(size: 12, alpha: 0.5),
            ),
            // 大星星 - 左中
            Positioned(
              top: 900,
              left: 50,
              child: _buildStar(size: 20, alpha: 0.5),
            ),
            // 小星星 - 右中
            Positioned(
              top: 1100,
              right: 90,
              child: _buildStar(size: 10, alpha: 0.4),
            ),
            // 中星星 - 左下
            Positioned(
              bottom: 800,
              left: 100,
              child: _buildStar(size: 14, alpha: 0.45),
            ),
            // 大星星 - 右下
            Positioned(
              bottom: 500,
              right: 70,
              child: _buildStar(size: 18, alpha: 0.5),
            ),
            // 小星星 - 左下
            Positioned(
              bottom: 300,
              left: 60,
              child: _buildStar(size: 12, alpha: 0.35),
            ),
            // 中星星 - 右底
            Positioned(
              bottom: 150,
              right: 120,
              child: _buildStar(size: 16, alpha: 0.4),
            ),

            // ===== 圆形装饰 =====
            // 顶部大圆环
            Positioned(
              top: 100,
              right: -60,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
              ),
            ),
            // 左侧小圆
            Positioned(
              top: 600,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // 底部圆环
            Positioned(
              bottom: 200,
              left: -50,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建星星装饰
  Widget _buildStar({required double size, required double alpha}) {
    return Icon(
      Icons.star_rounded,
      size: size,
      color: Colors.white.withValues(alpha: alpha),
    );
  }

  /// 背景装饰 - 使用白色光晕
  Widget _buildBackgroundDecorations() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // 顶部白色光晕
            Positioned(
              top: -150,
              left: 0,
              right: 0,
              child: Container(
                height: 500,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.5),
                    radius: 1.2,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.white.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            // 右侧光晕
            Positioned(
              top: 600,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 左下光晕
            Positioned(
              bottom: 300,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header with logo
  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 50, 40, 20),
      child: Row(
        children: [
          // Logo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                'assets/logo2.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.sharePosterAppName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.annualReportTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // QR Code
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: 'https://github.com/TNT-Likely/BeeCount',
              version: QrVersions.auto,
              size: 80,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// 年度大标题
  Widget _buildYearHighlight(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 年度数字
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.8),
              ],
            ).createShader(bounds),
            child: Text(
              '${data.year}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 100,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 副标题
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.annualReportSubtitle(data.year),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Overview section - 核心数据
  Widget _buildOverviewSection(BuildContext context, AppLocalizations l10n) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部装饰条
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor,
                  primaryColor.withValues(alpha: 0.7),
                  const Color(0xFFFF6B6B),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                // 记账概览标题
                Row(
                  children: [
                    Icon(Icons.analytics_rounded,
                        color: primaryColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      l10n.annualReportPage1Title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 收入支出
                Row(
                  children: [
                    Expanded(
                      child: _buildAmountCard(
                        icon: Icons.trending_up_rounded,
                        label: l10n.annualReportTotalIncome,
                        amount: hideIncome
                            ? '****'
                            : formatter.format(data.totalIncome),
                        color: const Color(0xFF4CAF50),
                        bgColor: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAmountCard(
                        icon: Icons.trending_down_rounded,
                        label: l10n.annualReportTotalExpense,
                        amount: formatter.format(data.totalExpense),
                        color: const Color(0xFFFF5252),
                        bgColor: const Color(0xFFFFEBEE),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 结余
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: data.netSavings >= 0
                          ? [const Color(0xFF4CAF50), const Color(0xFF66BB6A)]
                          : [const Color(0xFFFF5252), const Color(0xFFFF6B6B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (data.netSavings >= 0
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252))
                            .withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          data.netSavings >= 0
                              ? Icons.savings_rounded
                              : Icons.warning_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.annualReportNetSavings,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.netSavings >= 0 ? '恭喜你攒下了' : '今年花超了',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        hideIncome
                            ? '****'
                            : '${data.netSavings >= 0 ? '+' : ''}${formatter.format(data.netSavings)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        ' 元',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard({
    required IconData icon,
    required String label,
    required String amount,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '¥$amount',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 统计摘要 - 记账天数、笔数、日均支出
  Widget _buildStatsSummary(BuildContext context, AppLocalizations l10n) {
    final formatter = NumberFormat('#,##0', 'zh_CN');

    // 计算年度总天数：过去年份用全年天数，当前年份用截至今天的天数
    final now = DateTime.now();
    final isCurrentYear = data.year == now.year;
    final yearEnd = isCurrentYear ? now : DateTime(data.year, 12, 31);
    final yearStart = DateTime(data.year, 1, 1);
    final totalCalendarDays = yearEnd.difference(yearStart).inDays + 1;

    final dailyAvg =
        totalCalendarDays > 0 ? data.totalExpense / totalCalendarDays : 0;
    final monthlyAvg = data.totalExpense / 12;

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.calendar_today_rounded,
              value: '${data.totalDays}',
              unit: '天',
              label: l10n.annualReportTotalDays,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.receipt_long_rounded,
              value: '${data.totalRecords}',
              unit: '笔',
              label: l10n.annualReportTotalRecords,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.schedule_rounded,
              value: formatter.format(dailyAvg),
              unit: '元/天',
              label: '日均支出',
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.date_range_rounded,
              value: formatter.format(monthlyAvg),
              unit: '元/月',
              label: '月均支出',
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String unit,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  /// 年度洞察部分
  Widget _buildInsightsSection(BuildContext context, AppLocalizations l10n) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');

    // 计算平均每笔支出
    final avgExpensePerRecord =
        data.totalRecords > 0 ? data.totalExpense / data.totalRecords : 0.0;

    // 找出记账笔数最多的月份
    int busiestMonth = 1;
    double maxMonthlyTotal = 0;
    for (final m in data.monthlyData) {
      final total = m.income + m.expense;
      if (total > maxMonthlyTotal) {
        maxMonthlyTotal = total;
        busiestMonth = m.month;
      }
    }

    // 计算储蓄率
    final savingsRate =
        data.totalIncome > 0 ? (data.netSavings / data.totalIncome * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.lightbulb_rounded,
            title: '年度洞察',
            subtitle: '从数据中发现你的消费习惯',
          ),
          const SizedBox(height: 20),

          // 洞察卡片网格
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  icon: Icons.receipt_long_rounded,
                  title: '平均每笔',
                  value: '¥${formatter.format(avgExpensePerRecord)}',
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  icon: Icons.calendar_month_rounded,
                  title: '最活跃月份',
                  value: '$busiestMonth月',
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  icon: Icons.category_rounded,
                  title: '消费分类',
                  value: '${data.topExpenseCategories.length}个',
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  icon: Icons.savings_rounded,
                  title: hideIncome ? '记账坚持' : '储蓄率',
                  value: hideIncome
                      ? '${data.maxConsecutiveDays}天'
                      : '${savingsRate.toStringAsFixed(1)}%',
                  // 储蓄率用红绿色区分正负
                  color: savingsRate >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5252),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Categories section
  Widget _buildCategoriesSection(BuildContext context, AppLocalizations l10n) {
    if (data.topExpenseCategories.isEmpty) return const SizedBox.shrink();

    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final rankColors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
      Colors.white.withValues(alpha: 0.6),
      Colors.white.withValues(alpha: 0.6),
    ];
    final rankBgColors = [
      const Color(0xFFFFF8E1),
      const Color(0xFFF5F5F5),
      const Color(0xFFFFE0B2),
      Colors.grey[100]!,
      Colors.grey[100]!,
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          _buildSectionTitle(
            icon: Icons.pie_chart_rounded,
            title: l10n.annualReportPage2Title,
            subtitle: l10n.annualReportPage2Subtitle,
          ),
          const SizedBox(height: 20),

          // 分类卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: data.topExpenseCategories.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final isLast = index == data.topExpenseCategories.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          // 排名徽章
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: rankBgColors[math.min(index, 4)],
                              shape: BoxShape.circle,
                              border: index < 3
                                  ? Border.all(
                                      color: rankColors[index], width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: index < 3
                                      ? rankColors[index]
                                      : Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // 图标
                          if (category.icon != null)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                CategoryService.getCategoryIcon(category.icon),
                                color: primaryColor,
                                size: 22,
                              ),
                            ),
                          const SizedBox(width: 12),
                          // 名称
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // 进度条
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: category.percentage,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation(
                                      index < 3
                                          ? rankColors[index]
                                          : primaryColor,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // 金额和占比
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${formatter.format(category.total)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              Text(
                                '${(category.percentage * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: Colors.grey[200]),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Monthly trend section
  Widget _buildMonthlyTrendSection(
      BuildContext context, AppLocalizations l10n) {
    final formatter = NumberFormat('#,##0', 'zh_CN');

    // Find highest and lowest month
    double maxExpense = 0;
    double minExpense = double.infinity;
    int maxMonth = 1;
    int minMonth = 1;

    for (final m in data.monthlyData) {
      if (m.expense > maxExpense) {
        maxExpense = m.expense;
        maxMonth = m.month;
      }
      if (m.expense < minExpense && m.expense > 0) {
        minExpense = m.expense;
        minMonth = m.month;
      }
    }
    if (minExpense == double.infinity) minExpense = 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.show_chart_rounded,
            title: l10n.annualReportPage3Title,
            subtitle: l10n.annualReportPage3Subtitle,
          ),
          const SizedBox(height: 20),

          // Highest and lowest cards
          Row(
            children: [
              Expanded(
                child: _buildHighlightMonthCard(
                  label: l10n.annualReportHighestMonth,
                  month: '$maxMonth月',
                  amount: '¥${formatter.format(maxExpense)}',
                  color: const Color(0xFFFF5252),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHighlightMonthCard(
                  label: l10n.annualReportLowestMonth,
                  month: '$minMonth月',
                  amount: '¥${formatter.format(minExpense)}',
                  color: const Color(0xFF4CAF50),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bar chart
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      '月度支出趋势',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.monthlyData.map((m) {
                      final heightRatio =
                          maxExpense > 0 ? m.expense / maxExpense : 0.0;
                      final isMax = m.month == maxMonth;
                      final isMin = m.month == minMonth;
                      final barColor = isMax
                          ? const Color(0xFFFF5252)
                          : isMin
                              ? const Color(0xFF4CAF50)
                              : primaryColor.withValues(alpha: 0.6);

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: 120 * heightRatio,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      barColor,
                                      barColor.withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                  ),
                                  boxShadow: (isMax || isMin)
                                      ? [
                                          BoxShadow(
                                            color:
                                                barColor.withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${m.month}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: (isMax || isMin)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: (isMax || isMin)
                                      ? barColor
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightMonthCard({
    required String label,
    required String month,
    required String amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  month,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  amount,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Special moments section
  Widget _buildSpecialMomentsSection(
      BuildContext context, AppLocalizations l10n) {
    final formatter = NumberFormat('#,##0.00', 'zh_CN');
    final dateFormatter = DateFormat('MM月dd日');

    final moments = <({
      String label,
      String amount,
      String note,
      String date,
      Color color,
      IconData icon
    })>[];

    if (data.largestExpense != null) {
      moments.add((
        label: l10n.annualReportLargestExpense,
        amount: formatter.format(data.largestExpense!.amount),
        note: data.largestExpense!.note ??
            data.largestExpenseCategory?.name ??
            '',
        date: dateFormatter.format(data.largestExpense!.happenedAt),
        color: const Color(0xFFFF5252),
        icon: Icons.arrow_downward_rounded,
      ));
    }

    if (data.largestIncome != null) {
      moments.add((
        label: l10n.annualReportLargestIncome,
        amount:
            hideIncome ? '****' : formatter.format(data.largestIncome!.amount),
        note:
            data.largestIncome!.note ?? data.largestIncomeCategory?.name ?? '',
        date: dateFormatter.format(data.largestIncome!.happenedAt),
        color: const Color(0xFF4CAF50),
        icon: Icons.arrow_upward_rounded,
      ));
    }

    if (data.firstRecord != null) {
      moments.add((
        label: l10n.annualReportFirstRecord,
        amount: formatter.format(data.firstRecord!.amount),
        note: data.firstRecord!.note ?? data.firstRecordCategory?.name ?? '',
        date: dateFormatter.format(data.firstRecord!.happenedAt),
        color: primaryColor,
        icon: Icons.flag_rounded,
      ));
    }

    if (moments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.star_rounded,
            title: l10n.annualReportPage4Title,
            subtitle: l10n.annualReportPage4Subtitle,
          ),
          const SizedBox(height: 20),
          ...moments.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMomentCard(
                  icon: m.icon,
                  label: m.label,
                  amount: m.amount,
                  note: m.note,
                  date: m.date,
                  color: m.color,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMomentCard({
    required IconData icon,
    required String label,
    required String amount,
    required String note,
    required String date,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '¥$amount',
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Achievements section
  Widget _buildAchievementsSection(
      BuildContext context, AppLocalizations l10n) {
    final achievements = [
      (
        title: l10n.annualReportAchievementConsistent,
        desc:
            l10n.annualReportAchievementConsistentDesc(data.maxConsecutiveDays),
        icon: Icons.local_fire_department_rounded,
        unlocked: data.maxConsecutiveDays >= 7,
        color: primaryColor, // 使用主题色
      ),
      (
        title: l10n.annualReportAchievementSaver,
        desc: l10n.annualReportAchievementSaverDesc,
        icon: Icons.savings_rounded,
        unlocked: data.netSavings > 0,
        color: const Color(0xFF4CAF50), // 储蓄用绿色
      ),
      (
        title: l10n.annualReportAchievementDetail,
        desc: l10n.annualReportAchievementDetailDesc(data.totalRecords),
        icon: Icons.auto_awesome_rounded,
        unlocked: data.totalRecords >= 100,
        color: primaryColor, // 使用主题色
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(40, 30, 40, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            icon: Icons.emoji_events_rounded,
            title: l10n.annualReportPage5Title,
            subtitle: l10n.annualReportPage5Subtitle,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: achievements.asMap().entries.map((entry) {
                final index = entry.key;
                final a = entry.value;
                final isLast = index == achievements.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          // 成就图标
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: a.unlocked
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        a.color,
                                        a.color.withValues(alpha: 0.7),
                                      ],
                                    )
                                  : null,
                              color: a.unlocked ? null : Colors.grey[200],
                              shape: BoxShape.circle,
                              boxShadow: a.unlocked
                                  ? [
                                      BoxShadow(
                                        color: a.color.withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              a.icon,
                              color:
                                  a.unlocked ? Colors.white : Colors.grey[400],
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: TextStyle(
                                    color: a.unlocked
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.grey[400],
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  a.desc,
                                  style: TextStyle(
                                    color: a.unlocked
                                        ? Colors.grey[600]
                                        : Colors.grey[400],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 状态标识
                          if (a.unlocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: a.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check, color: a.color, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '已达成',
                                    style: TextStyle(
                                      color: a.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline,
                                      color: Colors.grey[400], size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '未达成',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: Colors.grey[200]),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Footer
  Widget _buildFooter(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 50),
      child: Column(
        children: [
          // 装饰线
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.sharePosterSlogan,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '扫码下载蜜蜂记账，开启你的记账之旅',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// 网格背景绘制器
class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 60.0;

    // 绘制垂直线
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 绘制水平线
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

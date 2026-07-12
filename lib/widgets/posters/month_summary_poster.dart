/// 月度总结海报Widget
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/export/share_poster_types.dart';
import '../../services/data/category_service.dart';
import '../../l10n/app_localizations.dart';

/// 月度总结海报
class MonthSummaryPoster extends StatelessWidget {
  final MonthSummaryPosterData data;
  final Color primaryColor;
  final bool hideIncome;

  const MonthSummaryPoster({
    super.key,
    required this.data,
    required this.primaryColor,
    this.hideIncome = false,
  });

  /// 是否显示省钱横幅
  bool get _hasSavedMoneyBanner =>
      data.expenseChangeRate != null && data.expenseChangeRate! < 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 创建渐变背景色 - 月度用更清新的配色
    final lightPrimary = Color.lerp(primaryColor, Colors.white, 0.7)!;
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lightPrimary,
        Colors.white,
      ],
    );

    return Container(
      width: 750,
      height: 1334,
      decoration: BoxDecoration(
        gradient: gradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题区域
              _buildHeader(context),

              const SizedBox(height: 40),

              // 核心数据卡片
              _buildCoreStatsCard(context),

              const SizedBox(height: 30),

              // TOP支出分类
              if (data.topExpenseCategories.isNotEmpty) ...[
                _buildCategorySection(context),
                const SizedBox(height: 30),
              ],

              // 其他数据
              _buildAdditionalStats(context),

              const Spacer(),

              // 底部Logo
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建副标题（省钱时显示省钱信息）
  Widget _buildSubtitle(BuildContext context, AppLocalizations l10n) {
    if (_hasSavedMoneyBanner) {
      // 省钱时显示省钱文案
      final formatter = NumberFormat('#,##0', 'zh_CN');
      final rate = data.expenseChangeRate!;
      final savedAmount = data.totalExpense * (-rate) / (1 + rate);
      // 使用与主题色协调的绿色
      const savedColor = Color(0xFF4CAF50);

      return Row(
        children: [
          Icon(
            Icons.trending_down_rounded,
            color: savedColor,
            size: 22,
          ),
          const SizedBox(width: 6),
          Text(
            '${l10n.sharePosterSavedMoneyTitle} ¥${formatter.format(savedAmount)}',
            style: TextStyle(
              color: savedColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // 默认副标题
    return Text(
      l10n.sharePosterMonthSubtitle,
      style: TextStyle(
        color: primaryColor.withValues(alpha: 0.6),
        fontSize: 18,
      ),
    );
  }

  /// 构建标题区域
  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 使用 DateFormat 来根据语言环境格式化年月
    final date = DateTime(data.year, data.month);
    final yearFormat = DateFormat.y(l10n.localeName);
    final monthFormat = DateFormat.MMMM(l10n.localeName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 年月标签
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      yearFormat.format(date),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      monthFormat.format(date),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 主标题
              Text(
                l10n.sharePosterMonthTitle,
                style: TextStyle(
                  color: primaryColor.withValues(alpha: 0.9),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              // 副标题（省钱时显示省钱信息）
              _buildSubtitle(context, l10n),
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
                  color: primaryColor.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: 'https://github.com/TNT-Likely/BeeCount',
              version: QrVersions.auto,
              size: 84,
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
      padding: const EdgeInsets.all(35),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 支出收入行
          Row(
            children: [
              Expanded(
                child: _buildStatColumn(
                  context,
                  label: l10n.sharePosterTotalExpense,
                  value: formatter.format(data.totalExpense),
                  color: const Color(0xFFFF6B6B),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildStatColumn(
                  context,
                  label: l10n.sharePosterTotalIncome,
                  value: hideIncome ? '**' : formatter.format(data.totalIncome),
                  color: const Color(0xFF51CF66),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),
          const Divider(),
          const SizedBox(height: 25),

          // 结余和记账笔数
          Row(
            children: [
              Expanded(
                child: _buildStatColumn(
                  context,
                  label: l10n.sharePosterMonthBalance,
                  value: hideIncome ? '**' : formatter.format(data.balance),
                  color: data.balance >= 0
                      ? const Color(0xFF51CF66)
                      : const Color(0xFFFF6B6B),
                  icon: data.balance >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  showSign: !hideIncome,
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildStatColumn(
                  context,
                  label: l10n.sharePosterRecordCount,
                  value: '${data.recordCount}',
                  color: primaryColor,
                  icon: Icons.edit_note_rounded,
                  unit: l10n.sharePosterUnitCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建统计列
  Widget _buildStatColumn(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    String? unit,
    bool showSign = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final displayUnit = unit ?? l10n.sharePosterUnitYuan;
    return Column(
      children: [
        // 图标
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 12),
        // 标签
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF999999),
          ),
        ),
        const SizedBox(height: 8),
        // 数值
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showSign && value != '0.00')
              Text(
                value.startsWith('-') ? '' : '+',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                displayUnit,
                style: TextStyle(
                  fontSize: 14,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建分类统计区域
  Widget _buildCategorySection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          l10n.sharePosterTopExpense,
          style: TextStyle(
            color: primaryColor.withValues(alpha: 0.9),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        // 分类列表
        ...data.topExpenseCategories
            .take(3)
            .toList()
            .asMap()
            .entries
            .map((entry) {
          final index = entry.key;
          final category = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 图标
          if (category.icon != null)
            Icon(
              CategoryService.getCategoryIcon(category.icon),
              size: 24,
              color: primaryColor,
            ),
          if (category.icon != null) const SizedBox(width: 10),
          // 分类名称
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                percentText,
                style: TextStyle(
                  fontSize: 14,
                  color: primaryColor.withValues(alpha: 0.7),
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
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 日均支出
          _buildInfoRow(
            context,
            l10n.sharePosterAvgDailyExpense,
            '¥${formatter.format(data.avgDailyExpense)}',
            Icons.calendar_today_outlined,
          ),
          if (data.expenseChangeRate != null) ...[
            const SizedBox(height: 18),
            // 环比变化
            _buildChangeRow(context),
          ],
        ],
      ),
    );
  }

  /// 构建环比变化行
  Widget _buildChangeRow(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rate = data.expenseChangeRate!;
    final isIncrease = rate > 0;
    final color =
        isIncrease ? const Color(0xFFFF6B6B) : const Color(0xFF51CF66);
    final icon = isIncrease ? Icons.trending_up : Icons.trending_down;
    final text = isIncrease
        ? l10n.sharePosterIncreaseRate
        : l10n.sharePosterDecreaseRate;
    final percentText = '${(rate.abs() * 100).toStringAsFixed(1)}%';

    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          l10n.sharePosterCompareLastMonth,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              percentText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(
      BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 22),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF666666),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  /// 构建底部Logo
  Widget _buildFooter(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        children: [
          // Logo
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: ClipOval(
              child: Image.asset(
                'assets/logo2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // App名称
          Text(
            l10n.sharePosterAppName,
            style: TextStyle(
              color: primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Slogan
          Text(
            l10n.sharePosterSlogan,
            style: TextStyle(
              color: primaryColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

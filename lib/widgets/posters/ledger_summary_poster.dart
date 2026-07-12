/// 账本总结海报Widget
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/export/share_poster_types.dart';
import '../../services/data/category_service.dart';
import '../../l10n/app_localizations.dart';

/// 账本总结海报
class LedgerSummaryPoster extends StatelessWidget {
  final LedgerSummaryPosterData data;
  final Color primaryColor;
  final bool hideIncome;

  const LedgerSummaryPoster({
    super.key,
    required this.data,
    required this.primaryColor,
    this.hideIncome = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // 使用清新的单色背景 + 柔和渐变
    final lightPrimary = Color.lerp(primaryColor, Colors.white, 0.85)!;
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

              const SizedBox(height: 35),

              // 核心数据卡片
              _buildCoreStatsCard(context),

              const SizedBox(height: 25),

              // TOP支出分类
              if (data.topExpenseCategories.isNotEmpty)
                _buildCategorySection(context),

              if (data.topExpenseCategories.isNotEmpty)
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
    );
  }

  /// 构建背景装饰图案
  List<Widget> _buildBackgroundPatterns() {
    return [
      // 右上角圆形
      Positioned(
        right: -80,
        top: -80,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      // 左下角圆形
      Positioned(
        left: -100,
        bottom: 150,
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.03),
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
              // 账本名称标签
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  data.ledgerName,
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 主标题
              Text(
                l10n.sharePosterLedgerTitle,
                style: TextStyle(
                  color: primaryColor.withValues(alpha: 0.9),
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              // 时间范围
              if (data.firstRecordDate != null && data.lastRecordDate != null)
                Text(
                  '${DateFormat('yyyy.MM.dd').format(data.firstRecordDate!)} - ${DateFormat('yyyy.MM.dd').format(data.lastRecordDate!)}',
                  style: TextStyle(
                    color: primaryColor.withValues(alpha: 0.6),
                    fontSize: 16,
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
                  color: Colors.black.withValues(alpha: 0.1),
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
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 记账天数和笔数
          Row(
            children: [
              Expanded(
                child: _buildMiniStatColumn(
                  icon: Icons.calendar_today_rounded,
                  label: l10n.sharePosterRecordDays,
                  value: '${data.recordDays}',
                  unit: l10n.sharePosterUnitDay,
                  color: Colors.white,
                ),
              ),
              Container(
                width: 1,
                height: 55,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildMiniStatColumn(
                  icon: Icons.edit_note_rounded,
                  label: l10n.sharePosterRecordCount,
                  value: '${data.recordCount}',
                  unit: l10n.sharePosterUnitCount,
                  color: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

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
                color: Colors.white.withValues(alpha: 0.3),
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

          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),

          // 结余
          _buildStatColumn(
            context,
            label: l10n.sharePosterBalance,
            value: hideIncome ? '**' : formatter.format(data.balance),
            color: data.balance >= 0
                ? const Color(0xFF51CF66)
                : const Color(0xFFFF6B6B),
            icon: data.balance >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            showSign: !hideIncome,
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
            color: color.withValues(alpha: 0.2),
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
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建迷你统计列（用于记账天数和笔数）
  Widget _buildMiniStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color.withValues(alpha: 0.9), size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
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
            const SizedBox(width: 3),
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
          _buildInfoRow(
            context,
            l10n.sharePosterLedgerName,
            data.ledgerName,
            Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
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
                  color: Colors.black.withValues(alpha: 0.15),
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

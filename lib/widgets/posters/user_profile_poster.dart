/// 用户档案海报Widget
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../services/export/share_poster_types.dart';

/// 用户档案海报
class UserProfilePoster extends StatelessWidget {
  final UserProfilePosterData data;
  final AppLocalizations l10n;
  final Color primaryColor;

  const UserProfilePoster({
    super.key,
    required this.data,
    required this.l10n,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // 创建渐变背景色（与年度总结海报一致）
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
                  _buildHeader(),

                  const SizedBox(height: 40),

                  // 用户头像和账本名称
                  _buildProfileSection(),

                  const SizedBox(height: 35),

                  // 核心数据卡片
                  _buildCoreStatsCard(),

                  const SizedBox(height: 30),

                  // 记账历程
                  _buildJourneySection(),

                  const Spacer(),

                  // 底部Logo和slogan
                  _buildFooter(),
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
      // 中间装饰光晕
      Positioned(
        top: 400,
        right: -80,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  /// 构建标题区域
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo和App名称
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
                  // 标签
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      l10n.userProfilePosterRecordDays,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
              data:
                  'https://github.com/TNT-Likely/BeeCount?utm_source=share_poster&utm_medium=qr_code&utm_campaign=user_profile',
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

  /// 构建用户档案区域
  Widget _buildProfileSection() {
    return Center(
      child: Column(
        children: [
          // 用户头像
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 5,
              ),
            ),
            child: ClipOval(
              child: data.avatarPath != null
                  ? Image.file(
                      File(data.avatarPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(height: 24),
          // 账本名称
          Text(
            data.ledgerName,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          // 开始记账时间
          if (data.firstRecordDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                l10n.userProfilePosterStartDate(
                  '${data.firstRecordDate!.year}/${data.firstRecordDate!.month}/${data.firstRecordDate!.day}',
                ),
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建默认头像
  Widget _buildDefaultAvatar() {
    return Container(
      color: primaryColor.withValues(alpha: 0.3),
      child: Icon(
        Icons.person,
        size: 70,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  /// 构建核心统计卡片
  Widget _buildCoreStatsCard() {
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
      child: Row(
        children: [
          // 记账天数
          Expanded(
            child: _buildStatColumn(
              icon: Icons.calendar_today_rounded,
              label: l10n.userProfilePosterRecordDays,
              value: '${data.recordDays}',
              unit: l10n.userProfilePosterDaysUnit,
            ),
          ),
          Container(width: 1, height: 80, color: Colors.grey[200]),
          // 记账笔数
          Expanded(
            child: _buildStatColumn(
              icon: Icons.edit_note_rounded,
              label: l10n.userProfilePosterRecordCount,
              value: '${data.recordCount}',
              unit: l10n.userProfilePosterCountUnit,
            ),
          ),
          Container(width: 1, height: 80, color: Colors.grey[200]),
          // 账本数量
          Expanded(
            child: _buildStatColumn(
              icon: Icons.menu_book_rounded,
              label: l10n.userProfilePosterLedgerCount,
              value: '${data.ledgerCount}',
              unit: l10n.userProfilePosterLedgerUnit,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计列
  Widget _buildStatColumn({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF999999),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 构建记账历程区域
  Widget _buildJourneySection() {
    // 根据记账天数选择成就图标
    IconData achievementIcon;
    if (data.recordDays >= 365) {
      achievementIcon = Icons.emoji_events_rounded;
    } else if (data.recordDays >= 30) {
      achievementIcon = Icons.star_rounded;
    } else {
      achievementIcon = Icons.favorite_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                achievementIcon,
                color: const Color(0xFFFFD700),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                _getJourneyMessage(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 日均记账
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.userProfileDailyAverage,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 18,
                ),
              ),
              Text(
                data.recordDays > 0
                    ? '${(data.recordCount / data.recordDays).toStringAsFixed(1)} ${l10n.userProfilePosterCountUnit}/${l10n.userProfilePosterDaysUnit}'
                    : '-',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 获取历程消息
  String _getJourneyMessage() {
    if (data.recordDays >= 365) {
      final years = (data.recordDays / 365).floor();
      return years >= 2
          ? l10n.userProfileJourneyYears(years)
          : l10n.userProfileJourneyOneYear;
    } else if (data.recordDays >= 180) {
      return l10n.userProfileJourneyHalfYear;
    } else if (data.recordDays >= 90) {
      return l10n.userProfileJourneyThreeMonths;
    } else if (data.recordDays >= 30) {
      return l10n.userProfileJourneyOneMonth;
    } else if (data.recordDays >= 7) {
      return l10n.userProfileJourneyOneWeek;
    } else {
      return l10n.userProfileJourneyStart;
    }
  }

  /// 构建底部slogan
  Widget _buildFooter() {
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

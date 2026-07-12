/// 应用推广海报Widget
library;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/app_localizations.dart';

/// 应用推广海报
class AppPromoPoster extends StatelessWidget {
  final AppLocalizations l10n;
  final Color primaryColor;

  const AppPromoPoster({
    super.key,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 标题区域
                  _buildHeader(),

                  const SizedBox(height: 40),

                  // 特点卡片
                  _buildFeaturesCard(),

                  const Spacer(),

                  // 二维码区域
                  _buildQRCodeSection(),

                  const SizedBox(height: 30),

                  // 底部slogan
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
        bottom: 200,
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
        top: 500,
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
    return Column(
      children: [
        // Logo
        Container(
          width: 120,
          height: 120,
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
          ),
          padding: const EdgeInsets.all(20),
          child: ClipOval(
            child: Image.asset(
              'assets/logo2.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 25),
        // App名称
        Text(
          l10n.sharePosterAppName,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 12),
        // Slogan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            l10n.sharePosterSlogan,
            style: TextStyle(
              fontSize: 20,
              color: Colors.white.withValues(alpha: 0.95),
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建特点卡片
  Widget _buildFeaturesCard() {
    final features = [
      _FeatureItem(Icons.lock_outline_rounded, l10n.sharePosterFeature1),
      _FeatureItem(Icons.code_rounded, l10n.sharePosterFeature2),
      _FeatureItem(Icons.auto_awesome_rounded, l10n.sharePosterFeature3),
      _FeatureItem(Icons.camera_alt_outlined, l10n.sharePosterFeature4),
      _FeatureItem(
          Icons.dashboard_customize_outlined, l10n.sharePosterFeature5),
      _FeatureItem(Icons.cloud_sync_outlined, l10n.sharePosterFeature6),
    ];

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
          for (int i = 0; i < features.length; i++) ...[
            _buildFeatureRow(features[i]),
            if (i < features.length - 1) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 16),
            ],
          ],
        ],
      ),
    );
  }

  /// 构建特点行
  Widget _buildFeatureRow(_FeatureItem feature) {
    return Row(
      children: [
        // 图标容器
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            feature.icon,
            color: primaryColor,
            size: 26,
          ),
        ),
        const SizedBox(width: 18),
        // 文本
        Expanded(
          child: Text(
            feature.text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建二维码区域
  Widget _buildQRCodeSection() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 二维码
          Container(
            padding: const EdgeInsets.all(12),
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
              data:
                  'https://github.com/TNT-Likely/BeeCount?utm_source=share_poster&utm_medium=qr_code&utm_campaign=app_share',
              version: QrVersions.auto,
              size: 120,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 25),
          // 文字说明
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.sharePosterScanText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'github.com/TNT-Likely/BeeCount',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 12),
                // 开源标签
                Row(
                  children: [
                    _buildTag(l10n.appPromoTagOpenSource),
                    const SizedBox(width: 10),
                    _buildTag(l10n.appPromoTagFree),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签
  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 构建底部slogan
  Widget _buildFooter() {
    return Text(
      l10n.appPromoFooterText,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 14,
        letterSpacing: 1,
      ),
    );
  }
}

/// 特点项数据类
class _FeatureItem {
  final IconData icon;
  final String text;

  const _FeatureItem(this.icon, this.text);
}

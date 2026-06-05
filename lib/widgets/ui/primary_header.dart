import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as Math;
import '../../providers.dart';
import '../../providers/theme_providers.dart';
import '../../styles/tokens.dart';
import '../../styles/header_skins.dart';

class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  final Widget? titleTrailing;
  final Widget? subtitleTrailing;
  final Widget? center;
  final IconData? leadingIcon;
  final bool compact;
  final Brightness? statusBarIconBrightness;
  final BoxDecoration? decoration;
  final bool leadingPlain;
  // 隐藏内置标题/副标题行，仅渲染自定义 content（用于首页）
  final bool showTitleSection;

  const PrimaryHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions,
    this.bottom,
    this.content,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 8),
    this.titleTrailing,
    this.subtitleTrailing,
    this.center,
    this.leadingIcon,
    this.compact = false,
    this.statusBarIconBrightness,
    this.decoration,
    this.leadingPlain = false,
    this.showTitleSection = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final titleStyle = BeeTextTokens.title(context);
    final subStyle = BeeTextTokens.label(context);
    final effectivePadding =
        compact ? const EdgeInsets.fromLTRB(8, 6, 8, 6) : padding;

    // ⭐ 使用 Token 系统
    final isDark = BeeTokens.isDark(context);

    // ⭐ 获取暗黑模式图案样式：none/icons/particles/honeycomb
    final patternStyle = ref.watch(darkModePatternStyleProvider);

    // ⭐ 头部皮肤(主题色之上的装饰层);'none' → null,回退到暗黑模式图案
    final skin = headerSkinById(ref.watch(headerSkinProvider));

    // ⭐ Header 背景颜色：亮色模式用主题色，暗黑模式用纯黑
    final headerBg = isDark ? Colors.black : primary;

    // ⭐ 文字和图标颜色（使用 Token）
    final textColor = BeeTokens.textPrimary(context);
    final iconColor = BeeTokens.iconPrimary(context);

    // ⭐ 状态栏图标颜色：亮色模式用深色图标，暗黑模式用浅色图标
    final statusBarBrightness = statusBarIconBrightness ??
        (isDark ? Brightness.light : Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: headerBg,
        statusBarIconBrightness: statusBarBrightness,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: decoration ?? BoxDecoration(color: headerBg), // ⭐ 根据设置决定背景色
          child: Stack(
            children: [
              // ⭐ 头部皮肤层(主题色之上的装饰);未选皮肤时回退到暗黑模式装饰图案
              if (skin != null)
                Positioned.fill(child: skin.builder(primary, isDark))
              else if (isDark && patternStyle != 'none')
                Positioned.fill(
                  child: patternStyle == 'icons'
                      ? _IconTilingPattern(primary)
                      : CustomPaint(
                          painter: switch (patternStyle) {
                            'honeycomb' => _HoneycombPatternPainter(primary),
                            'particles' => _ParticlePatternPainter(primary),
                            _ => _ParticlePatternPainter(primary),
                          },
                        ),
                ),
              // 主内容
              SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (showTitleSection)
                  Padding(
                    padding: effectivePadding,
                    child: Row(
                      children: [
                        if (showBack) ...[
                          IconButton(
                            icon: Icon(Icons.arrow_back, color: iconColor), // ⭐ 自适应颜色
                            onPressed: () => Navigator.of(context).maybePop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (leadingIcon != null) ...[
                          leadingPlain
                              ? Icon(leadingIcon, color: iconColor)
                              : Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(leadingIcon, color: iconColor),
                                ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      style: titleStyle.copyWith(color: textColor), // ⭐ 自适应颜色
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (titleTrailing != null) ...[
                                    const SizedBox(width: 6),
                                    titleTrailing!,
                                  ],
                                ],
                              ),
                              if (subtitle != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        subtitle!,
                                        style: subStyle.copyWith(
                                          color: BeeTokens.textSecondary(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (subtitleTrailing != null) ...[
                                      const SizedBox(width: 6),
                                      subtitleTrailing!,
                                    ]
                                  ],
                                ),
                            ],
                          ),
                        ),
                        if (center != null) ...[
                          const SizedBox(width: 6),
                          DefaultTextStyle(
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: iconColor, // ⭐ 自适应颜色
                            ) ?? TextStyle(fontSize: 12, color: iconColor),
                            child: center!,
                          ),
                        ],
                        if (actions != null) ...actions!,
                      ],
                    ),
                  ),
                if (content != null)
                  Padding(
                    padding: effectivePadding,
                    child: DefaultTextStyle(
                      style: DefaultTextStyle.of(context).style.copyWith(
                        color: textColor, // ⭐ 自适应颜色
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: iconColor), // ⭐ 自适应颜色
                        child: content!,
                      ),
                    ),
                  ),
                    if (bottom != null) bottom!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图标平铺装饰组件
class _IconTilingPattern extends StatelessWidget {
  final Color color;

  const _IconTilingPattern(this.color);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Opacity(
        opacity: 0.2,
        child: Stack(
          children: [
            // === 上半部分图标 ===
            // 蜜蜂图标
            Positioned(
              top: -20,
              right: 20,
              child: Icon(
                Icons.hive_outlined,
                size: 120,
                color: color,
              ),
            ),
            // 账本图标
            Positioned(
              top: 40,
              left: -30,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 80,
                  color: color,
                ),
              ),
            ),
            // 硬币图标
            Positioned(
              top: -10,
              right: 150,
              child: Icon(
                Icons.monetization_on_outlined,
                size: 60,
                color: color,
              ),
            ),
            // 图表图标
            Positioned(
              top: 30,
              right: -20,
              child: Transform.rotate(
                angle: 0.15,
                child: Icon(
                  Icons.pie_chart_outline,
                  size: 70,
                  color: color,
                ),
              ),
            ),
            // 钱包图标
            Positioned(
              top: 10,
              left: 100,
              child: Icon(
                Icons.account_balance_wallet_outlined,
                size: 50,
                color: color,
              ),
            ),
            // === 下半部分图标 ===
            // 储蓄罐图标
            Positioned(
              bottom: 20,
              left: 20,
              child: Transform.rotate(
                angle: 0.1,
                child: Icon(
                  Icons.savings_outlined,
                  size: 90,
                  color: color,
                ),
              ),
            ),
            // 趋势图标
            Positioned(
              bottom: -10,
              right: 80,
              child: Icon(
                Icons.trending_up,
                size: 70,
                color: color,
              ),
            ),
            // 收据图标
            Positioned(
              bottom: 30,
              left: 150,
              child: Transform.rotate(
                angle: -0.15,
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 60,
                  color: color,
                ),
              ),
            ),
            // 计算器图标
            Positioned(
              bottom: -20,
              right: -10,
              child: Icon(
                Icons.calculate_outlined,
                size: 80,
                color: color,
              ),
            ),
            // 标签图标
            Positioned(
              bottom: 40,
              right: 200,
              child: Transform.rotate(
                angle: 0.2,
                child: Icon(
                  Icons.label_outlined,
                  size: 55,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 粒子/星星点点绘制器
class _ParticlePatternPainter extends CustomPainter {
  final Color color;

  _ParticlePatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Math.Random(42); // 固定种子，保持一致性

    // 绘制30-40个随机分布的粒子
    for (int i = 0; i < 35; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final particleSize = 2.0 + random.nextDouble() * 4; // 2-6 px
      final opacity = 0.1 + random.nextDouble() * 0.15; // 10%-25% 透明度

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // 绘制圆形粒子
      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // 20%的粒子绘制光晕效果
      if (i % 5 == 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint);
      }
    }

    // 绘制几个五角星形状的粒子
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 8.0 + random.nextDouble() * 8; // ⭐ 增大尺寸：8-16px
      final opacity = 0.15 + random.nextDouble() * 0.1;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      // ⭐ 绘制真正的五角星
      final path = _createStarPath(x, y, starSize, starSize * 0.4);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  /// 创建五角星路径
  Path _createStarPath(double centerX, double centerY, double outerRadius, double innerRadius) {
    final path = Path();
    const points = 5;
    const angle = Math.pi / points;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final currentAngle = angle * i - Math.pi / 2; // 从顶部开始
      final x = centerX + radius * Math.cos(currentAngle);
      final y = centerY + radius * Math.sin(currentAngle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }
}

/// 对角线条纹绘制器（方案7）
class _DiagonalStripesPatternPainter extends CustomPainter {
  final Color color;

  _DiagonalStripesPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paint3 = Paint()
      ..color = color.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const spacing = 30.0; // 条纹间距

    // 绘制从左上到右下的对角线
    // 第一组：较粗较明显
    for (double i = -size.height; i < size.width + size.height; i += spacing * 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint1,
      );
    }

    // 第二组：中等粗细
    for (double i = -size.height + spacing; i < size.width + size.height; i += spacing * 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint2,
      );
    }

    // 第三组：较细较淡
    for (double i = -size.height + spacing * 2; i < size.width + size.height; i += spacing * 3) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 蜂巢六边形图案绘制器（方案8）
class _HoneycombPatternPainter extends CustomPainter {
  final Color color;

  _HoneycombPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const hexSize = 30.0; // 六边形尺寸
    final hexHeight = hexSize * Math.sqrt(3);
    final hexWidth = hexSize * 2;

    // 计算需要绘制的行列数
    final rows = (size.height / hexHeight * 1.5).ceil() + 2;
    final cols = (size.width / (hexWidth * 0.75)).ceil() + 2;

    // 绘制蜂巢网格
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final x = col * hexWidth * 0.75;
        final y = row * hexHeight + (col.isOdd ? hexHeight / 2 : 0);

        // 只绘制部分六边形（随机效果）
        final random = Math.Random((row * 1000 + col).hashCode);
        if (random.nextDouble() > 0.3) { // 70% 显示
          _drawHexagon(canvas, Offset(x, y), hexSize, paint);
        }
      }
    }
  }

  /// 绘制单个六边形
  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (Math.pi / 3) * i;
      final x = center.dx + size * Math.cos(angle);
      final y = center.dy + size * Math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

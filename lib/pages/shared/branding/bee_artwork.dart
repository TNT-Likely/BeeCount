import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BeeIcon extends StatelessWidget {
  final Color color; // 类似 Web 中的 color 属性
  final double size;

  const BeeIcon({super.key, required this.color, this.size = 256});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final svg = SvgPicture.asset(
      'assets/bee.svg',
      width: size,
      height: size,
      theme: SvgTheme(
        currentColor: color, // 核心：模拟 CSS 的 currentColor
      ),
    );

    if (!isDark) return svg;

    // 暗黑模式：在蜜蜂图标后面加浅色圆形遮罩，让黑色边框可见
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          svg,
        ],
      ),
    );
  }
}

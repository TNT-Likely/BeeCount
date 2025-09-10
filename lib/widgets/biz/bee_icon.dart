import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BeeIcon extends StatelessWidget {
  final Color color; // 类似 Web 中的 color 属性
  final double size;

  const BeeIcon({super.key, required this.color, this.size = 256});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/bee.svg',
      width: size,
      height: size,
      theme: SvgTheme(
        currentColor: color, // 核心：模拟 CSS 的 currentColor
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin; // 新增 margin 参数

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(BeeDimens.p12),
    this.margin = const EdgeInsets.symmetric(horizontal: BeeDimens.p12), // 默认值
  });

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    final borderWidth = BeeTokens.cardOuterBorderWidth(context);
    final borderColor = BeeTokens.cardOuterBorderColor(context);

    return Container(
      margin: margin, // 使用传入的 margin
      decoration: BoxDecoration(
        color: BeeTokens.surface(context), // ⭐ 使用 Token
        borderRadius: BorderRadius.circular(BeeDimens.radius12),
        border: borderWidth > 0
            ? Border.all(
                color: borderColor, // ⭐ 使用卡片边框 Token
                width: borderWidth,
              )
            : null,
        boxShadow: isDark ? null : BeeShadows.card, // ⭐ 暗黑模式：无阴影，亮色模式：有阴影
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

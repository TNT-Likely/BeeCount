import 'package:flutter/material.dart';
import '../../styles/design.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin; // 新增 margin 参数

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.p12),
    this.margin = const EdgeInsets.symmetric(horizontal: AppDimens.p12), // 默认值
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin, // 使用传入的 margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimens.radius12),
        boxShadow: AppShadows.card,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

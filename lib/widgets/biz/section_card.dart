import 'package:flutter/material.dart';
import '../../styles/tokens.dart';
import 'package:beecount_ui/beecount_ui.dart';

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
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: BeeSurface(padding: padding, child: child),
      );
}

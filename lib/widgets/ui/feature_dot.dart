import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/feature_highlight_providers.dart';

/// 新功能红点。挂在通往新功能的入口上,用户走到功能本身后自动熄灭。
///
/// 用法:包住任何入口 widget(列表项的图标、tab 图标…),给一个锚点 id。
/// 该锚点下没有未读功能时**完全不渲染**,不占位、不加层。
///
/// ```dart
/// FeatureDot(anchor: 'header_skin', child: Icon(Icons.wallpaper_outlined))
/// ```
class FeatureDot extends ConsumerWidget {
  const FeatureDot({
    super.key,
    required this.anchor,
    required this.child,
    this.offset = const Offset(2, -2),
  });

  final String anchor;
  final Widget child;

  /// 红点相对右上角的微调。图标形状各异,有的需要往里收一点。
  final Offset offset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = ref.watch(anchorHasUnreadProvider(anchor));
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: offset.dx,
          top: offset.dy,
          // 红点自己不该吃掉入口的点击
          child: const IgnorePointer(child: _Dot()),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30),
        shape: BoxShape.circle,
        // 描一圈底色:红点常常压在图标或彩色背景上,没有这圈会糊在一起
        border: Border.all(color: Theme.of(context).cardColor, width: 1.5),
      ),
    );
  }
}

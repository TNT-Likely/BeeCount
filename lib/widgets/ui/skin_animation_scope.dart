import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_providers.dart';

/// 把「皮肤动效开关」翻译成子树的 `MediaQuery.disableAnimations`。
///
/// 动态皮肤本来就实现了「系统减弱动态效果 → 停在静态帧」这条分支
/// (见 `_AnimSkinShell` 和各皮肤的 `didChangeDependencies`),用户手动关动效
/// 想要的是**完全一样的效果**。所以这里不给皮肤加新参数,直接复用那条既有
/// 分支 —— 皮肤代码一行都不用改,以后新增的动态皮肤也自动支持。
///
/// 只包皮肤子树:里面除了皮肤自己的 CustomPainter 没有别的动画,
/// 不会误伤页面转场之类。
///
/// 注意是 `||` 而不是覆盖:系统开了「减弱动态效果」时,不管 App 里这个开关
/// 是什么都必须停 —— 那是无障碍设置,优先级高于皮肤偏好。
class SkinAnimationScope extends ConsumerWidget {
  const SkinAnimationScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(skinAnimationEnabledProvider);
    if (enabled) return child; // 开着就什么都不做,少一层 MediaQuery
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(disableAnimations: true),
      child: child,
    );
  }
}

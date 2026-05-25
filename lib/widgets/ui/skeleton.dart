import 'dart:async';

import 'package:flutter/material.dart';

import '../../styles/tokens.dart';

/// 延迟显示骨架屏:< [DelayedSkeleton.defaultDelay] 期间显示等高占位,
/// >= 才出真正的骨架。快速查询(<300ms)用户根本看不到骨架,
/// 避免"骨架闪一下就消失"的违和感;慢查询时骨架接管,告诉用户在加载。
///
/// 配合 [PulseSkeleton] / [SkeletonBar] 等原语使用:
/// ```dart
/// asyncValue.when(
///   skipLoadingOnReload: true,
///   data: (d) => ...,
///   loading: () => DelayedSkeleton(
///     placeholder: SizedBox(height: 200),
///     child: PulseSkeleton(child: SkeletonListTile()),
///   ),
///   error: ...,
/// )
/// ```
class DelayedSkeleton extends StatefulWidget {
  static const Duration defaultDelay = Duration(milliseconds: 300);

  final Widget child;

  /// 延迟期间显示的占位。建议传一个等高的 [SizedBox] 避免布局抖动。
  final Widget placeholder;

  final Duration delay;

  const DelayedSkeleton({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
    this.delay = defaultDelay,
  });

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton> {
  bool _show = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _show ? widget.child : widget.placeholder;
  }
}

/// 让子组件以"呼吸"动画显示(opacity 在 0.55 ↔ 1.0 之间循环),
/// 比静态灰块更有生命力,告诉用户"正在加载"。
class PulseSkeleton extends StatefulWidget {
  final Widget child;

  /// 单次循环时长,默认 900ms,大多数 loading 场景节奏舒适。
  final Duration period;

  const PulseSkeleton({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 900),
  });

  @override
  State<PulseSkeleton> createState() => _PulseSkeletonState();
}

class _PulseSkeletonState extends State<PulseSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.period)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final v = 0.55 + 0.45 * (1 - _controller.value);
        return Opacity(opacity: v, child: widget.child);
      },
    );
  }
}

/// 骨架矩形条原语 — 通用占位灰块,用 [BeeTokens.surfaceSecondary] 自适应亮/暗。
class SkeletonBar extends StatelessWidget {
  final double height;
  final double? width;

  /// 按父容器宽度的比例填充,与 [width] 二选一(都不传则横向 expand)。
  final double? widthFactor;
  final BorderRadius? borderRadius;

  const SkeletonBar({
    super.key,
    required this.height,
    this.width,
    this.widthFactor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: BeeTokens.surfaceSecondary(context),
        borderRadius: borderRadius ?? BorderRadius.circular(6),
      ),
    );
    if (widthFactor != null) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor,
        child: box,
      );
    }
    return box;
  }
}

/// 骨架圆形原语 — 通用,适合头像 / 图标占位。
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: BeeTokens.surfaceSecondary(context),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 模拟 ListTile 的骨架行:左圆 + 中间两行文字 + 右侧金额条。
/// 常用于交易列表、账户列表、分类列表等 loading 占位。
class SkeletonListTile extends StatelessWidget {
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const SkeletonListTile({
    super.key,
    this.iconSize = 36,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          SkeletonCircle(size: iconSize),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBar(height: 14, width: 110),
                SizedBox(height: 6),
                SkeletonBar(height: 11, width: 70),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBar(height: 16, width: 60),
        ],
      ),
    );
  }
}

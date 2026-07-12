import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 消息长按弹出菜单项
class PopoverMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const PopoverMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
}

/// 微信风格的长按弹出菜单
class MessagePopoverMenu {
  /// 显示弹出菜单
  ///
  /// [context] - BuildContext
  /// [globalPosition] - 长按位置（全局坐标）
  /// [items] - 菜单项列表
  /// [primaryColor] - 主题色
  static Future<void> show({
    required BuildContext context,
    required Offset globalPosition,
    required List<PopoverMenuItem> items,
    Color? primaryColor,
  }) async {
    // 触感反馈
    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    // 获取当前路由，用于监听页面退出
    final route = ModalRoute.of(context);

    // 计算菜单位置
    final screenSize = MediaQuery.of(context).size;
    final menuWidth = items.length * 70.0;
    final menuHeight = 56.0;

    // 默认显示在点击位置上方
    double left = globalPosition.dx - menuWidth / 2;
    double top = globalPosition.dy - menuHeight - 12;

    // 边界检查
    if (left < 12) left = 12;
    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }
    if (top < 60) {
      // 如果上方空间不够，显示在下方
      top = globalPosition.dy + 12;
    }

    OverlayEntry? overlayEntry;
    bool isRemoved = false;

    void removeOverlay() {
      if (!isRemoved) {
        isRemoved = true;
        overlayEntry?.remove();
      }
    }

    overlayEntry = OverlayEntry(
      builder: (context) => _PopoverOverlay(
        left: left,
        top: top,
        items: items,
        primaryColor: primaryColor ?? Theme.of(context).colorScheme.primary,
        onDismiss: removeOverlay,
        route: route,
      ),
    );

    overlay.insert(overlayEntry);
  }
}

class _PopoverOverlay extends StatefulWidget {
  final double left;
  final double top;
  final List<PopoverMenuItem> items;
  final Color primaryColor;
  final VoidCallback onDismiss;
  final ModalRoute? route;

  const _PopoverOverlay({
    required this.left,
    required this.top,
    required this.items,
    required this.primaryColor,
    required this.onDismiss,
    this.route,
  });

  @override
  State<_PopoverOverlay> createState() => _PopoverOverlayState();
}

class _PopoverOverlayState extends State<_PopoverOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    // 监听路由状态变化
    widget.route?.animation?.addStatusListener(_routeAnimationStatusListener);
  }

  void _routeAnimationStatusListener(AnimationStatus status) {
    // 当路由开始退出动画时（手势返回或点击返回），关闭 popover
    if (status == AnimationStatus.reverse) {
      _dismissImmediately();
    }
  }

  @override
  void dispose() {
    widget.route?.animation
        ?.removeStatusListener(_routeAnimationStatusListener);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用进入后台时关闭 popover
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _dismissImmediately();
    }
  }

  /// 立即关闭（不播放动画）
  void _dismissImmediately() {
    if (_isDismissed) return;
    _isDismissed = true;
    widget.onDismiss();
  }

  Future<void> _dismiss() async {
    if (_isDismissed) return;
    _isDismissed = true;
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 获取顶部安全区域高度 + Header 高度（约 56）
    final topPadding = MediaQuery.of(context).padding.top + 56;

    return Stack(
      children: [
        // 背景遮罩（点击关闭），但不覆盖顶部 Header 区域
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 弹出菜单
        Positioned(
          left: widget.left,
          top: widget.top,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isLast = index == widget.items.length - 1;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMenuItem(context, item, isDark),
                          if (!isLast)
                            Container(
                              width: 0.5,
                              height: 32,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.1),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    PopoverMenuItem item,
    bool isDark,
  ) {
    final color = item.color ?? (isDark ? Colors.white : Colors.black87);

    return InkWell(
      onTap: () async {
        await _dismiss();
        item.onTap();
      },
      child: Container(
        width: 70,
        height: 56,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

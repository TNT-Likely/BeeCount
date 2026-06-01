import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

/// 轻量 Toast（基础 UI 工具）：覆盖层展示，不占据布局，不顶起 FAB
void showToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 2)}) {
  showToastOnOverlay(
    Overlay.of(context, rootOverlay: true),
    message,
    duration: duration,
    isDark: BeeTokens.isDark(context),
  );
}

/// 用指定的 OverlayState 直接弹 Toast —— 给没有就近 BuildContext 的全局场景
/// (如 deep-link 处理:`globalNavigatorKey.currentState?.overlay`)。普通页面
/// 请用 [showToast]。注意不能用 navigator 的 context 走 [showToast],因为它在
/// Overlay 之上,`Overlay.of` 找不到祖先 Overlay 会抛 "No Overlay widget found"。
void showToastOnOverlay(OverlayState overlay, String message,
    {Duration duration = const Duration(seconds: 2), bool? isDark}) {
  final dark = isDark ?? BeeTokens.isDark(overlay.context);

  final entry = OverlayEntry(
    builder: (ctx) => Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  // 暗黑模式下添加白色阴影，提升可见度
                  boxShadow: dark ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ] : null,
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    entry.remove();
  });
}

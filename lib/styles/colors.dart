import 'package:flutter/material.dart';

/// 颜色令牌：中性色、语义色、分割线与文本对比色工具
class BeeColors {
  // 中性文本
  static const Color primaryText = Color(0xFF111827); // 黑灰 900
  static const Color secondaryText = Color(0xFF6B7280); // 灰 500
  static const Color hintText = Color(0xFF9CA3AF); // 灰 400
  // 兼容要求：提供等同于 Colors.black54 的令牌
  static const Color black54 = Color(0x8A000000); // 54% 黑

  // 分隔/卡片背景（通过透明度控制层级）
  static Color divider = Colors.black.withValues(alpha: 0.06);
  static Color cardBg = Colors.white;

  // 语义色
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // 根据背景自动选择对比文本（简化：亮背景用深字，暗背景用白字）
  static Color onColor(Color bg) {
    final l = bg.computeLuminance();
    return l > 0.5 ? const Color(0xFF111827) : Colors.white;
  }
}

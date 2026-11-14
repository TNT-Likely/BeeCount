import 'package:flutter/material.dart';

/// 扇形展开的 FAB 菜单项
class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final String? disabledTooltip;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.disabledTooltip,
  });
}

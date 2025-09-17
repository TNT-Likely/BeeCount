import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/font_scale_provider.dart';
import '../services/ui_scale_service.dart';

/// 为double类型添加UI缩放扩展
extension UIScaleDouble on double {
  /// 根据当前上下文和用户设置缩放数值
  double scaled(BuildContext context, WidgetRef ref) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scale(context, this, userScale);
  }
}

/// 为int类型添加UI缩放扩展
extension UIScaleInt on int {
  /// 根据当前上下文和用户设置缩放数值
  double scaled(BuildContext context, WidgetRef ref) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scale(context, toDouble(), userScale);
  }
}

/// 为EdgeInsets添加UI缩放扩展
extension UIScaleEdgeInsets on EdgeInsets {
  /// 根据当前上下文和用户设置缩放边距
  EdgeInsets scaled(BuildContext context, WidgetRef ref) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scaleEdgeInsets(context, this, userScale);
  }
}

/// 为BorderRadius添加UI缩放扩展
extension UIScaleBorderRadius on BorderRadius {
  /// 根据当前上下文和用户设置缩放圆角
  BorderRadius scaled(BuildContext context, WidgetRef ref) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scaleBorderRadius(context, this, userScale);
  }
}

/// 便捷的UI缩放混入类
mixin UIScaleMixin {
  /// 缩放数值
  double scale(BuildContext context, WidgetRef ref, double value) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scale(context, value, userScale);
  }

  /// 缩放边距
  EdgeInsets scaleEdgeInsets(BuildContext context, WidgetRef ref, EdgeInsets insets) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scaleEdgeInsets(context, insets, userScale);
  }

  /// 缩放圆角
  BorderRadius scaleBorderRadius(BuildContext context, WidgetRef ref, BorderRadius radius) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.scaleBorderRadius(context, radius, userScale);
  }

  /// 获取最终缩放因子
  double getScaleFactor(BuildContext context, WidgetRef ref) {
    final userScale = ref.watch(effectiveFontScaleProvider);
    return UIScaleService.getFinalScaleFactor(context, userScale);
  }
}
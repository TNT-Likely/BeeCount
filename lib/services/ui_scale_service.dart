import 'package:flutter/material.dart';

/// UI缩放服务 - 类似Web中的rem概念
/// 解决不同屏幕密度设备的显示差异问题
class UIScaleService {
  /// 基准屏幕密度 (设置为用户设备2312CRAD3C的实际DPI，让其设备缩放为1.0)
  static const double baseDevicePixelRatio = 3.00; // 用户设备的实际DPI

  /// 基准屏幕宽度 (设置为用户设备2312CRAD3C的实际宽度，让其设备缩放为1.0)
  static const double baseScreenWidth = 407.0; // 用户设备的实际宽度

  /// 计算效果补偿系数 (确保所有设备用户缩放1.0时效果一致)
  static double getEffectCompensation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final screenWidth = mediaQuery.size.width;

    // 基于屏幕密度的补偿
    final densityCompensation = devicePixelRatio / baseDevicePixelRatio;

    // 基于屏幕宽度的补偿
    final widthCompensation = screenWidth / baseScreenWidth;

    // 组合补偿系数，密度占80%权重，宽度占20%权重
    final deviceCompensation = (densityCompensation * 0.8) + (widthCompensation * 0.2);

    // 直接返回设备补偿，不再额外调整
    // 让用户自己选择合适的缩放档位
    return deviceCompensation;
  }

  /// 计算基于屏幕密度的自适应缩放因子 (为了显示统一，现在总是返回1.0)
  static double getDeviceScaleFactor(BuildContext context) {
    // 新策略：设备缩放总是显示1.0，设备差异通过补偿系数处理
    return 1.0;
  }


  /// 获取最终的UI缩放因子 (设备差异已内置，用户缩放直接应用)
  static double getFinalScaleFactor(BuildContext context, double userScale) {
    final deviceScale = getDeviceScaleFactor(context);
    // 用户缩放值直接应用，1.0就是基准效果
    return deviceScale * userScale;
  }

  /// 缩放尺寸值 (用于padding, margin, size等)
  static double scale(BuildContext context, double value, double userScale) {
    final deviceScale = getDeviceScaleFactor(context);
    final compensation = getEffectCompensation(context);
    // 核心逻辑改变：设备差异内置，确保所有设备1.0x效果一致
    // 应用动态计算的效果补偿系数，保持跨设备的视觉效果一致
    return value * deviceScale * userScale * compensation;
  }

  /// 缩放EdgeInsets
  static EdgeInsets scaleEdgeInsets(BuildContext context, EdgeInsets insets, double userScale) {
    final scale = getFinalScaleFactor(context, userScale) * getEffectCompensation(context);
    return EdgeInsets.only(
      left: insets.left * scale,
      top: insets.top * scale,
      right: insets.right * scale,
      bottom: insets.bottom * scale,
    );
  }

  /// 缩放BorderRadius
  static BorderRadius scaleBorderRadius(BuildContext context, BorderRadius radius, double userScale) {
    final scale = getFinalScaleFactor(context, userScale) * getEffectCompensation(context);
    return BorderRadius.only(
      topLeft: radius.topLeft * scale,
      topRight: radius.topRight * scale,
      bottomLeft: radius.bottomLeft * scale,
      bottomRight: radius.bottomRight * scale,
    );
  }

  /// 检测是否为基准设备（或非常接近基准设备）
  static bool isBaseDevice(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final devicePixelRatio = mediaQuery.devicePixelRatio;
    final screenWidth = mediaQuery.size.width;

    // 允许5%的误差
    final densityMatch = (devicePixelRatio - baseDevicePixelRatio).abs() / baseDevicePixelRatio < 0.05;
    final widthMatch = (screenWidth - baseScreenWidth).abs() / baseScreenWidth < 0.05;

    return densityMatch && widthMatch;
  }

  /// 获取推荐的用户缩放值（现在所有设备1.0x都一致，推荐值简化）
  static double getRecommendedUserScale(BuildContext context) {
    // 新逻辑：由于设备差异已内置，所有设备都推荐1.0作为基准
    return 1.0;
  }

  /// 获取调试信息
  static Map<String, double> getDebugInfo(BuildContext context, double userScale) {
    final mediaQuery = MediaQuery.of(context);
    final deviceScale = getDeviceScaleFactor(context);
    final finalScale = getFinalScaleFactor(context, userScale);
    final recommendedScale = getRecommendedUserScale(context);

    return {
      'devicePixelRatio': mediaQuery.devicePixelRatio,
      'screenWidth': mediaQuery.size.width,
      'screenHeight': mediaQuery.size.height,
      'baseDevicePixelRatio': baseDevicePixelRatio,
      'baseScreenWidth': baseScreenWidth,
      'deviceScaleFactor': deviceScale,
      'userScaleFactor': userScale,
      'finalScaleFactor': finalScale,
      'recommendedUserScale': recommendedScale,
      'isBaseDevice': isBaseDevice(context) ? 1.0 : 0.0,
    };
  }
}
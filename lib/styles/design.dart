import 'package:flutter/material.dart';
import 'colors.dart';

/// 设计基准：统一间距、圆角、阴影、分割线等
class AppDimens {
  static const double p8 = 8;
  static const double p12 = 12;
  static const double p16 = 16;
  static const double radius12 = 12;
  static const double radius16 = 16;
}

class AppShadows {
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];
}

class AppDivider {
  static Divider thin({EdgeInsetsGeometry? padding}) => Divider(
        height: 1,
        thickness: 1,
        color: BeeColors.divider,
      );

  static Divider short({double indent = 0, double endIndent = 0}) => Divider(
        height: 1,
        thickness: 1,
        indent: indent,
        endIndent: endIndent,
        color: BeeColors.divider,
      );
}

/// 图表令牌：统一折线图的视觉参数
class AppChartTokens {
  static const double lineWidth = 2.0;
  static const double dotRadius = 2.5;
  static const double cornerRadius = 12.0;
  static const double xLabelFontSize = 10.0;
  static const double yLabelFontSize = 10.0;
}

/// 文本令牌：全局统一字号与字重（以“我的”页列表为准）
class AppTextTokens {
  // 标题：用于列表主标题、条目标题
  static TextStyle title(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ) ??
      const TextStyle(
          fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500);

  // 正文：用于一般性文字
  static TextStyle body(BuildContext ctx) =>
      Theme.of(ctx).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: Colors.black87,
          ) ??
      const TextStyle(fontSize: 14, color: Colors.black87);

  // 标签/说明：用于次要说明、辅助信息
  static TextStyle label(BuildContext ctx) =>
      Theme.of(ctx).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            color: BeeColors.black54,
          ) ??
      const TextStyle(fontSize: 12, color: Colors.black54);
}

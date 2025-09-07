import 'package:flutter/material.dart';

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
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];
}

class AppDivider {
  static Divider thin({EdgeInsetsGeometry? padding}) => Divider(
        height: 1,
        thickness: 1,
        color: Colors.black12.withOpacity(0.06),
      );
}

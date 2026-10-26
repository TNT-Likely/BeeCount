import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// App compatibility entry point; presentation is owned by the basic UI package.
void showToast(BuildContext context, String message,
    {Duration duration = const Duration(seconds: 2),
    BeeTone tone = BeeTone.neutral}) {
  showBeeToast(context, message, duration: duration, tone: tone);
}

/// Services and deep links use the root navigator overlay directly.
void showToastOnOverlay(OverlayState overlay, String message,
    {Duration duration = const Duration(seconds: 2),
    bool? isDark,
    BeeTone tone = BeeTone.neutral}) {
  showBeeToastOnOverlay(overlay, message,
      duration: duration,
      tone: tone,
      brightness: isDark == null
          ? null
          : isDark
              ? Brightness.dark
              : Brightness.light);
}

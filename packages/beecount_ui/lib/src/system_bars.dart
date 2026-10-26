import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Theme-owned fallback for headerless pages. Inner annotated regions retain
/// their override, and navigation-bar configuration is intentionally untouched.
class BeeSystemBars extends StatelessWidget {
  const BeeSystemBars({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: brightness),
        child: child);
  }
}

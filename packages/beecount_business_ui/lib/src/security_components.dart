import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Centered security prompt; authentication and persistence belong to the App.
class BeeSecurityPanel extends StatelessWidget {
  const BeeSecurityPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.inputBuilder,
    this.symbol = const BeeLineIcon('Lock', size: 31),
  });
  final String title, subtitle;
  final Widget symbol;
  final Widget Function(bool compact) inputBuilder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final compact = size.maxHeight < 620;
        final accent = Theme.of(context).colorScheme.primary;
        final dark = Theme.of(context).brightness == Brightness.dark;
        final strong = Color.lerp(accent,
            dark ? Colors.white : const Color(0xff222222), dark ? .25 : .42)!;
        return SingleChildScrollView(
            child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: size.maxHeight),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 398),
                        child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 27, vertical: compact ? 16 : 24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      width: compact ? 50 : 67,
                                      height: compact ? 50 : 67,
                                      decoration: BoxDecoration(
                                          color: accent.withValues(alpha: .12),
                                          borderRadius: BorderRadius.circular(
                                              compact ? 18 : 23)),
                                      child: IconTheme(
                                          data: IconThemeData(color: strong),
                                          child: symbol)),
                                  SizedBox(height: compact ? 14 : 22),
                                  Semantics(
                                      header: true,
                                      child: Text(title,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: compact ? 20 : 25,
                                              fontWeight: FontWeight.w600))),
                                  const SizedBox(height: 10),
                                  Text(subtitle,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.8,
                                          color: Theme.of(context).hintColor)),
                                  SizedBox(height: compact ? 12 : 25),
                                  inputBuilder(compact),
                                ]))))));
      });
}

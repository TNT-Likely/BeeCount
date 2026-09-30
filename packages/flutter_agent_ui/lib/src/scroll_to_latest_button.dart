import 'package:flutter/material.dart';

/// Overlay this above the composer only while the user is reading history.
class AgentScrollToLatestButton extends StatelessWidget {
  const AgentScrollToLatestButton(
      {super.key, required this.onPressed, required this.label});
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: CircleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor)),
        elevation: 3,
        child: IconButton(
            onPressed: onPressed,
            tooltip: label,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(Icons.arrow_downward_rounded,
                size: 20, color: Theme.of(context).colorScheme.onSurface)),
      );
}

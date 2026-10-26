import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import 'transaction_presentation.dart';

/// A tag's visual pill is independent of its transparent tap target.
class BeeTag extends StatelessWidget {
  const BeeTag({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
    this.compact = false,
    this.choice = false,
    this.enabled = true,
  });

  final BeeTagData tag;
  final bool selected;
  final VoidCallback? onTap;

  /// Details remain 21px tall even when they link to the tag page.
  final bool compact;

  /// Explicit choice style keeps disabled picker options at the same size.
  final bool choice, enabled;

  @override
  Widget build(BuildContext context) {
    final inline = compact || (!choice && onTap == null);
    final interactive = onTap != null || choice;
    final color = Theme.of(context).brightness == Brightness.dark
        ? Color.lerp(tag.color, Colors.white, .3)!
        : tag.color;
    Widget pill = Opacity(
      opacity: enabled ? 1 : .45,
      child: Container(
        key: const ValueKey('bee-tag-pill'),
        constraints: BoxConstraints(minHeight: inline ? 21 : 26),
        padding: EdgeInsets.symmetric(
            horizontal: inline ? 8 : 10, vertical: inline ? 2 : 3),
        decoration: BoxDecoration(
          color: tag.color.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? .2 : .12),
          border: Border.all(color: selected ? color : Colors.transparent),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!enabled || (!inline && selected)) ...[
            BeeLineIcon(enabled ? 'Check' : 'Lock', size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(tag.label,
                maxLines: inline ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: inline ? 10 : 11,
                    height: inline ? 1.5 : 1.4,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ),
        ]),
      ),
    );
    if (interactive) {
      pill = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(widthFactor: 1, heightFactor: 1, child: pill),
      );
    }
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: interactive,
      child: Tooltip(
        message: tag.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            child: pill,
          ),
        ),
      ),
    );
  }
}

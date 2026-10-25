import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Consistent 44+ touch area, tooltip, selection and in-progress/disabled states.
class BeeIconButton extends StatelessWidget {
  const BeeIconButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.selected = false,
      this.loading = false,
      this.danger = false});
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected, loading, danger;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        danger ? theme.colorScheme.error : theme.colorScheme.onSurface;
    return Semantics(
        container: true,
        label: label,
        button: true,
        enabled: onPressed != null && !loading,
        onTap: loading ? null : onPressed,
        selected: selected,
        liveRegion: loading,
        child: ExcludeSemantics(
            child: IconButton(
                tooltip: label,
                onPressed: loading ? null : onPressed,
                style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: color,
                    backgroundColor: selected
                        ? theme.colorScheme.primary.withValues(alpha: .14)
                        : Colors.transparent,
                    disabledForegroundColor: color.withValues(alpha: .35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13))),
                icon: loading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color))
                    : icon)));
  }
}

/// Counts/feature dots are presentational; unread data stays in the host.
class BeeBadge extends StatelessWidget {
  const BeeBadge(
      {super.key,
      required this.child,
      required this.label,
      this.count,
      this.visible = true});
  final Widget child;
  final String label;
  final int? count;
  final bool visible;
  @override
  Widget build(BuildContext context) {
    if (!visible || (count != null && count! <= 0)) return child;
    return Semantics(
        label: label,
        child: Stack(clipBehavior: Clip.none, children: [
          child,
          Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                  child: ExcludeSemantics(
                      child: Container(
                          padding: count == null
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                          constraints: BoxConstraints(
                              minWidth: count == null ? 8 : 18,
                              minHeight: count == null ? 8 : 18),
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: BeeCardTheme.of(context).surface,
                                  width: 1.5)),
                          child: count == null
                              ? null
                              : Text(count! > 99 ? '99+' : '$count',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 10,
                                      height: 1.3,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onError))))))
        ]));
  }
}

/// Neutral selection tokens; category/tag semantic color belongs in business UI.
class BeeChoiceChip extends StatelessWidget {
  const BeeChoiceChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected,
      this.leading,
      this.trailing,
      this.compact = false});
  final String label;
  final bool selected, compact;
  final ValueChanged<bool>? onSelected;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 10 : 13);
    final content = Padding(
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12, vertical: compact ? 7 : 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading!, SizedBox(width: compact ? 5 : 6)],
          if (selected) ...[
            BeeLineIcon('Check', size: compact ? 12 : 16),
            const SizedBox(width: 6)
          ],
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: compact ? 11 : 13,
                      height: compact ? 1.5 : null,
                      color: compact && !selected
                          ? Theme.of(context).hintColor
                          : null))),
          if (trailing != null) ...[const SizedBox(width: 5), trailing!],
        ]));
    final shape = RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent));
    final color = selected
        ? Theme.of(context).colorScheme.primary.withValues(alpha: .14)
        : BeeCardTheme.of(context).soft;
    void tap() => onSelected?.call(!selected);
    final visual = Material(
        key: const ValueKey('bee-choice-chip-visual'),
        color: color,
        shape: shape,
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 34 : 44),
            child: content));
    return Semantics(
        checked: selected,
        enabled: onSelected != null,
        button: true,
        child: Opacity(
            opacity: onSelected == null ? .45 : 1,
            child: compact
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSelected == null ? null : tap,
                    child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: Center(
                            widthFactor: 1, heightFactor: 1, child: visual)))
                : Material(
                    color: color,
                    shape: shape,
                    child: InkWell(
                        onTap: onSelected == null ? null : tap,
                        borderRadius: radius,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: content)))));
  }
}

class BeeDivider extends StatelessWidget {
  const BeeDivider({super.key, this.label, this.inset = 0, this.height = 24});
  final String? label;
  final double inset, height;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: label == null
          ? Divider(height: height, thickness: .6)
          : Row(children: [
              const Expanded(child: Divider(thickness: .6)),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(label!,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))),
              const Expanded(child: Divider(thickness: .6))
            ]));
}

/// Put in Scaffold.bottomNavigationBar for a fixed, safe-area-aware action row.
class BeeActionBar extends StatelessWidget {
  const BeeActionBar(
      {super.key,
      required this.primaryLabel,
      required this.onPrimary,
      this.secondaryLabel,
      this.onSecondary,
      this.loading = false,
      this.safeArea = true});
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading, safeArea;
  @override
  Widget build(BuildContext context) {
    final bar = Padding(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (secondaryLabel != null) ...[
            Expanded(
                child: BeeButton(
                    label: secondaryLabel!,
                    onPressed: loading ? null : onSecondary,
                    kind: BeeButtonKind.secondary)),
            const SizedBox(width: 10)
          ],
          Expanded(
              child: BeeButton(
                  label: primaryLabel, onPressed: onPrimary, loading: loading))
        ]));
    return Material(
        color: BeeCardTheme.of(context).surface,
        child: safeArea ? SafeArea(top: false, child: bar) : bar);
  }
}

/// Compact, non-interactive metadata. Selection controls use BeeChoiceChip.
class BeeLabel extends StatelessWidget {
  const BeeLabel(
      {super.key,
      required this.label,
      this.leading,
      this.accent = false,
      this.muted = false});
  final String label;
  final Widget? leading;
  final bool accent, muted;
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: muted ? .4 : 1,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: accent
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .13)
                  : BeeCardTheme.of(context).soft,
              borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 11, height: 1.4))),
          ])));
}

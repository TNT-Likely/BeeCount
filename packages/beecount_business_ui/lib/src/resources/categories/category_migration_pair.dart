import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Category identities and navigation only. The App owns selection and migration.
class BeeCategoryMigrationPair extends StatelessWidget {
  const BeeCategoryMigrationPair(
      {super.key,
      required this.fromLabel,
      required this.toLabel,
      required this.fromHint,
      required this.toHint,
      this.fromName,
      this.toName,
      this.fromIcon,
      this.toIcon,
      this.onFrom,
      this.onTo});
  final String fromLabel, toLabel, fromHint, toHint;
  final String? fromName, toName;
  final Widget? fromIcon, toIcon;
  final VoidCallback? onFrom, onTo;
  @override
  Widget build(BuildContext context) => Column(children: [
        _MigrationChoice(
            label: fromLabel,
            name: fromName,
            hint: fromHint,
            icon: fromIcon ?? const BeeLineIcon('Upload'),
            onTap: onFrom),
        const SizedBox(height: 16),
        _MigrationChoice(
            label: toLabel,
            name: toName,
            hint: toHint,
            icon: toIcon ?? const BeeLineIcon('Download'),
            onTap: onTo),
      ]);
}

class _MigrationChoice extends StatelessWidget {
  const _MigrationChoice(
      {required this.label,
      required this.name,
      required this.hint,
      required this.icon,
      required this.onTap});
  final String label, hint;
  final String? name;
  final Widget icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cards = BeeCardTheme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ExcludeSemantics(
          child: Text(label,
              style: TextStyle(fontSize: 12, color: theme.hintColor))),
      const SizedBox(height: 8),
      Semantics(
          container: true,
          button: true,
          enabled: onTap != null,
          selected: name != null,
          label: '$label · ${name ?? hint}',
          onTap: onTap,
          child: ExcludeSemantics(
              child: Opacity(
                  opacity: onTap == null ? .45 : 1,
                  child: Material(
                      color: cards.surface,
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                              constraints: const BoxConstraints(minHeight: 64),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                      color: name == null
                                          ? cards.divider
                                          : theme.colorScheme.primary
                                              .withValues(alpha: .65))),
                              child: Row(children: [
                                Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: cards.soft,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: icon),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Tooltip(
                                        message: name ?? hint,
                                        excludeFromSemantics: true,
                                        child: Text(name ?? hint,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 14,
                                                height: 1.4,
                                                color: name == null
                                                    ? theme.hintColor
                                                    : null)))),
                                const SizedBox(width: 8),
                                const BeeLineIcon('ChevronRight', size: 16),
                              ]))))))),
    ]);
  }
}

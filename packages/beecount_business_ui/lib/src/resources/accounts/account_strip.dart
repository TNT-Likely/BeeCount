import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Already filtered and ordered by the host. This model owns no account data.
class BeeAccountStripItem {
  const BeeAccountStripItem(
      {required this.id, required this.label, this.icon, this.hidden = false});
  final String id, label;
  final Widget? icon;
  final bool hidden;
}

/// Compact counterpart of [BeeAccountPicker]. Selection, including unset, is
/// controlled; loading and empty states use the same reserved height.
class BeeAccountStrip extends StatelessWidget {
  const BeeAccountStrip(
      {super.key,
      required this.items,
      required this.selected,
      required this.onSelected,
      required this.unsetLabel,
      required this.emptyLabel,
      required this.hiddenLabel,
      this.loading = false,
      this.allowUnset = true});
  final List<BeeAccountStripItem> items;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String unsetLabel, emptyLabel, hiddenLabel;
  final bool loading, allowUnset;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
          height: 32,
          child: Center(
              child: SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (items.isEmpty && !allowUnset) {
      return SizedBox(
          height: 32,
          child: Center(
              child: Text(emptyLabel,
                  style: Theme.of(context).textTheme.bodySmall)));
    }
    final choices = <BeeAccountStripItem?>[if (allowUnset) null, ...items];
    return SizedBox(
        height: 32,
        child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: choices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final item = choices[index];
              final active = item?.id == selected;
              final scheme = Theme.of(context).colorScheme;
              return Semantics(
                  selected: active,
                  button: true,
                  label: item?.hidden == true
                      ? '${item!.label}, $hiddenLabel'
                      : item?.label ?? unsetLabel,
                  child: GestureDetector(
                      onTap: () => onSelected(item?.id),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: active
                                  ? scheme.primary
                                  : BeeCardTheme.of(context).soft,
                              borderRadius: BorderRadius.circular(16)),
                          child: Center(
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                if (item?.icon != null) ...[
                                  item!.icon!,
                                  const SizedBox(width: 5)
                                ],
                                if (item?.hidden == true) ...[
                                  Icon(Icons.visibility_off,
                                      size: 12,
                                      color: active
                                          ? Colors.white70
                                          : Theme.of(context).hintColor),
                                  const SizedBox(width: 4)
                                ],
                                Text(item?.label ?? unsetLabel,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.2,
                                        fontWeight: active
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: active
                                            ? Colors.white
                                            : scheme.onSurface
                                                .withValues(alpha: .65)))
                              ])))));
            }));
  }
}

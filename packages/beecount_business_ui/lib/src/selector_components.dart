import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'recording_components.dart';

class BeeCategoryChoice {
  const BeeCategoryChoice(
      {required this.id,
      required this.label,
      required this.icon,
      this.children = const []});
  final String id, label;
  final Widget icon;
  final List<BeeCategoryChoice> children;
}

/// Hierarchy and image widgets come from the host; confirmation commits the draft.
class BeeCategoryPicker extends StatefulWidget {
  const BeeCategoryPicker(
      {super.key,
      required this.items,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.confirmLabel,
      required this.cancelLabel,
      required this.onConfirm,
      required this.onCancel});
  final List<BeeCategoryChoice> items;
  final String? selected;
  final String searchLabel, emptyLabel, confirmLabel, cancelLabel;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;
  @override
  State<BeeCategoryPicker> createState() => _BeeCategoryPickerState();
}

class _BeeCategoryPickerState extends State<BeeCategoryPicker> {
  late String? draft = widget.selected;
  String query = '';

  @override
  void didUpdateWidget(covariant BeeCategoryPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) draft = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final visible = widget.items
        .where((i) =>
            i.label.toLowerCase().contains(q) ||
            i.children.any((c) => c.label.toLowerCase().contains(q)))
        .toList();
    final parent = visible
            .where((i) => i.id == draft || i.children.any((c) => c.id == draft))
            .firstOrNull ??
        visible.firstOrNull;
    final valid = widget.items
        .any((i) => i.id == draft || i.children.any((c) => c.id == draft));
    final children = parent?.children
            .where((c) =>
                q.isEmpty ||
                parent.label.toLowerCase().contains(q) ||
                c.label.toLowerCase().contains(q))
            .toList() ??
        <BeeCategoryChoice>[];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      BeeSearchField(
          hint: widget.searchLabel,
          onChanged: (v) => setState(() => query = v)),
      const SizedBox(height: 8),
      Expanded(
          child: visible.isEmpty
              ? BeeEmptyState(title: widget.emptyLabel)
              : SingleChildScrollView(
                  child: BeeSurface(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LayoutBuilder(
                                builder: (context, constraints) => Wrap(
                                    children: visible
                                        .map((i) => SizedBox(
                                            width: constraints.maxWidth / 4,
                                            child: RecordingCategoryTile(
                                                label: i.label,
                                                icon: i.icon,
                                                selected: i.id == draft ||
                                                    i.children.any(
                                                        (c) => c.id == draft),
                                                onTap: () => setState(
                                                    () => draft = i.id))))
                                        .toList())),
                            if (parent != null && children.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: BeeCardTheme.of(context).soft,
                                      borderRadius: BorderRadius.circular(14)),
                                  child: LayoutBuilder(
                                      builder: (context, constraints) {
                                    final choices = [parent, ...children];
                                    final columns =
                                        constraints.maxWidth < 270 ? 2 : 4;
                                    return Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: choices
                                            .map((c) => SizedBox(
                                                width: (constraints.maxWidth -
                                                        (columns - 1) * 4) /
                                                    columns,
                                                height: 44,
                                                child: RecordingSubcategoryChip(
                                                    label: c.label,
                                                    icon: c.icon,
                                                    selected: draft == c.id,
                                                    onTap: () => setState(
                                                        () => draft = c.id))))
                                            .toList());
                                  }))
                            ],
                          ])))),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: BeeButton(
                label: widget.cancelLabel,
                kind: BeeButtonKind.secondary,
                onPressed: () {
                  setState(() => draft = widget.selected);
                  widget.onCancel();
                })),
        const SizedBox(width: 8),
        Expanded(
            child: BeeButton(
                label: widget.confirmLabel,
                onPressed: valid ? () => widget.onConfirm(draft!) : null)),
      ])
    ]);
  }
}

class BeeAccountChoice {
  const BeeAccountChoice(
      {required this.id,
      required this.name,
      required this.currency,
      this.balance = '',
      this.detail,
      this.icon});
  final String id, name, currency, balance;
  final String? detail;
  final Widget? icon;
}

/// The host supplies permission-filtered resources and balances. No requests here.
class BeeAccountPicker extends StatelessWidget {
  const BeeAccountPicker(
      {super.key,
      required this.accounts,
      required this.currency,
      required this.selected,
      required this.searchLabel,
      required this.emptyLabel,
      required this.unsetLabel,
      required this.onSelected,
      this.filterByCurrency = true,
      this.allowUnset = true});
  final List<BeeAccountChoice> accounts;
  final bool filterByCurrency, allowUnset;
  final String currency, searchLabel, emptyLabel, unsetLabel;
  final String? selected;
  final ValueChanged<String?> onSelected;
  @override
  Widget build(BuildContext context) => BeeChoicePicker<String?>(
          items: [
            if (allowUnset) BeeChoice<String?>(value: null, title: unsetLabel),
            ...accounts
                .where((a) => !filterByCurrency || a.currency == currency)
                .map((a) => BeeChoice<String?>(
                    value: a.id,
                    title: a.name,
                    subtitle: [
                      a.currency,
                      if (a.balance.isNotEmpty) a.balance,
                      if (a.detail != null) a.detail!
                    ].join(' · '),
                    leading: a.icon ?? const BeeLineIcon('Wallet'),
                    searchText: a.currency))
          ],
          selected: selected,
          searchLabel: searchLabel,
          emptyLabel: emptyLabel,
          onSelected: onSelected);
}

class BeeLedgerChoice {
  const BeeLedgerChoice(
      {required this.id,
      required this.name,
      required this.currency,
      this.detail});
  final String id, name, currency;
  final String? detail;
}

class BeeLedgerPicker extends StatelessWidget {
  const BeeLedgerPicker(
      {super.key,
      required this.ledgers,
      required this.currentId,
      required this.searchLabel,
      required this.emptyLabel,
      required this.currentLabel,
      required this.onSelected,
      this.createLabel,
      this.onCreate,
      this.joinLabel,
      this.onJoin});
  final List<BeeLedgerChoice> ledgers;
  final String? currentId;
  final String searchLabel, emptyLabel, currentLabel;
  final ValueChanged<String> onSelected;
  final String? createLabel, joinLabel;
  final VoidCallback? onCreate, onJoin;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
            child: BeeChoicePicker<String>(
                items: ledgers
                    .map((l) => BeeChoice(
                        value: l.id,
                        title: l.name,
                        subtitle: [
                          l.currency,
                          if (l.detail != null) l.detail!,
                          if (l.id == currentId) currentLabel
                        ].join(' · '),
                        leading: const BeeLineIcon('BookOpen')))
                    .toList(),
                selected: currentId,
                searchLabel: searchLabel,
                emptyLabel: emptyLabel,
                onSelected: onSelected)),
        if (onCreate != null && createLabel != null) ...[
          const SizedBox(height: 12),
          BeeButton(label: createLabel!, onPressed: onCreate)
        ],
        if (onJoin != null && joinLabel != null) ...[
          const SizedBox(height: 8),
          BeeButton(
              label: joinLabel!,
              kind: BeeButtonKind.secondary,
              onPressed: onJoin)
        ],
      ]);
}

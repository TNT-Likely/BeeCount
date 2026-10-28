import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'recording_components.dart';

class BeeCategoryChoice {
  const BeeCategoryChoice(
      {required this.id,
      required this.label,
      required this.icon,
      this.children = const [],
      this.enabled = true,
      this.detail});
  final String id, label;
  final Widget icon;
  final List<BeeCategoryChoice> children;
  final bool enabled;
  final String? detail;
}

/// Four columns in source order. Long labels span two cells and wrap within
/// that width. This widget never queries data or changes selection by itself.
class RecordingSubcategoryGrid extends StatelessWidget {
  const RecordingSubcategoryGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.selectedAnchorKey,
  });
  final List<BeeCategoryChoice> items;
  final String? selected;
  final ValueChanged<String> onSelected;
  final Key? selectedAnchorKey;
  static const spacing = 5.0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth;
        final cell = (width - 3 * spacing) / 4;
        final style = Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontSize: 11, fontWeight: FontWeight.w600);
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        return Wrap(spacing: spacing, runSpacing: spacing, children: [
          for (final item in items)
            Builder(builder: (context) {
              // Reserve selected weight for every item so selecting never reflows.
              final text = TextPainter(
                  text: TextSpan(text: item.label, style: style),
                  textDirection: direction,
                  textScaler: scaler,
                  locale: Localizations.maybeLocaleOf(context),
                  maxLines: 1)
                ..layout();
              final span = text.width + 16 + 5 + 12 > cell ? 2 : 1;
              text.dispose();
              return SizedBox(
                  key: item.id == selected ? selectedAnchorKey : null,
                  width: cell * span + spacing * (span - 1),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: Opacity(
                                opacity: item.enabled ? 1 : .4,
                                child: Tooltip(
                                    message: item.label,
                                    child: RecordingSubcategoryChip(
                                        key: ValueKey(
                                            'recording-category-${item.id}'),
                                        label: item.label,
                                        icon: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: item.icon),
                                        selected: item.id == selected,
                                        wrapLabel: true,
                                        onTap: item.enabled
                                            ? () => onSelected(item.id)
                                            : null)))),
                        if (item.detail != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(item.detail!,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).hintColor))),
                      ]));
            }),
        ]);
      });
}

/// Controlled hierarchy. The host supplies permission/eligibility decisions and
/// real counts; immediate selection is available for the original parent picker.
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
      required this.onCancel,
      this.immediate = false,
      this.expandAllChildren = false});
  final List<BeeCategoryChoice> items;
  final String? selected;
  final String searchLabel, emptyLabel, confirmLabel, cancelLabel;
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;
  final bool immediate, expandAllChildren;
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

  void choose(BeeCategoryChoice item, {bool direct = false}) {
    if (!item.enabled && item.children.isEmpty) return;
    if (widget.immediate) {
      if (!direct && item.children.isNotEmpty) {
        setState(() => draft = item.id);
      } else if (item.enabled) {
        widget.onConfirm(item.id);
      }
    } else {
      setState(() => draft = item.id);
    }
  }

  Widget tile(BeeCategoryChoice item) {
    final selected =
        item.id == draft || item.children.any((c) => c.id == draft);
    final navigable = item.enabled || item.children.isNotEmpty;
    return Semantics(
        enabled: navigable,
        child: Opacity(
            opacity: navigable ? 1 : .4,
            child: Column(children: [
              RecordingCategoryTile(
                  label: item.label,
                  icon: item.icon,
                  selected: selected,
                  onTap: navigable ? () => choose(item) : null),
              if (item.detail != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(item.detail!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10, color: Theme.of(context).hintColor)))
            ])));
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
    final valid = widget.items.any((i) =>
        (i.id == draft && i.enabled) ||
        i.children.any((c) => c.id == draft && c.enabled));
    List<BeeCategoryChoice> childrenOf(BeeCategoryChoice parent) =>
        parent.children
            .where((c) =>
                q.isEmpty ||
                parent.label.toLowerCase().contains(q) ||
                c.label.toLowerCase().contains(q))
            .toList();
    List<Widget> childBlock(BeeCategoryChoice group) => [
          if (childrenOf(group).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(14)),
                child: RecordingSubcategoryGrid(
                    items: [group, ...childrenOf(group)],
                    selected: draft,
                    onSelected: (id) => choose(
                        id == group.id
                            ? group
                            : group.children.firstWhere((c) => c.id == id),
                        direct: true)))
          ]
        ];
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
                            LayoutBuilder(builder: (context, constraints) {
                              Widget grid(List<BeeCategoryChoice> row) => Wrap(
                                  children: row
                                      .map((i) => SizedBox(
                                          width: constraints.maxWidth / 4,
                                          child: tile(i)))
                                      .toList());
                              if (widget.expandAllChildren) {
                                return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      grid(visible),
                                      for (final group in visible)
                                        ...childBlock(group),
                                    ]);
                              }
                              final rows = <Widget>[];
                              for (var start = 0;
                                  start < visible.length;
                                  start += 4) {
                                final row =
                                    visible.skip(start).take(4).toList();
                                rows.add(grid(row));
                                // Keep expansion beside the tapped grid row,
                                // even when many later parents fill the popup.
                                if (parent != null && row.contains(parent)) {
                                  rows.addAll(childBlock(parent));
                                }
                              }
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: rows);
                            }),
                          ])))),
      if (!widget.immediate) ...[
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
                  onPressed: valid ? () => widget.onConfirm(draft!) : null))
        ])
      ]
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

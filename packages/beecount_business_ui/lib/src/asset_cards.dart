import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'finance_components.dart';

/// Asset-only controlled layout; original summaries keep their default layout.
class BeeAssetOverviewCard extends StatelessWidget {
  const BeeAssetOverviewCard(
      {super.key,
      required this.title,
      required this.balance,
      required this.assetsLabel,
      required this.assets,
      required this.liabilitiesLabel,
      required this.liabilities,
      required this.hidden,
      required this.privacyLabel,
      required this.onPrivacy,
      this.approximate = false,
      this.unitLabel,
      this.onUnit,
      this.currencies = const [],
      this.currency,
      this.onCurrency,
      this.footnote,
      this.onFootnote,
      this.detailLabel,
      this.onDetails,
      this.warning = false});
  final String title,
      balance,
      assetsLabel,
      assets,
      liabilitiesLabel,
      liabilities,
      privacyLabel;
  final bool hidden, approximate, warning;
  final VoidCallback onPrivacy;
  final String? unitLabel, footnote, detailLabel, currency;
  final VoidCallback? onUnit, onFootnote, onDetails;
  final List<BeeSegment<String>> currencies;
  final ValueChanged<String>? onCurrency;
  @override
  Widget build(BuildContext context) {
    final colors = BeeCardTheme.of(context), theme = Theme.of(context);
    Widget metric(String label, String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: theme.hintColor)),
              const SizedBox(height: 7),
              Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(
                      amount: value, hidden: hidden, size: 19, lineHeight: 1.2))
            ]);
    Widget link(String label, VoidCallback? callback, String icon,
            {bool warn = false}) =>
        Tooltip(
            message: label,
            child: InkWell(
                onTap: callback,
                borderRadius: BorderRadius.circular(5),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (icon == 'Info') ...[
                        BeeLineIcon(icon, size: 12, color: theme.hintColor),
                        const SizedBox(width: 4)
                      ],
                      Flexible(
                          child: Text(label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: warn
                                      ? theme.colorScheme.primary
                                      : theme.hintColor))),
                      if (icon != 'Info') ...[
                        const SizedBox(width: 4),
                        BeeLineIcon(icon, size: 12, color: theme.hintColor)
                      ]
                    ]))));
    return BeeSurface(
        padding: const EdgeInsets.fromLTRB(21, 16, 21, 9),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                    flex: 2,
                    child: Row(children: [
                      Flexible(
                          child: Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: theme.hintColor))),
                      BeeIconButton(
                          label: privacyLabel,
                          icon:
                              BeeLineIcon(hidden ? 'EyeOff' : 'Eye', size: 16),
                          onPressed: onPrivacy),
                    ])),
                const SizedBox(width: 8),
                if (unitLabel != null)
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerRight,
                          child: link(unitLabel!, onUnit, 'ChevronDown')))
              ]),
              Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(
                      amount: balance,
                      hidden: hidden,
                      prefix: approximate ? '≈' : null,
                      prefixSize: 17,
                      size: 39,
                      lineHeight: 1.15)),
              if (currencies.length > 1 &&
                  currency != null &&
                  onCurrency != null) ...[
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                        spacing: 7,
                        children: currencies
                            .map((c) => BeeChoiceChip(
                                label: c.label,
                                selected: c.value == currency,
                                compact: true,
                                onSelected: (_) => onCurrency!(c.value)))
                            .toList()))
              ],
              const SizedBox(height: 21),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    Expanded(child: metric(assetsLabel, assets)),
                    const SizedBox(width: 18),
                    VerticalDivider(
                        width: 1, thickness: 1, color: colors.divider),
                    const SizedBox(width: 18),
                    Expanded(child: metric(liabilitiesLabel, liabilities))
                  ])),
              if (footnote != null || detailLabel != null) ...[
                const SizedBox(height: 17),
                Divider(height: 1, color: colors.divider),
                Row(children: [
                  if (footnote != null)
                    Expanded(child: link(footnote!, onFootnote, 'Info'))
                  else
                    const Spacer(),
                  const SizedBox(width: 10),
                  if (detailLabel != null)
                    Expanded(
                        child: Align(
                            alignment: Alignment.centerRight,
                            child: link(detailLabel!, onDetails, 'ChevronRight',
                                warn: warning)))
                ])
              ]
            ]));
  }
}

class BeeAssetTypeGroup extends StatelessWidget {
  const BeeAssetTypeGroup(
      {super.key,
      required this.title,
      required this.count,
      required this.expanded,
      required this.onToggle,
      required this.children,
      this.subtotal,
      this.onSubtotal});
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final String? subtotal;
  final VoidCallback? onSubtotal;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: BeeSurface(
          padding: EdgeInsets.zero,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(21),
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 11, 15, 7),
                        child: Row(children: [
                          Expanded(
                              child: Text('$title  $count',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).hintColor))),
                          if (!expanded && subtotal != null)
                            Flexible(
                                child: Text(subtotal!,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor))),
                          const SizedBox(width: 7),
                          BeeLineIcon(expanded ? 'ChevronUp' : 'ChevronDown',
                              size: 13, color: Theme.of(context).hintColor)
                        ]))),
                if (expanded)
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      Padding(
                          padding: const EdgeInsets.only(left: 60, right: 15),
                          child: Divider(
                              height: 1,
                              color: BeeCardTheme.of(context).divider)),
                    children[i]
                  ]
              ])));
}

/// The App supplies every original/converted amount, missing-rate and credit
/// label. No balance, currency or credit arithmetic is performed in this row.
class BeeCompactAccountRow extends StatelessWidget {
  const BeeCompactAccountRow(
      {super.key,
      required this.name,
      required this.subtitle,
      required this.amount,
      required this.icon,
      required this.hidden,
      required this.onTap,
      required this.onEdit,
      this.converted,
      this.badge,
      this.status,
      this.progress,
      this.creditLeft,
      this.creditRight,
      this.onRestore,
      this.restoreLabel,
      this.includedLabel});
  final String name, subtitle, amount;
  final Widget icon;
  final bool hidden;
  final VoidCallback onTap, onEdit;
  final String? converted,
      badge,
      status,
      creditLeft,
      creditRight,
      restoreLabel,
      includedLabel;
  final double? progress;
  final VoidCallback? onRestore;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = BeeCardTheme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Semantics(
          onLongPress: onEdit,
          child: InkWell(
              onTap: onTap,
              onLongPress: onEdit,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                  constraints: const BoxConstraints(minHeight: 72),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                  child: LayoutBuilder(
                      builder: (context, constraints) => Row(children: [
                            ExcludeSemantics(
                                child: Container(
                                    width: 35,
                                    height: 35,
                                    decoration: BoxDecoration(
                                        color: colors.soft,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    alignment: Alignment.center,
                                    child: icon)),
                            const SizedBox(width: 10),
                            Expanded(
                                flex: 5,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500)),
                                      if (badge != null)
                                        Container(
                                            margin:
                                                const EdgeInsets.only(top: 3),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: theme.colorScheme.primary
                                                    .withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                            child: Text(badge!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 9))),
                                      if (subtitle.isNotEmpty)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 3),
                                            child: Text(subtitle,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: theme.hintColor)))
                                    ])),
                            const SizedBox(width: 8),
                            Flexible(
                                flex: 5,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          BeeMoney(
                                              amount: amount,
                                              hidden: hidden,
                                              size: 15,
                                              lineHeight: 1.4),
                                          if (converted != null)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 3),
                                                child: Text(
                                                    hidden
                                                        ? '••••'
                                                        : converted!,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.right,
                                                    style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            theme.hintColor)))
                                          else if (status != null)
                                            Text(status!,
                                                maxLines: 2,
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: theme.hintColor))
                                        ])))
                          ]))))),
      if (progress != null || creditLeft != null || creditRight != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(60, 0, 15, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (progress != null) ...[
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 3,
                            color: theme.colorScheme.primary,
                            backgroundColor: colors.divider)),
                    const SizedBox(height: 7)
                  ],
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 3,
                      children: [
                        if (creditLeft != null)
                          Text(hidden ? '••••' : creditLeft!,
                              style: TextStyle(
                                  fontSize: 9, color: theme.hintColor)),
                        if (creditRight != null)
                          Text(creditRight!,
                              style: TextStyle(
                                  fontSize: 9, color: theme.hintColor))
                      ])
                ])),
      if (onRestore != null && restoreLabel != null)
        Padding(
            padding: const EdgeInsets.fromLTRB(60, 0, 15, 9),
            child: Row(children: [
              Expanded(
                  child: Text(includedLabel ?? '',
                      style: TextStyle(fontSize: 10, color: theme.hintColor))),
              BeeButton(
                  label: restoreLabel!,
                  compact: true,
                  kind: BeeButtonKind.quiet,
                  onPressed: onRestore)
            ]))
    ]);
  }
}

class BeeAssetAllocation {
  const BeeAssetAllocation(
      {required this.label, required this.value, required this.amount});
  final String label, amount;
  final double value;
}

/// Single-accent presentation of already-filtered positive asset positions.
class BeeAssetComposition extends StatefulWidget {
  const BeeAssetComposition(
      {super.key, required this.items, required this.hidden, this.note});
  final List<BeeAssetAllocation> items;
  final bool hidden;
  final String? note;
  @override
  State<BeeAssetComposition> createState() => _BeeAssetCompositionState();
}

class _BeeAssetCompositionState extends State<BeeAssetComposition> {
  int? selected;
  @override
  Widget build(BuildContext context) {
    final items = widget.items.where((item) => item.value > 0).toList();
    final total = items.fold(0.0, (n, item) => n + item.value);
    if (items.isEmpty || total <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context),
        pick = selected != null && selected! < items.length
            ? items[selected!]
            : null;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                  height: 12,
                  child: Row(children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                          flex: (items[i].value / total * 10000)
                              .round()
                              .clamp(1, 10000),
                          child: InkWell(
                              onTap: () => setState(() => selected = i),
                              child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  color: theme.colorScheme.primary.withValues(
                                      alpha: (1 - i * .12).clamp(.25, 1)))))
                  ]))),
          const SizedBox(height: 10),
          if (pick != null)
            Text('${pick.label} · ${widget.hidden ? '••••' : pick.amount}',
                style: const TextStyle(fontSize: 11)),
          Wrap(spacing: 14, runSpacing: 4, children: [
            for (var i = 0; i < items.length; i++)
              InkWell(
                  onTap: () => setState(() => selected = i),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                    alpha: (1 - i * .12).clamp(.25, 1)),
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 5),
                        Text(
                            '${items[i].label}  ${(items[i].value / total * 100).toStringAsFixed(1)}%',
                            style:
                                TextStyle(fontSize: 10, color: theme.hintColor))
                      ])))
          ]),
          if (widget.note != null)
            Text(widget.note!,
                style: TextStyle(fontSize: 10, color: theme.hintColor))
        ]);
  }
}

class BeeAssetAccountToolbar extends StatelessWidget {
  const BeeAssetAccountToolbar(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged,
      required this.searchLabel,
      required this.onSearch,
      required this.orderLabel,
      required this.onOrder});
  final List<BeeSegment<String>> items;
  final String value, searchLabel, orderLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch, onOrder;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 13, bottom: 8),
      child: LayoutBuilder(builder: (context, bounds) {
        final tabs =
            BeeUnderlineTabs(items: items, value: value, onChanged: onChanged);
        final actions = Row(mainAxisSize: MainAxisSize.min, children: [
          BeeIconButton(
              label: searchLabel,
              icon: const BeeLineIcon('Search', size: 17),
              onPressed: onSearch),
          BeeIconButton(
              label: orderLabel,
              icon: const RotatedBox(
                  quarterTurns: 1,
                  child: BeeLineIcon('ArrowRightLeft', size: 17)),
              onPressed: onOrder)
        ]);
        return MediaQuery.textScalerOf(context).scale(13) > 16 &&
                bounds.maxWidth < 370
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                    tabs,
                    Align(alignment: Alignment.centerRight, child: actions)
                  ])
            : Row(children: [
                Expanded(child: tabs),
                const SizedBox(width: 4),
                actions
              ]);
      }));
}

/// Mini chart shared by the live asset page and Flutter component acceptance.
/// The host supplies the real series, selected month and formatted amount.
class BeeAssetTrendPreview extends StatelessWidget {
  const BeeAssetTrendPreview(
      {super.key,
      required this.values,
      required this.labels,
      required this.selected,
      required this.pointLabel,
      required this.amount,
      required this.hidden,
      required this.onSelected,
      required this.detailLabel,
      required this.onDetails});
  final List<double> values;
  final List<String> labels;
  final int selected;
  final String pointLabel, amount, detailLabel;
  final bool hidden;
  final ValueChanged<int> onSelected;
  final VoidCallback onDetails;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
              child: Text('$pointLabel · ${hidden ? '••••' : amount}',
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 10, color: Theme.of(context).hintColor))),
          BeeButton(
              label: detailLabel,
              compact: true,
              kind: BeeButtonKind.quiet,
              onPressed: onDetails)
        ]),
        SizedBox(
            height: 80,
            child: LayoutBuilder(
                builder: (context, bounds) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: values.isEmpty
                        ? null
                        : (details) => onSelected((details.localPosition.dx /
                                bounds.maxWidth *
                                (values.length - 1))
                            .round()
                            .clamp(0, values.length - 1)),
                    child: BeeLineChart(
                        values: values,
                        xLabels: labels,
                        highlightIndex: selected,
                        onSwipeLeft: () {},
                        onSwipeRight: () {},
                        showGrid: true,
                        showDots: false,
                        annotate: false,
                        hideAmounts: hidden,
                        themeColor: Theme.of(context).colorScheme.primary,
                        minimal: true,
                        interactive: false,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        whiteBg:
                            Theme.of(context).brightness != Brightness.dark))))
      ]);
}

import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'transaction_swipe.dart';

/// ImageProvider supports file, memory, network or the host's cached image layer.
/// Images keep their own colors; only the fallback/line icon is tinted.
class BeeCategoryIcon extends StatelessWidget {
  const BeeCategoryIcon(
      {super.key,
      this.name = 'Shapes',
      this.image,
      this.size = 34,
      this.selected = false,
      this.crop = false,
      this.label});
  final String name;
  final ImageProvider? image;
  final double size;
  final bool selected, crop;
  final String? label;
  @override
  Widget build(BuildContext context) {
    Widget fallback() => BeeLineIcon(name, size: size * .55);
    return Semantics(
        label: label,
        image: true,
        child: Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * .16),
            decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(size * .32)),
            child: image == null
                ? fallback()
                : ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image(
                        image: image!,
                        fit: crop ? BoxFit.cover : BoxFit.contain,
                        frameBuilder: (_, child, frame, synchronous) =>
                            synchronous || frame != null
                                ? child
                                : const Center(
                                    child: SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 1.5))),
                        errorBuilder: (_, error, stack) => fallback()))));
  }
}

class BeeTagData {
  const BeeTagData(this.id, this.label, this.color);
  final String id, label;
  final Color color;
}

class BeeTag extends StatelessWidget {
  const BeeTag(
      {super.key,
      required this.tag,
      this.selected = false,
      this.onTap,
      this.compact = false});
  final BeeTagData tag;
  final bool selected;
  final VoidCallback? onTap;

  /// Compact inline pills keep their 21px visual size when tappable.
  /// The larger choice style belongs to the tag picker.
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final inline = compact || onTap == null;
    final radius = BorderRadius.circular(inline ? 20 : 12);
    Widget pill = Container(
      key: const ValueKey('bee-tag-pill'),
      constraints: BoxConstraints(minHeight: inline ? 21 : 44),
      padding: EdgeInsets.symmetric(horizontal: inline ? 8 : 12, vertical: 3),
      decoration: BoxDecoration(
          color: tag.color.withValues(alpha: .12),
          border: selected ? Border.all(color: tag.color) : null,
          borderRadius: radius),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!inline) ...[
          BeeLineIcon(selected ? 'Check' : 'Tag', size: 13, color: tag.color),
          const SizedBox(width: 4)
        ],
        Text(tag.label,
            style: TextStyle(
                fontSize: inline ? 10 : 12, height: 1.5, color: tag.color)),
      ]),
    );
    if (compact && onTap != null) {
      pill = ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28, minWidth: 44),
          child: Center(widthFactor: 1, heightFactor: 1, child: pill));
    }
    return Semantics(
        selected: selected,
        button: onTap != null,
        child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: InkWell(onTap: onTap, borderRadius: radius, child: pill)));
  }
}

class BeeMoney extends StatelessWidget {
  const BeeMoney(
      {super.key,
      required this.amount,
      this.prefix,
      this.prefixSize,
      this.converted,
      this.hidden = false,
      this.size = 28,
      this.color,
      this.lineHeight});
  final String amount;
  final String? prefix, converted;
  final bool hidden;
  final double size;
  final double? prefixSize;
  final double? lineHeight;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text.rich(
                    TextSpan(children: [
                      if (!hidden && prefix != null)
                        TextSpan(
                            text: '$prefix ',
                            style: TextStyle(
                                fontSize: prefixSize ?? size * .6,
                                fontWeight: FontWeight.w400)),
                      TextSpan(text: hidden ? '••••' : amount)
                    ]),
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: size,
                        height: lineHeight,
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()]))),
            if (converted != null)
              Text(hidden ? '••••' : converted!,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.55,
                      color: Theme.of(context).hintColor)),
          ]);
}

/// Category icon and content remain independent hit targets.

enum BeeTransactionKind { expense, income, transfer }

/// Mirrors the existing transaction row: full date overrides the time switch;
/// a time-only row suppresses exact midnight, but keeps non-zero seconds.
String? formatBeeTransactionTimestamp(DateTime? value,
    {bool showTime = false, bool showFullDate = false}) {
  if (value == null) return null;
  String pad(int n) => n.toString().padLeft(2, '0');
  if (showFullDate) {
    return '${value.year}-${pad(value.month)}-${pad(value.day)} ${pad(value.hour)}:${pad(value.minute)}';
  }
  if (!showTime ||
      (value.hour == 0 && value.minute == 0 && value.second == 0)) {
    return null;
  }
  return '${pad(value.hour)}:${pad(value.minute)}:${pad(value.second)}';
}

class BeeTransactionRow extends StatelessWidget {
  const BeeTransactionRow(
      {super.key,
      required this.title,
      required this.amount,
      required this.icon,
      required this.onCategoryTap,
      required this.onTap,
      this.subtitle,
      this.happenedAt,
      this.showTime = false,
      this.amountColor,
      this.incomeIsRed = true,
      this.showFullDate = false,
      this.accountName,
      this.categoryLabel,
      this.ledgerName,
      this.note,
      this.onTagTap,
      this.onMoreTagsTap,
      this.onAttachmentTap,
      this.converted,
      this.tags = const [],
      this.onMenu,
      this.onDeleteRequested,
      this.deleteLabel,
      this.selected,
      this.onSelected,
      this.hidden = false,
      this.hasAttachment = false,
      this.kind = BeeTransactionKind.expense,
      this.readOnly = false,
      this.statusLabels = const [],
      this.attachmentCount = 0});
  final String title, amount;
  final String? subtitle,
      converted,
      deleteLabel,
      note,
      accountName,
      categoryLabel,
      ledgerName;
  final DateTime? happenedAt;
  final Color? amountColor;
  final bool showTime, showFullDate, incomeIsRed;
  final ValueChanged<BeeTagData>? onTagTap;
  final VoidCallback? onMoreTagsTap, onAttachmentTap;
  final Widget icon;
  final List<BeeTagData> tags;
  final VoidCallback onCategoryTap, onTap;
  final VoidCallback? onMenu;
  final Future<void> Function()? onDeleteRequested;
  final bool? selected;
  final ValueChanged<bool>? onSelected;
  final bool hidden, hasAttachment, readOnly;
  final BeeTransactionKind kind;
  final List<String> statusLabels;
  final int attachmentCount;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = formatBeeTransactionTimestamp(happenedAt,
        showTime: showTime, showFullDate: showFullDate);
    final secondary = [timestamp, categoryLabel, accountName ?? subtitle]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final dark = theme.brightness == Brightness.dark;
    final colorKind = incomeIsRed
        ? kind
        : switch (kind) {
            BeeTransactionKind.expense => BeeTransactionKind.income,
            BeeTransactionKind.income => BeeTransactionKind.expense,
            BeeTransactionKind.transfer => BeeTransactionKind.transfer,
          };
    final moneyColor = switch (colorKind) {
      BeeTransactionKind.expense =>
        dark ? const Color(0xff79c8ad) : const Color(0xff25856d),
      BeeTransactionKind.income =>
        dark ? const Color(0xffe49a8d) : const Color(0xffbd5d50),
      BeeTransactionKind.transfer => theme.colorScheme.onSurfaceVariant,
    };
    final row = Material(
        color: selected == true
            ? theme.colorScheme.primary.withValues(alpha: .1)
            : Colors.transparent,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 69),
            child: Row(children: [
              if (selected != null)
                Checkbox(
                    value: selected,
                    onChanged: onSelected == null || readOnly
                        ? null
                        : (v) => onSelected!(v ?? false)),
              if (selected == null)
                Semantics(
                    button: true,
                    child: InkWell(
                        onTap: onCategoryTap,
                        onLongPress:
                            readOnly || selected != null ? null : onMenu,
                        child: SizedBox(
                            width: 49,
                            height: 61,
                            child: Center(child: icon)))),
              Expanded(
                  child: InkWell(
                      onTap: selected != null
                          ? (readOnly || onSelected == null
                              ? null
                              : () => onSelected!(!selected!))
                          : onTap,
                      onLongPress: readOnly || selected != null ? null : onMenu,
                      child: Padding(
                          padding: const EdgeInsets.fromLTRB(5, 9, 0, 9),
                          child: LayoutBuilder(
                              builder: (context, constraints) => Row(children: [
                                    Expanded(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text.rich(
                                                    TextSpan(
                                                        text: title,
                                                        children: [
                                                          if (note != null &&
                                                              note!
                                                                  .isNotEmpty &&
                                                              note != title)
                                                            TextSpan(
                                                                text:
                                                                    '  ($note)',
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w400,
                                                                    color: theme
                                                                        .hintColor))
                                                        ]),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500))),
                                            if (ledgerName != null &&
                                                ledgerName!.isNotEmpty) ...[
                                              const SizedBox(width: 5),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        constraints.maxWidth *
                                                            .23),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme.primary
                                                          .withValues(
                                                              alpha: .1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4)),
                                                  child: Text(ledgerName!,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: theme
                                                              .colorScheme
                                                              .primary)),
                                                ),
                                              ),
                                            ],
                                          ]),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            if (secondary.isNotEmpty)
                                              Flexible(
                                                  child: Text(secondary,
                                                      maxLines:
                                                          showFullDate ? 3 : 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: theme
                                                              .hintColor))),
                                            if (hasAttachment ||
                                                attachmentCount > 0) ...[
                                              const SizedBox(width: 4),
                                              InkWell(
                                                  onTap: selected != null
                                                      ? null
                                                      : onAttachmentTap,
                                                  child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 4),
                                                      child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            BeeLineIcon(
                                                                'ImagePlus',
                                                                size: 12,
                                                                color: theme
                                                                    .hintColor),
                                                            if (attachmentCount > 0)
                                                              Text(
                                                                  '$attachmentCount',
                                                                  style: TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: theme
                                                                          .hintColor))
                                                          ]))),
                                            ]
                                          ]),
                                          if (statusLabels.isNotEmpty)
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Wrap(
                                                    spacing: 4,
                                                    runSpacing: 3,
                                                    children: statusLabels
                                                        .map((s) => Container(
                                                            padding: const EdgeInsets.symmetric(
                                                                horizontal: 5,
                                                                vertical: 2),
                                                            decoration: BoxDecoration(
                                                                color: BeeCardTheme.of(context)
                                                                    .soft,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                        6)),
                                                            child: Text(s,
                                                                style: TextStyle(
                                                                    fontSize: 9,
                                                                    color: theme
                                                                        .hintColor))))
                                                        .toList())),
                                        ])),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxWidth:
                                                constraints.maxWidth * .52),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              BeeMoney(
                                                  amount: amount,
                                                  hidden: hidden,
                                                  size: 16,
                                                  color: amountColor ??
                                                      moneyColor),
                                              if (converted != null ||
                                                  tags.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Wrap(
                                                    alignment:
                                                        WrapAlignment.end,
                                                    spacing: 4,
                                                    runSpacing: 3,
                                                    children: [
                                                      if (converted != null)
                                                        Text(
                                                            hidden
                                                                ? '••••'
                                                                : converted!,
                                                            style: TextStyle(
                                                                fontSize: 11,
                                                                color: theme
                                                                    .hintColor)),
                                                      ...tags
                                                          .take(
                                                              converted == null
                                                                  ? 2
                                                                  : 1)
                                                          .map((tag) => BeeTag(
                                                              tag: tag,
                                                              compact: true,
                                                              onTap: onTagTap ==
                                                                          null ||
                                                                      selected !=
                                                                          null
                                                                  ? null
                                                                  : () =>
                                                                      onTagTap!(
                                                                          tag))),
                                                      if (tags.length >
                                                          (converted == null
                                                              ? 2
                                                              : 1))
                                                        InkWell(
                                                            onTap: selected !=
                                                                    null
                                                                ? null
                                                                : onMoreTagsTap,
                                                            child: Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        4,
                                                                    vertical:
                                                                        2),
                                                                child: Text(
                                                                    '+${tags.length - (converted == null ? 2 : 1)}',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color: theme
                                                                            .hintColor))))
                                                    ])
                                              ]
                                            ])),
                                  ]))))),
            ])));
    if (onDeleteRequested == null || readOnly || selected != null) return row;
    return TransactionSwipeAction(
        key: ValueKey('swipe-${key ?? title}'),
        onDeleteRequested: onDeleteRequested!,
        deleteLabel: deleteLabel ??
            MaterialLocalizations.of(context).deleteButtonTooltip,
        child: row);
  }
}

class BeeSummaryCard extends StatelessWidget {
  const BeeSummaryCard(
      {super.key,
      required this.title,
      required this.amount,
      required this.incomeLabel,
      required this.income,
      required this.expenseLabel,
      required this.expense,
      this.amountLabel,
      this.currencyLabel,
      this.prefix,
      this.budget,
      this.hidden = false,
      this.onContextTap,
      this.onPrivacyTap,
      this.privacyLabel});
  final String title, amount, incomeLabel, income, expenseLabel, expense;
  final String? amountLabel, currencyLabel, prefix, privacyLabel;
  final Widget? budget;
  final bool hidden;
  final VoidCallback? onContextTap, onPrivacyTap;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 27),
            child: Row(children: [
              Expanded(
                  child: InkWell(
                      onTap: onContextTap,
                      child: Row(children: [
                        Flexible(
                            child: Text(title,
                                style: const TextStyle(fontSize: 13))),
                        if (onContextTap != null) ...[
                          const SizedBox(width: 5),
                          const BeeLineIcon('ChevronDown', size: 14)
                        ]
                      ]))),
              if (currencyLabel != null)
                Text(currencyLabel!,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor))
            ])),
        const SizedBox(height: 13),
        if (amountLabel != null)
          Row(children: [
            Text(amountLabel!,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).hintColor)),
            if (onPrivacyTap != null)
              SizedBox(
                  width: 30,
                  height: 26,
                  child: IconButton(
                      tooltip: privacyLabel,
                      style: IconButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: onPrivacyTap,
                      icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye',
                          size: 14, color: Theme.of(context).hintColor)))
          ]),
        const SizedBox(height: 6),
        Align(
            alignment: Alignment.centerLeft,
            child: BeeMoney(
                amount: amount,
                prefix: prefix,
                hidden: hidden,
                size: 36,
                lineHeight: 1.3)),
        const SizedBox(height: 17),
        Row(children: [
          Expanded(
              child: _Metric(incomeLabel, hidden ? '••••' : income,
                  size: 15, labelSize: 11, gap: 4, lineHeight: 1.5)),
          const SizedBox(width: 10),
          Expanded(
              child: _Metric(expenseLabel, hidden ? '••••' : expense,
                  size: 15, labelSize: 11, gap: 4, lineHeight: 1.5))
        ]),
        if (budget != null) ...[
          const SizedBox(height: 17),
          Divider(
              height: 1, color: Theme.of(context).dividerColor, thickness: .6),
          const SizedBox(height: 15),
          budget!
        ],
      ]));
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value,
      {this.size = 12, this.labelSize = 10, this.gap = 3, this.lineHeight});
  final String label, value;
  final double size, labelSize, gap;
  final double? lineHeight;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                fontSize: labelSize,
                height: lineHeight,
                color: Theme.of(context).hintColor)),
        SizedBox(height: gap),
        Text(value,
            style: TextStyle(
                fontSize: size,
                height: lineHeight,
                fontWeight: FontWeight.w600))
      ]);
}

class BeeLedgerCard extends StatelessWidget {
  const BeeLedgerCard(
      {super.key,
      required this.name,
      required this.subtitle,
      required this.icon,
      required this.income,
      required this.expense,
      required this.incomeLabel,
      required this.expenseLabel,
      required this.currentLabel,
      required this.onSelect,
      required this.onMenu,
      this.current = false,
      this.status,
      this.footer,
      this.actions = const []});
  final String name,
      subtitle,
      income,
      expense,
      incomeLabel,
      expenseLabel,
      currentLabel;
  final Widget icon;
  final Widget? status, footer;
  final bool current;
  final VoidCallback onSelect, onMenu;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BeeCardTheme.of(context);
    return Semantics(
        selected: current,
        child: Material(
            color: current
                ? Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: .03),
                    colors.surface)
                : colors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                    color: current
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    width: 2)),
            child: InkWell(
                onTap: onSelect,
                onLongPress: onMenu,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(children: [
                      ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 47),
                          child: Row(children: [
                            Container(
                                width: 39,
                                height: 39,
                                decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: .1),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Center(child: icon)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Text(subtitle,
                                      style: TextStyle(
                                          fontSize: 11, color: theme.hintColor))
                                ])),
                            if (status != null) ...[
                              status!,
                              const SizedBox(width: 8)
                            ],
                            if (current)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const BeeLineIcon('Check', size: 12),
                                        const SizedBox(width: 3),
                                        Text(currentLabel,
                                            style:
                                                const TextStyle(fontSize: 10))
                                      ]))
                          ])),
                      const SizedBox(height: 19),
                      Row(children: [
                        Expanded(child: _Metric(expenseLabel, expense)),
                        Expanded(child: _Metric(incomeLabel, income))
                      ]),
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!
                      ],
                      const SizedBox(height: 14),
                      Row(children: [
                        for (var i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 7),
                          Expanded(child: actions[i])
                        ],
                        const SizedBox(width: 7),
                        SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                                onPressed: onMenu,
                                tooltip: MaterialLocalizations.of(context)
                                    .showMenuTooltip,
                                style: IconButton.styleFrom(
                                    backgroundColor: colors.soft,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                icon: const BeeLineIcon('Ellipsis', size: 19)))
                      ]),
                    ])))));
  }
}

enum BeeSyncState {
  signedOut,
  unconfigured,
  noCloudData,
  synced,
  localNewer,
  cloudNewer,
  conflict,
  checking,
  syncing,
  offline,
  error
}

class BeeSyncStatus extends StatelessWidget {
  const BeeSyncStatus(
      {super.key,
      required this.state,
      required this.title,
      required this.label,
      this.detail,
      this.progress,
      this.onTap,
      this.action});
  final BeeSyncState state;
  final String title, label;
  final String? detail;
  final double? progress;
  final VoidCallback? onTap;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      BeeSyncState.synced => const Color(0xff43835e),
      BeeSyncState.error || BeeSyncState.offline => theme.colorScheme.error,
      BeeSyncState.localNewer ||
      BeeSyncState.cloudNewer ||
      BeeSyncState.conflict =>
        theme.brightness == Brightness.dark
            ? const Color(0xffe9bc70)
            : const Color(0xffa06a14),
      _ => theme.hintColor
    };
    final busy =
        state == BeeSyncState.checking || state == BeeSyncState.syncing;
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(children: [
              Row(children: [
                const SizedBox(
                    width: 26, child: BeeLineIcon('CloudSync', size: 18)),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 3),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11, height: 1.6, color: color)),
                      if (detail != null)
                        Text(detail!,
                            style:
                                TextStyle(fontSize: 10, color: theme.hintColor))
                    ])),
                if (action != null)
                  action!
                else if (busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 1.5))
                else
                  BeeLineIcon(
                      switch (state) {
                        BeeSyncState.synced => 'Check',
                        BeeSyncState.error ||
                        BeeSyncState.offline ||
                        BeeSyncState.conflict =>
                          'CircleHelp',
                        _ => 'ChevronRight'
                      },
                      size: 18,
                      color: color)
              ]),
              if (state == BeeSyncState.syncing && progress != null) ...[
                const SizedBox(height: 7),
                LinearProgressIndicator(
                    value: progress!.isFinite ? progress!.clamp(0, 1) : null,
                    minHeight: 3)
              ]
            ])));
  }
}

class BeeLedgerBalance extends StatelessWidget {
  const BeeLedgerBalance(
      {super.key,
      required this.ledger,
      required this.amount,
      required this.stats,
      required this.onLedgerTap,
      required this.onPrivacyTap,
      required this.privacyLabel,
      this.balanceLabel,
      this.days,
      this.count,
      this.daysLabel,
      this.countLabel,
      this.prefix,
      this.hidden = false});
  final String ledger, amount, stats, privacyLabel;
  final String? balanceLabel, days, count, daysLabel, countLabel, prefix;
  final VoidCallback onLedgerTap, onPrivacyTap;
  final bool hidden;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: InkWell(
                  onTap: onLedgerTap,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 30),
                      child: Row(children: [
                        const BeeLineIcon('BookOpen', size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(ledger,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11))),
                        const SizedBox(width: 4),
                        const BeeLineIcon('ChevronDown', size: 14)
                      ])))),
          if (balanceLabel != null)
            Text(balanceLabel!,
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).hintColor)),
          SizedBox(
              width: 32,
              height: 30,
              child: IconButton(
                  tooltip: privacyLabel,
                  onPressed: onPrivacyTap,
                  padding: EdgeInsets.zero,
                  icon: BeeLineIcon(hidden ? 'EyeOff' : 'Eye', size: 16)))
        ]),
        const SizedBox(height: 3),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: BeeMoney(
                      amount: amount,
                      prefix: prefix,
                      hidden: hidden,
                      size: 23))),
          const SizedBox(width: 10),
          if (days != null && count != null)
            Row(children: [
              _stat(context, days!, daysLabel ?? ''),
              const SizedBox(width: 8),
              _stat(context, count!, countLabel ?? '')
            ])
          else
            Text(stats,
                style:
                    TextStyle(fontSize: 10, color: Theme.of(context).hintColor))
        ]),
      ]));
  Widget _stat(BuildContext context, String value, String label) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 2),
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: Theme.of(context).hintColor))
          ]);
}

class BeeHomeIdentity extends StatelessWidget {
  const BeeHomeIdentity(
      {super.key,
      required this.name,
      required this.ledger,
      required this.logo,
      required this.onLedgerTap,
      required this.actions,
      this.showBrand = true,
      this.pageTitle});
  final String name, ledger;
  final String? pageTitle;
  final Widget logo;
  final VoidCallback onLedgerTap;
  final List<Widget> actions;
  final bool showBrand;
  Widget _ledger(BuildContext context) => InkWell(
      onTap: onLedgerTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
            child: Text(ledger,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: showBrand ? 11 : 13,
                    color: Theme.of(context).hintColor))),
        const SizedBox(width: 5),
        BeeLineIcon('ChevronDown',
            size: 15, color: Theme.of(context).hintColor),
      ]));
  @override
  Widget build(BuildContext context) => Row(children: [
        if (showBrand) ...[
          SizedBox(width: 26, height: 32, child: logo),
          const SizedBox(width: 8)
        ],
        Expanded(
            child: showBrand
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        _ledger(context),
                      ])
                : Row(children: [
                    Flexible(
                        child: Text(pageTitle ?? name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 23, fontWeight: FontWeight.w600))),
                    const SizedBox(width: 8),
                    Flexible(child: _ledger(context)),
                  ])),
        ...actions,
      ]);
}

class BeeProfile extends StatelessWidget {
  const BeeProfile(
      {super.key,
      required this.nickname,
      this.greeting,
      this.profileLabel,
      this.editLabel,
      required this.subtitle,
      required this.avatar,
      required this.onEdit,
      required this.onTap});
  final String nickname, subtitle;
  final String? greeting, profileLabel, editLabel;
  final Widget avatar;
  final VoidCallback onEdit, onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      child: Row(children: [
        Semantics(
            container: true,
            button: true,
            label: profileLabel ?? nickname,
            excludeSemantics: true,
            onTap: onTap,
            child: InkWell(
                onTap: onTap,
                child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(18)),
                    child: avatar))),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
              container: true,
              button: true,
              label: editLabel,
              child: InkWell(
                  onTap: onEdit,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (greeting != null) ...[
                          Text(greeting!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).hintColor)),
                          const SizedBox(width: 8)
                        ],
                        Flexible(
                            child: Text(nickname,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 6),
                        const BeeLineIcon('PencilLine', size: 13)
                      ])))),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ])),
        Semantics(
            container: true,
            button: true,
            label: profileLabel ?? nickname,
            excludeSemantics: true,
            onTap: onTap,
            child: IconButton(
                tooltip: profileLabel,
                onPressed: onTap,
                icon: const BeeLineIcon('ChevronRight')))
      ]));
}

class BeeRankItem {
  const BeeRankItem(
      {required this.id,
      required this.label,
      required this.amount,
      required this.fraction,
      required this.icon,
      this.children = const []});
  final String id, label, amount;
  final double fraction;
  final Widget icon;
  final List<BeeRankItem> children;
}

class BeeCategoryRanking extends StatelessWidget {
  const BeeCategoryRanking(
      {super.key,
      required this.items,
      required this.expanded,
      required this.onExpand,
      required this.onDetail});
  final List<BeeRankItem> items;
  final Set<String> expanded;
  final ValueChanged<String> onExpand, onDetail;
  @override
  Widget build(BuildContext context) => Column(
      children: items
          .map((item) => Column(children: [
                Row(children: [
                  InkWell(
                      onTap: () => onDetail(item.id),
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(child: item.icon))),
                  Expanded(
                      child: InkWell(
                          onTap: () => item.children.isEmpty
                              ? onDetail(item.id)
                              : onExpand(item.id),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: BeeProgress(
                                  value: item.fraction,
                                  label: item.label,
                                  trailing: item.amount)))),
                  if (item.children.isNotEmpty)
                    IconButton(
                        onPressed: () => onExpand(item.id),
                        icon: BeeLineIcon(
                            expanded.contains(item.id)
                                ? 'ChevronUp'
                                : 'ChevronDown',
                            size: 14))
                ]),
                if (expanded.contains(item.id))
                  Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: BeeCategoryRanking(
                          items: item.children,
                          expanded: expanded,
                          onExpand: onExpand,
                          onDetail: onDetail)),
              ]))
          .toList());
}

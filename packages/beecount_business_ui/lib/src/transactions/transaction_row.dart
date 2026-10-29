import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'transaction_fields.dart';
import 'transaction_presentation.dart';
import 'transaction_row_layout.dart';
import 'transaction_swipe.dart';
export 'transaction_fields.dart';

/// C3 transaction presentation: ordinary rows use two lines, complex rows at
/// most three. The host supplies original values, preferences and callbacks.
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
      this.horizontalInset,
      this.incomeIsRed = true,
      this.showFullDate = false,
      this.accountName,
      this.categoryLabel,
      this.categoryActionLabel,
      this.ledgerName,
      this.note,
      this.detailsNote,
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
      this.attachmentCount = 0,
      this.labels = const BeeTransactionRowLabels(),
      this.onMoreFieldsTap});
  final String title, amount;
  final String? subtitle,
      converted,
      deleteLabel,
      note,
      detailsNote,
      accountName,
      categoryLabel,
      categoryActionLabel,
      ledgerName;
  final DateTime? happenedAt;
  final Color? amountColor;

  /// Containers that already provide list gutters can align rows to headers.
  final double? horizontalInset;
  final bool showTime, showFullDate, incomeIsRed;
  final ValueChanged<BeeTagData>? onTagTap;
  final VoidCallback? onMoreTagsTap, onAttachmentTap, onMoreFieldsTap;
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
  final BeeTransactionRowLabels labels;

  String? get _account => accountName ?? subtitle;
  bool get _hasAttachment => hasAttachment || attachmentCount > 0;
  String get _attachmentText => attachmentCount > 0 ? '$attachmentCount' : '';

  /// A real field disclosure, including values folded by density. Opening it
  /// never edits/selects the transaction, even in read-only or batch mode.
  void _showFields(BuildContext context) {
    if (onMoreFieldsTap != null) {
      onMoreFieldsTap!();
      return;
    }
    void follow(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    final time = happenedAt?.toIso8601String().replaceFirst('T', ' ');
    showBeeSheet<void>(context,
        title: labels.fieldsTitle,
        child: BeeTransactionFields(fields: [
          BeeTransactionField(
              label: labels.amount, value: hidden ? '••••' : amount),
          if (converted != null)
            BeeTransactionField(
                label: labels.converted, value: hidden ? '••••' : converted!),
          BeeTransactionField(
              label: labels.category,
              value: categoryLabel ?? categoryActionLabel ?? title),
          if (_account?.isNotEmpty == true)
            BeeTransactionField(label: labels.account, value: _account!),
          if (ledgerName?.isNotEmpty == true)
            BeeTransactionField(label: labels.ledger, value: ledgerName!),
          if (detailsNote?.isNotEmpty == true || note?.isNotEmpty == true)
            BeeTransactionField(
                label: labels.note, value: detailsNote ?? note!),
          if (time != null)
            BeeTransactionField(label: labels.time, value: time),
          if (statusLabels.isNotEmpty)
            BeeTransactionField(
                label: labels.rules, value: statusLabels.join(' · ')),
          if (readOnly)
            BeeTransactionField(label: labels.access, value: labels.readOnly),
          if (tags.isNotEmpty)
            BeeTransactionField(
                label: labels.tags,
                value: tags.map((t) => t.label).join(' · '),
                onTap: () => follow(() => _showTags(context))),
          if (_hasAttachment)
            BeeTransactionField(
                label: labels.attachments,
                value: _attachmentText.isEmpty
                    ? labels.attachments
                    : _attachmentText,
                onTap: onAttachmentTap == null
                    ? null
                    : () => follow(onAttachmentTap!)),
        ]));
  }

  void _showTags(BuildContext context) {
    if (onMoreTagsTap != null) {
      onMoreTagsTap!();
      return;
    }
    showBeeSheet<void>(context,
        title: labels.tags,
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final tag in tags)
            BeeInlineLabel(
                label: tag.label,
                foreground: tag.color,
                background: tag.color.withValues(alpha: .12),
                onTap: onTagTap == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        onTagTap!(tag);
                      })
        ]));
  }

  InlineSpan _amountSpan(TextStyle style) {
    if (hidden) return TextSpan(text: '••••', style: style);
    final parts = RegExp(r'^([+−-]?)([^0-9]*)([0-9][0-9,]*(?:\.[0-9]+)?)$')
        .firstMatch(amount);
    if (parts == null) return TextSpan(text: amount, style: style);
    return TextSpan(style: style, children: [
      TextSpan(text: parts[1]),
      if (parts[2]!.isNotEmpty)
        TextSpan(
            text: parts[2],
            style: const TextStyle(fontSize: 12, letterSpacing: -.1)),
      TextSpan(text: parts[3]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = BeeCardTheme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final inherited = DefaultTextStyle.of(context).style;
    TextStyle style(double size,
            {Color? color, FontWeight? weight, double height = 1.3}) =>
        inherited.copyWith(
            fontSize: size,
            height: height,
            color: color ?? theme.hintColor,
            fontWeight: weight ?? FontWeight.w400,
            letterSpacing: 0);
    final primaryStyle =
        style(14, color: theme.colorScheme.onSurface, weight: FontWeight.w500);
    final secondaryStyle = style(10.5);
    final smallStyle = style(10, height: 1.2);
    final timestampStyle = style(9.5);
    final moneyStyle = style(16,
            color: amountColor ??
                beeTransactionColor(context, kind, incomeIsRed: incomeIsRed),
            weight: FontWeight.w600,
            height: 1.25)
        .copyWith(
            letterSpacing: -.25,
            fontFeatures: const [FontFeature.tabularFigures()]);
    final moneySpan = _amountSpan(moneyStyle);
    InlineSpan titleSpan(bool wide) => TextSpan(
            text: title,
            style: wide ? primaryStyle.copyWith(fontSize: 13) : primaryStyle,
            children: [
              if (note?.isNotEmpty == true && note != title)
                TextSpan(text: ' ($note)', style: style(11)),
            ]);
    double spanWidth(InlineSpan span) {
      final painter = TextPainter(
          text: span, textDirection: direction, textScaler: scaler, maxLines: 1)
        ..layout();
      return painter.width;
    }

    double measure(String text, TextStyle textStyle) =>
        spanWidth(TextSpan(text: text, style: textStyle));
    final time = formatBeeTransactionTimestamp(happenedAt,
        showTime: showTime, showFullDate: showFullDate);
    final account = _account?.isNotEmpty == true ? _account : null;
    double tagWidth(BeeTagData tag) =>
        math.min(84, measure(tag.label, smallStyle) + 10);
    double tagsWidth(int limit) {
      if (tags.isEmpty) return 0;
      final count = math.min(limit, tags.length);
      final tokens = tags.take(count).map(tagWidth).toList();
      if (tags.length > count) {
        tokens.add(measure('+${tags.length - count}', smallStyle) +
            (count == 0 ? 8 : 4));
      }
      return tokens.fold(0.0, (a, b) => a + b) +
          math.max(0, tokens.length - 1) * 5;
    }

    final metrics = TransactionRowMetrics(
      amount: spanWidth(moneySpan),
      minimumTitle: scaler.scale(45),
      account: account == null ? 0 : measure(account, secondaryStyle) + 15,
      attachment: !_hasAttachment
          ? 0
          : 12 +
              (_attachmentText.isEmpty
                  ? 0
                  : 2 + measure(_attachmentText, smallStyle)),
      ledger: ledgerName?.isNotEmpty == true
          ? measure(ledgerName!, smallStyle) + 10
          : 0,
      converted: converted == null
          ? 0
          : measure(hidden ? '••••' : converted!, secondaryStyle),
      timestamp: time == null ? 0 : measure(time, timestampStyle),
      readOnly: readOnly && !statusLabels.contains(labels.readOnly)
          ? measure(labels.readOnly, smallStyle)
          : 0,
      statuses: statusLabels.map((s) => measure(s, smallStyle)).toList(),
      tags: [for (var i = 0; i <= 2; i++) tagsWidth(i)],
      moreLabelWidth: (count) => measure(labels.more(count), smallStyle),
    );
    final content = LayoutBuilder(builder: (context, constraints) {
      final plan = planTransactionRow(constraints.maxWidth, metrics,
          horizontalInset: horizontalInset);
      Widget tap(Widget child, VoidCallback? action, {String? tooltip}) {
        Widget result = InkWell(
            onTap: action,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: child));
        if (tooltip != null) result = Tooltip(message: tooltip, child: result);
        return result;
      }

      Widget tagStrip() {
        final count = math.min(plan.visibleTags, tags.length);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            BeeInlineLabel(
                key: ValueKey('transaction-tag-${tags[i].id}'),
                label: tags[i].label,
                maxWidth: 84,
                foreground: tags[i].color,
                background: tags[i].color.withValues(alpha: .12),
                hitPadding: const EdgeInsets.symmetric(vertical: 3),
                onTap: selected != null || onTagTap == null
                    ? null
                    : () => onTagTap!(tags[i])),
          ],
          if (tags.length > count) ...[
            if (count > 0) const SizedBox(width: 5),
            tap(
                Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: count == 0 ? 4 : 2),
                    decoration: count == 0
                        ? BoxDecoration(
                            color: colors.soft,
                            borderRadius: BorderRadius.circular(5))
                        : null,
                    child: Text('+${tags.length - count}', style: smallStyle)),
                selected != null ? null : () => _showTags(context),
                tooltip: labels.tags),
          ],
        ]);
      }

      Widget token(String id) {
        final width = plan.widths[id];
        return switch (id) {
          'title' => Text.rich(titleSpan(plan.wide),
              key: const ValueKey('transaction-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: plan.wide
                  ? primaryStyle.copyWith(fontSize: 13)
                  : primaryStyle),
          'amount' => Text.rich(moneySpan,
              key: const ValueKey('transaction-amount'),
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.ltr),
          'account' => SizedBox(
              width: width,
              child: tap(
                  Row(children: [
                    BeeLineIcon(
                        kind == BeeTransactionKind.transfer
                            ? 'ArrowLeftRight'
                            : 'Wallet',
                        size: 12,
                        color: theme.hintColor),
                    const SizedBox(width: 3),
                    Expanded(
                        child: Text(account!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: secondaryStyle))
                  ]),
                  () => _showFields(context),
                  tooltip: account)),
          'attachment' => tap(
              Row(mainAxisSize: MainAxisSize.min, children: [
                BeeLineIcon('Image', size: 12, color: theme.hintColor),
                if (_attachmentText.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Text(_attachmentText, style: smallStyle)
                ],
              ]),
              selected == null ? onAttachmentTap : null,
              tooltip: labels.attachments),
          'ledger' => SizedBox(
              width: width,
              child: BeeInlineLabel(
                  key: const ValueKey('transaction-ledger'),
                  label: ledgerName!,
                  foreground: theme.hintColor,
                  background: colors.soft,
                  maxWidth: width!,
                  hitPadding: const EdgeInsets.symmetric(vertical: 2),
                  onTap: () => _showFields(context))),
          'converted' => Text(hidden ? '••••' : converted!,
              key: const ValueKey('transaction-converted'),
              maxLines: 1,
              softWrap: false,
              style: secondaryStyle,
              textDirection: TextDirection.ltr),
          'time' => Text(time!,
              key: const ValueKey('transaction-timestamp'),
              maxLines: 1,
              softWrap: false,
              style: timestampStyle,
              textDirection: TextDirection.ltr),
          'readonly' => Text(labels.readOnly,
              key: const ValueKey('transaction-readonly'),
              maxLines: 1,
              softWrap: false,
              style: smallStyle),
          'tags' => tagStrip(),
          'more' => tap(
              Text(labels.more(plan.folded.length),
                  key: const ValueKey('transaction-more-fields'),
                  style: smallStyle.copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: theme.hintColor.withValues(alpha: .4))),
              () => _showFields(context),
              tooltip: labels.fieldsTitle),
          _ => Text(statusLabels[int.parse(id.substring(7))],
              key: ValueKey('transaction-$id'),
              maxLines: 1,
              softWrap: false,
              style: smallStyle),
        };
      }

      Widget line(List<String> ids, int index) {
        final hasTitle = ids.contains('title');
        final alignRight = !hasTitle
            ? ids.indexWhere(
                (id) => id == 'amount' || id == 'converted' || id == 'time')
            : -1;
        return Padding(
            key: ValueKey('transaction-line-${index + 1}'),
            // The overlaid category target is 20px. A fixed extra gap can
            // overflow a complete amount that otherwise fits beside it.
            padding: EdgeInsets.only(left: plan.wide && index == 0 ? 20 : 0),
            child: Row(children: [
              for (var i = 0; i < ids.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                if (i == alignRight) const Spacer(),
                if (ids[i] == 'title')
                  Expanded(child: token(ids[i]))
                else
                  token(ids[i]),
              ]
            ]));
      }

      Widget categoryTarget() {
        if (selected != null) {
          return SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                  value: selected,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: readOnly || onSelected == null
                      ? null
                      : (v) => onSelected!(v ?? false)));
        }
        return Semantics(
            container: true,
            button: true,
            label: categoryActionLabel ?? categoryLabel ?? title,
            excludeSemantics: true,
            onTap: onCategoryTap,
            onLongPress: readOnly ? null : onMenu,
            child: InkWell(
                onTap: onCategoryTap,
                onLongPress: readOnly ? null : onMenu,
                child: SizedBox(
                    width: plan.wide ? 20 : 36,
                    height: plan.wide ? 24 : 36,
                    child: Center(
                        child: plan.wide
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown, child: icon))
                            : icon))));
      }

      final lines = Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < plan.lines.length; i++)
          if (plan.lines[i].isNotEmpty) ...[
            if (i > 0) const SizedBox(height: 3),
            line(plan.lines[i], i),
          ],
      ]);
      return Padding(
          padding: EdgeInsets.symmetric(horizontal: plan.inset, vertical: 9),
          child: plan.wide
              ? Stack(children: [
                  lines,
                  PositionedDirectional(
                      start: 0, top: 0, child: categoryTarget())
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  SizedBox(width: 36, child: categoryTarget()),
                  const SizedBox(width: 10),
                  Expanded(child: lines)
                ]));
    });
    final row = Material(
        color: selected == true
            ? theme.colorScheme.primary.withValues(alpha: .1)
            : Colors.transparent,
        child: InkWell(
            onTap: selected != null
                ? (readOnly || onSelected == null
                    ? null
                    : () => onSelected!(!selected!))
                : onTap,
            onLongPress: readOnly || selected != null ? null : onMenu,
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 65),
                child: content)));
    if (onDeleteRequested == null || readOnly || selected != null) return row;
    return TransactionSwipeAction(
        key: ValueKey('swipe-${key ?? title}'),
        onDeleteRequested: onDeleteRequested!,
        deleteLabel: deleteLabel ??
            MaterialLocalizations.of(context).deleteButtonTooltip,
        child: row);
  }
}

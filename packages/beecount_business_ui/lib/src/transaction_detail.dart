import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'detail_components.dart';
import 'finance_components.dart';
import 'workflow_components.dart';

/// Read-only transaction content. No repositories, navigation, formatting,
/// exchange-rate requests or mutations are performed by this component.
class BeeTransactionDetail extends StatelessWidget {
  const BeeTransactionDetail({
    super.key,
    required this.title,
    required this.kindLabel,
    required this.kind,
    required this.amount,
    required this.currency,
    required this.icon,
    required this.items,
    required this.copyLabel,
    required this.editLabel,
    required this.receiptLabel,
    required this.attachmentLabel,
    this.incomeIsRed = true,
    this.hidden = false,
    this.busy = false,
    this.onCategory,
    this.snapshotLabel,
    this.snapshotAmount,
    this.snapshotRateLabel,
    this.snapshotRate,
    this.tags = const [],
    this.readOnlyTagIds = const {},
    this.tagsLabel,
    this.onTag,
    this.attachments = const [],
    this.attachmentCountLabel,
    this.onAttachment,
    this.attachmentPlaceholder,
    this.statusLabels = const [],
    this.note,
    this.noteLabel,
    this.onCopy,
    this.onEdit,
    this.onReceipt,
  });
  final String title,
      kindLabel,
      amount,
      currency,
      copyLabel,
      editLabel,
      receiptLabel,
      attachmentLabel;
  final BeeTransactionKind kind;
  final Widget icon;
  final Widget? attachmentPlaceholder;
  final List<BeeDetailItem> items;
  final bool incomeIsRed, hidden, busy;
  final String? snapshotLabel, snapshotAmount, snapshotRateLabel, snapshotRate;
  final String? tagsLabel, attachmentCountLabel, note, noteLabel;
  final List<BeeTagData> tags;
  final Set<String> readOnlyTagIds;
  final List<BeeAttachment> attachments;
  final List<String> statusLabels;
  final VoidCallback? onCategory, onCopy, onEdit, onReceipt;
  final ValueChanged<BeeTagData>? onTag;
  final ValueChanged<int>? onAttachment;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BeeSurface(
          child: Column(children: [
        InkWell(
            onTap: busy ? null : onCategory,
            borderRadius: BorderRadius.circular(19),
            child: Container(
                width: 53,
                height: 53,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: BeeCardTheme.of(context).soft,
                    borderRadius: BorderRadius.circular(19)),
                child: icon)),
        const SizedBox(height: 14),
        Text(title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, height: 1.45)),
        const SizedBox(height: 10),
        Center(
            child: BeeMoney(
                amount: amount,
                hidden: hidden,
                size: 36,
                color: beeTransactionColor(context, kind,
                    incomeIsRed: incomeIsRed))),
        const SizedBox(height: 6),
        Text('$kindLabel · $currency',
            style: TextStyle(fontSize: 12, color: muted)),
      ])),
      if (snapshotAmount != null) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (snapshotLabel != null)
                Text(snapshotLabel!,
                    style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 7),
              Text(hidden ? '••••' : snapshotAmount!,
                  key: const ValueKey('transaction-detail-snapshot'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              if (snapshotRate != null) ...[
                const SizedBox(height: 7),
                Text(
                    '${snapshotRateLabel ?? ''}${snapshotRateLabel == null ? '' : ' · '}${hidden ? '••••' : snapshotRate!}',
                    key: const ValueKey('transaction-detail-rate'),
                    style: TextStyle(fontSize: 12, height: 1.5, color: muted)),
              ],
            ])),
      ],
      const SizedBox(height: 12),
      BeeDetailList(items: items),
      if (note?.isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (noteLabel != null) ...[
                Text(noteLabel!, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8)
              ],
              SelectableText(note!,
                  style: const TextStyle(fontSize: 13, height: 1.6)),
            ])),
      ],
      if (tags.isNotEmpty) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (tagsLabel != null) ...[
                Text(tagsLabel!, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8)
              ],
              Wrap(spacing: 6, runSpacing: 0, children: [
                for (final tag in tags)
                  BeeTag(
                      tag: tag,
                      compact: true,
                      onTap: busy ||
                              onTag == null ||
                              readOnlyTagIds.contains(tag.id)
                          ? null
                          : () => onTag!(tag))
              ]),
            ])),
      ],
      if (attachmentPlaceholder != null) ...[
        const SizedBox(height: 12),
        BeeSurface(child: attachmentPlaceholder!)
      ],
      if (attachmentPlaceholder == null && attachments.isNotEmpty) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: BeeAttachments(
                items: attachments,
                title: attachmentLabel,
                countLabel: attachmentCountLabel,
                onOpen: (index) {
                  if (!busy) onAttachment?.call(index);
                })),
      ],
      if (statusLabels.isNotEmpty) ...[
        const SizedBox(height: 12),
        BeeSurface(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final label in statusLabels)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const BeeLineIcon('Info', size: 14),
              const SizedBox(width: 5),
              Flexible(child: Text(label, style: const TextStyle(fontSize: 12)))
            ])
        ])),
      ],
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, box) {
        final buttons = [
          BeeButton(
              key: const ValueKey('transaction-detail-copy'),
              label: copyLabel,
              kind: BeeButtonKind.secondary,
              icon: const BeeLineIcon('Copy', size: 18),
              onPressed: busy ? null : onCopy),
          BeeButton(
              key: const ValueKey('transaction-detail-edit'),
              label: editLabel,
              icon: const BeeLineIcon('PencilLine', size: 18),
              onPressed: busy ? null : onEdit),
        ];
        return box.maxWidth < 300 &&
                MediaQuery.textScalerOf(context).scale(1) > 1.2
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [buttons[0], const SizedBox(height: 8), buttons[1]])
            : Row(children: [
                Expanded(child: buttons[0]),
                const SizedBox(width: 8),
                Expanded(child: buttons[1])
              ]);
      }),
      const SizedBox(height: 8),
      BeeButton(
          key: const ValueKey('transaction-detail-receipt'),
          label: receiptLabel,
          icon: const BeeLineIcon('Share2', size: 18),
          kind: BeeButtonKind.quiet,
          onPressed: busy ? null : onReceipt),
    ]);
  }
}

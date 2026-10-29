import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../resources/tags/tag.dart';
import '../transactions/transaction_presentation.dart';

/// Conversation controls are controlled by the App's existing chat lifecycle.
class BeeConversationInput extends StatelessWidget {
  const BeeConversationInput(
      {super.key,
      required this.controller,
      required this.hint,
      required this.sendLabel,
      required this.stopLabel,
      required this.busy,
      required this.onSend,
      required this.onStop});
  final TextEditingController controller;
  final String hint, sendLabel, stopLabel;
  final bool busy;
  final VoidCallback onSend, onStop;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 8, 17, 12),
          child: BeeSurface(
              padding: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(18),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                    child: BeeField(
                        label: hint,
                        showLabel: false,
                        controller: controller,
                        hint: hint,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !busy,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend())),
                const SizedBox(width: 7),
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: busy
                            ? Theme.of(context).colorScheme.errorContainer
                            : Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(13)),
                    child: SizedBox.square(
                        dimension: 44,
                        child: BeeIconButton(
                            key: const ValueKey('ai-chat-send'),
                            label: busy ? stopLabel : sendLabel,
                            icon: Icon(
                                busy ? Icons.stop_circle_outlined : Icons.send,
                                size: 20,
                                color: busy
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer
                                    : Theme.of(context).colorScheme.onPrimary),
                            onPressed: busy ? onStop : onSend)))
              ]))));
}

class BeeConversationUserMessage extends StatelessWidget {
  const BeeConversationUserMessage(
      {super.key, required this.child, this.avatar});
  final Widget child;
  final Widget? avatar;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16, left: 45),
      child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
                child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: .12),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(4))),
                    child: child)),
            if (avatar != null) ...[const SizedBox(width: 8), avatar!]
          ]));
}

class BeeConversationNotice extends StatelessWidget {
  const BeeConversationNotice(
      {super.key,
      required this.label,
      required this.actionLabel,
      required this.onAction});
  final String label, actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(17, 8, 17, 8),
      child: BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        BeeStatus(label: label, tone: BeeTone.warning),
        const SizedBox(height: 8),
        BeeButton(
            label: actionLabel,
            kind: BeeButtonKind.secondary,
            onPressed: onAction)
      ])));
}

class BeeAssistantBillField {
  const BeeAssistantBillField(this.label, this.value);
  final String label, value;
}

/// Formatting, identities and mutation callbacks remain in the App adapter.
class BeeAssistantBillCard extends StatelessWidget {
  const BeeAssistantBillCard(
      {super.key,
      required this.title,
      required this.ledger,
      required this.fields,
      required this.undone,
      required this.undoLabel,
      required this.editLabel,
      required this.tagsLabel,
      this.tags = const [],
      this.onUndo,
      this.onEdit,
      this.onChangeLedger});
  final String title, ledger, undoLabel, editLabel, tagsLabel;
  final List<BeeAssistantBillField> fields;
  final List<String> tags;
  final bool undone;
  final VoidCallback? onUndo, onEdit, onChangeLedger;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(undone ? Icons.cancel : Icons.check_circle,
              color: undone
                  ? Theme.of(context).hintColor
                  : beeToneColor(context, BeeTone.success),
              size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 4),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: undone ? null : onChangeLedger,
                icon: const BeeLineIcon('BookOpen', size: 16),
                label: Text(ledger))),
        const Divider(height: 20),
        for (final field in fields)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                    width: 70,
                    child: Text(field.label,
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(field.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 13)))
              ])),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(tagsLabel,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final tag in tags)
              BeeTag(
                  tag: BeeTagData(
                      tag, tag, Theme.of(context).colorScheme.primary))
          ])
        ],
        if (!undone && (onUndo != null || onEdit != null)) ...[
          const SizedBox(height: 12),
          Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onUndo != null)
                  BeeButton(
                      label: undoLabel,
                      kind: BeeButtonKind.quiet,
                      onPressed: onUndo),
                if (onEdit != null)
                  BeeButton(
                      label: editLabel,
                      kind: BeeButtonKind.secondary,
                      onPressed: onEdit)
              ])
        ]
      ]));
}

class BeeToolRequestDetails extends StatelessWidget {
  const BeeToolRequestDetails(
      {super.key,
      required this.label,
      required this.description,
      required this.scope,
      required this.parametersLabel,
      required this.emptyLabel,
      required this.fields});
  final String label, description, scope, parametersLabel, emptyLabel;
  final List<BeeAssistantBillField> fields;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(description),
        const SizedBox(height: 12),
        Text(scope),
        const SizedBox(height: 12),
        Text(parametersLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (fields.isEmpty) Text(emptyLabel),
        for (final field in fields) ...[
          Text(field.label,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          SelectableText(field.value),
          const SizedBox(height: 6)
        ]
      ]);
}

class BeeConversationStart extends StatelessWidget {
  const BeeConversationStart(
      {super.key,
      required this.title,
      required this.description,
      required this.example,
      required this.brand,
      this.period,
      this.summary});
  final String title, description, example;
  final String? period;
  final Widget brand;
  final Widget? summary;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (period != null) ...[
                      Text(period!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor)),
                      const SizedBox(height: 16)
                    ],
                    brand,
                    const SizedBox(height: 14),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Theme.of(context).hintColor)),
                    if (summary != null) ...[
                      const SizedBox(height: 20),
                      summary!
                    ],
                    const SizedBox(height: 18),
                    Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BeeLineIcon('ArrowUpRight', size: 15),
                          const SizedBox(width: 5),
                          Flexible(
                              child: Text(example,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor)))
                        ])
                  ])))));
}

class BeeConversationLedgerBrief extends StatelessWidget {
  const BeeConversationLedgerBrief(
      {super.key,
      required this.amount,
      required this.count,
      required this.amountLabel,
      required this.countLabel});
  final Widget amount;
  final String count, amountLabel, countLabel;
  @override
  Widget build(BuildContext context) {
    Widget metric(Widget value, String label) => Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              child: value),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor))
        ]));
    return Container(
        width: 238,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
            border: Border.symmetric(
                horizontal:
                    BorderSide(color: BeeCardTheme.of(context).divider))),
        child: Row(children: [
          metric(amount, amountLabel),
          Container(
              width: 1, height: 35, color: BeeCardTheme.of(context).divider),
          metric(Text(count, textAlign: TextAlign.center), countLabel)
        ]));
  }
}

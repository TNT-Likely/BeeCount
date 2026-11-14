import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeeAIAdvancedNotice extends StatelessWidget {
  const BeeAIAdvancedNotice(
      {super.key, required this.text, required this.icon, this.contentKey});
  final String text;
  final Widget icon;
  final Key? contentKey;
  @override
  Widget build(BuildContext context) => Container(
      key: contentKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: BeeCardTheme.of(context).soft,
          borderRadius: BorderRadius.circular(22)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        icon,
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Theme.of(context).hintColor)))
      ]));
}

class BeeAIAdvancedMemoryCard extends StatelessWidget {
  const BeeAIAdvancedMemoryCard(
      {super.key,
      required this.content,
      required this.deleteLabel,
      required this.onDelete,
      this.deleteKey,
      this.busy = false});
  final String content, deleteLabel;
  final VoidCallback? onDelete;
  final Key? deleteKey;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(
            padding: EdgeInsets.only(top: 9),
            child: BeeLineIcon('Bookmark', size: 22)),
        const SizedBox(width: 12),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(content,
                    style: const TextStyle(fontSize: 14, height: 1.6)))),
        BeeIconButton(
            key: deleteKey,
            label: deleteLabel,
            icon: BeeLineIcon('Trash2',
                size: 20, color: beeToneColor(context, BeeTone.error)),
            onPressed: busy ? null : onDelete),
      ]));
}

class BeeAIAdvancedPermissionRow extends StatelessWidget {
  const BeeAIAdvancedPermissionRow(
      {super.key,
      required this.title,
      required this.description,
      required this.status,
      required this.ask,
      required this.onTap,
      this.busy = false,
      this.statusKey});
  final String title, description, status;
  final bool ask, busy;
  final VoidCallback? onTap;
  final Key? statusKey;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 5),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: Theme.of(context).hintColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)
                ])),
            const SizedBox(width: 10),
            if (busy)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Semantics(
                      button: true,
                      child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                              key: statusKey,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                  color: beeToneColor(
                                          context,
                                          ask
                                              ? BeeTone.warning
                                              : BeeTone.success)
                                      .withValues(alpha: .1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(status,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: beeToneColor(
                                          context,
                                          ask
                                              ? BeeTone.warning
                                              : BeeTone.success))))))),
          ])));
}

class BeeAIAdvancedPermissionSection extends StatelessWidget {
  const BeeAIAdvancedPermissionSection(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.rows});
  final String title, subtitle;
  final Widget icon;
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context).hintColor))
              ]))
        ]),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i]
        ],
      ]));
}

class BeeAIAdvancedPermissionOption extends StatelessWidget {
  const BeeAIAdvancedPermissionOption(
      {super.key,
      required this.label,
      required this.ask,
      required this.selected,
      required this.onTap});
  final String label;
  final bool ask, selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: selected
          ? beeToneColor(context, ask ? BeeTone.warning : BeeTone.success)
              .withValues(alpha: .1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                BeeLineIcon(ask ? 'CircleHelp' : 'CircleCheck', size: 21),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 14))),
                if (selected) const BeeLineIcon('Check', size: 20)
              ]))));
}

class BeeAIAdvancedDefaults extends StatelessWidget {
  const BeeAIAdvancedDefaults(
      {super.key,
      required this.summary,
      required this.restoreLabel,
      required this.onRestore,
      this.restoreKey,
      this.busy = false});
  final String summary, restoreLabel;
  final VoidCallback? onRestore;
  final Key? restoreKey;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(summary,
            style: TextStyle(
                fontSize: 12, height: 1.5, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        BeeButton(
            key: restoreKey,
            label: restoreLabel,
            icon: const BeeLineIcon('RotateCcw', size: 18),
            kind: BeeButtonKind.secondary,
            loading: busy,
            onPressed: busy ? null : onRestore)
      ]));
}

class BeeAIAdvancedActivityCard extends StatelessWidget {
  const BeeAIAdvancedActivityCard(
      {super.key,
      required this.message,
      required this.status,
      required this.tone,
      required this.toolsLabel,
      required this.tools,
      this.error});
  final String message, status, toolsLabel;
  final String? error;
  final BeeTone tone;
  final List<Widget> tools;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(message,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, height: 1.6)),
        const SizedBox(height: 10),
        Wrap(children: [_Badge(label: status, tone: tone)]),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Theme.of(context).hintColor))
        ],
        if (tools.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(toolsLabel,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: tools)
        ],
      ]));
}

class BeeAIAdvancedToolBadge extends StatelessWidget {
  const BeeAIAdvancedToolBadge(
      {super.key,
      required this.label,
      required this.status,
      required this.tone});
  final String label, status;
  final BeeTone tone;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
          color: beeToneColor(context, tone).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10)),
      child: Wrap(spacing: 3, children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: beeToneColor(context, tone))),
        Text('·',
            style: TextStyle(fontSize: 11, color: beeToneColor(context, tone))),
        Text(status,
            style: TextStyle(fontSize: 11, color: beeToneColor(context, tone)))
      ]));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});
  final String label;
  final BeeTone tone;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: beeToneColor(context, tone).withValues(alpha: .1),
          borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: beeToneColor(context, tone))));
}

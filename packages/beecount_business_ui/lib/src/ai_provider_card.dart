import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeeAIProviderCapability {
  const BeeAIProviderCapability(this.label, this.icon, {required this.enabled});
  final String label;
  final Widget icon;
  final bool enabled;
}

/// Display-only provider metadata. Credentials and model requests stay in the host.
class BeeAIProviderCard extends StatelessWidget {
  const BeeAIProviderCard(
      {super.key,
      required this.name,
      required this.capabilities,
      required this.editHint,
      required this.onEdit,
      this.builtInLabel,
      this.warning,
      this.onDelete,
      this.deleteLabel});
  final String name, editHint;
  final String? builtInLabel, warning, deleteLabel;
  final List<BeeAIProviderCapability> capabilities;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => BeeSurface(
      child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(13),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              BeeLineIcon(builtInLabel != null ? 'BadgeCheck' : 'Cloud'),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              if (builtInLabel != null)
                BeeLabel(label: builtInLabel!, accent: true),
              if (onDelete != null)
                BeeIconButton(
                    label: deleteLabel!,
                    icon: const BeeLineIcon('Trash2'),
                    onPressed: onDelete),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in capabilities)
                Opacity(
                    opacity: c.enabled ? 1 : .4,
                    child: BeeLabel(
                        label: c.label, leading: c.icon, accent: c.enabled))
            ]),
            if (warning != null) ...[
              const SizedBox(height: 12),
              BeeStatus(label: warning!, tone: BeeTone.warning)
            ],
            if (onEdit != null) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(
                    child: Text(editHint,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor))),
                const SizedBox(width: 6),
                const BeeLineIcon('ChevronRight', size: 16),
              ]),
            ]
          ])));
}

/// Field presentation shared by key and model tests; the host supplies callbacks/results.
class BeeAIModelTestField extends StatelessWidget {
  const BeeAIModelTestField(
      {super.key,
      required this.title,
      required this.field,
      required this.testLabel,
      this.onTest,
      this.busy = false,
      this.tone = BeeTone.neutral,
      this.detail});
  final String title, testLabel;
  final Widget field;
  final VoidCallback? onTest;
  final bool busy;
  final BeeTone tone;
  final String? detail;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500))),
          Flexible(
              child: TextButton.icon(
                  style: TextButton.styleFrom(
                      foregroundColor: beeToneColor(context, tone)),
                  onPressed: busy ? null : onTest,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : BeeLineIcon(
                          tone == BeeTone.success
                              ? 'CircleCheck'
                              : tone == BeeTone.error
                                  ? 'CircleAlert'
                                  : 'Play',
                          size: 16,
                          color: beeToneColor(context, tone)),
                  label: Text(testLabel, style: const TextStyle(fontSize: 12))))
        ]),
        const SizedBox(height: 4),
        field,
        if (detail != null) ...[
          const SizedBox(height: 8),
          BeeStatus(label: detail!, tone: tone)
        ],
      ]);
}

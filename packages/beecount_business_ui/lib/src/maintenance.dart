import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeMaintenanceCard extends StatelessWidget {
  const BeeMaintenanceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) =>
      BeeSurface(padding: padding, child: child);
}

class BeeMaintenanceInfo extends StatelessWidget {
  const BeeMaintenanceInfo(
      {super.key,
      required this.title,
      required this.message,
      required this.icon});
  final String title, message;
  final Widget icon;
  @override
  Widget build(BuildContext context) => BeeMaintenanceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, height: 1.5)))
        ]),
        const SizedBox(height: 10),
        Text(message,
            style: TextStyle(
                fontSize: 12, height: 1.6, color: Theme.of(context).hintColor))
      ]));
}

class BeeMaintenanceAction extends StatelessWidget {
  const BeeMaintenanceAction(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.icon,
      this.onTap,
      this.busy = false});
  final String title, subtitle, value;
  final Widget icon;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Theme.of(context).hintColor))
                    ])),
                const SizedBox(width: 10),
                if (busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)))
              ]))));
}

class BeeMaintenanceFilterChoice {
  const BeeMaintenanceFilterChoice(
      {required this.label,
      required this.selected,
      required this.onSelected,
      this.key});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Key? key;
}

class BeeMaintenanceLogFilters extends StatelessWidget {
  const BeeMaintenanceLogFilters(
      {super.key,
      required this.levelLabel,
      required this.sourceLabel,
      required this.levels,
      required this.sources});
  final String levelLabel, sourceLabel;
  final List<BeeMaintenanceFilterChoice> levels, sources;
  @override
  Widget build(BuildContext context) => BeeMaintenanceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(levelLabel,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final item in levels)
            FilterChip(
                key: item.key,
                label: Text(item.label),
                selected: item.selected,
                onSelected: item.onSelected)
        ]),
        const SizedBox(height: 14),
        Text(sourceLabel,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final item in sources)
            FilterChip(
                key: item.key,
                label: Text(item.label),
                selected: item.selected,
                onSelected: item.onSelected)
        ]),
      ]));
}

class BeeMaintenanceLogCard extends StatelessWidget {
  const BeeMaintenanceLogCard(
      {super.key,
      required this.level,
      required this.source,
      required this.time,
      required this.tag,
      required this.message,
      required this.tone,
      required this.onDetails,
      required this.onCopy,
      this.error,
      this.levelColor});
  final String level, source, time, tag, message;
  final String? error;
  final BeeTone tone;
  final Color? levelColor;
  final VoidCallback onDetails, onCopy;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
          onTap: onDetails,
          onLongPress: onCopy,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                        spacing: 7,
                        runSpacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MaintenanceBadge(
                              label: level,
                              color: levelColor ?? beeToneColor(context, tone)),
                          _MaintenanceBadge(
                              label: source,
                              color: Theme.of(context).hintColor),
                          Text(time,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor))
                        ]),
                    const SizedBox(height: 10),
                    Text('[$tag]',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).hintColor)),
                    const SizedBox(height: 5),
                    Text(message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.6)),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text('Error: $error',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              color: beeToneColor(context, BeeTone.error)))
                    ],
                  ]))));
}

class _MaintenanceBadge extends StatelessWidget {
  const _MaintenanceBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)));
}

class BeeMaintenanceDetailRow extends StatelessWidget {
  const BeeMaintenanceDetailRow(
      {super.key, required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 60,
            child: Text('$label:',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(
            child:
                Text(value, style: const TextStyle(fontSize: 12, height: 1.5)))
      ]));
}

class BeeMaintenanceWidgetCard extends StatelessWidget {
  const BeeMaintenanceWidgetCard(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.sizeLabel,
      required this.previewSize,
      required this.preview});
  final String title, subtitle, sizeLabel;
  final Size previewSize;
  final Widget preview;
  @override
  Widget build(BuildContext context) => BeeMaintenanceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(subtitle,
            style: TextStyle(
                fontSize: 12, height: 1.5, color: Theme.of(context).hintColor)),
        const SizedBox(height: 9),
        Align(
            alignment: Alignment.centerLeft,
            child: _MaintenanceBadge(
                label:
                    '$sizeLabel · ${previewSize.width.toInt()}×${previewSize.height.toInt()}',
                color: Theme.of(context).hintColor)),
        const SizedBox(height: 14),
        Center(child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth.clamp(0.0, 400.0);
          return SizedBox(
              width: width,
              height: width * previewSize.height / previewSize.width,
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                          width: previewSize.width,
                          height: previewSize.height,
                          child: MediaQuery(
                              data: MediaQuery.of(context)
                                  .copyWith(textScaler: TextScaler.noScaling),
                              child: preview)))));
        })),
      ]));
}

class BeeMaintenanceGuide extends StatelessWidget {
  const BeeMaintenanceGuide(
      {super.key, required this.title, required this.steps});
  final String title;
  final List<String> steps;
  @override
  Widget build(BuildContext context) => BeeMaintenanceCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        for (var i = 0; i < steps.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: BeeCardTheme.of(context).soft,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(steps[i],
                        style: const TextStyle(fontSize: 13, height: 1.6)))
              ]))
      ]));
}

class BeeMaintenanceSelectionRow extends StatelessWidget {
  const BeeMaintenanceSelectionRow(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.selected,
      required this.onChanged,
      required this.deleteLabel,
      required this.onDelete});
  final String title, subtitle, deleteLabel;
  final bool selected;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
      value: selected,
      onChanged: onChanged,
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12, height: 1.5, color: Theme.of(context).hintColor)),
      secondary: BeeIconButton(
          label: deleteLabel,
          icon: const BeeLineIcon('Trash2', size: 19),
          onPressed: onDelete),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true);
}

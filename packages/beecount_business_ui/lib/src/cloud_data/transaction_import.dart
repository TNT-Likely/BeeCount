import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Presentation only. The host owns file access, parsers, mappings and writes.
class BeeImportOption<T> {
  const BeeImportOption(this.value, this.label);
  final T value;
  final String label;
}

class BeeImportSourcePicker<T> extends StatelessWidget {
  const BeeImportSourcePicker(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  final String label;
  final T value;
  final List<BeeImportOption<T>> options;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option.label),
              selected: value == option.value,
              onSelected:
                  onChanged == null ? null : (_) => onChanged!(option.value),
              showCheckmark: false,
              side: BorderSide.none,
              backgroundColor: BeeCardTheme.of(context).soft,
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
        ]),
      ]);
}

class BeeImportSteps extends StatelessWidget {
  const BeeImportSteps(
      {super.key, required this.labels, required this.current});
  final List<String> labels;
  final int current;
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
          labels.length,
          (index) => Semantics(
                selected: index == current,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: index == current
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: .2)
                          : BeeCardTheme.of(context).soft,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text('${index + 1}  ${labels[index]}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: index == current
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: index == current
                              ? null
                              : Theme.of(context).hintColor)),
                ),
              )));
}

class BeeImportSection extends StatelessWidget {
  const BeeImportSection(
      {super.key, this.title, this.description, required this.child});
  final String? title, description;
  final Widget child;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (title != null)
          Text(title!,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        if (description != null) ...[
          if (title != null) const SizedBox(height: 8),
          Text(description!,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).hintColor)),
        ],
        if (title != null || description != null) const SizedBox(height: 14),
        child,
      ]));
}

class BeeImportFileChoice extends StatelessWidget {
  const BeeImportFileChoice(
      {super.key,
      required this.fileName,
      required this.chooseLabel,
      required this.onChoose,
      this.description});
  final String fileName, chooseLabel;
  final String? description;
  final VoidCallback? onChoose;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(13)),
            child: Row(children: [
              const BeeLineIcon('FileSpreadsheet', size: 28),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(fileName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    if (description != null) ...[
                      const SizedBox(height: 5),
                      Text(description!,
                          style: TextStyle(
                              fontSize: 11, color: Theme.of(context).hintColor))
                    ],
                  ])),
            ])),
        const SizedBox(height: 14),
        BeeButton(
            label: chooseLabel,
            icon: const BeeLineIcon('FolderOpen', size: 18),
            onPressed: onChoose),
      ]);
}

class BeeImportMappingField<T> extends StatelessWidget {
  const BeeImportMappingField(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged,
      this.hint});
  final String label;
  final String? hint;
  final T? value;
  final List<BeeImportOption<T>> options;
  final ValueChanged<T?>? onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 6),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(13)),
            child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: hint == null ? null : Text(hint!),
              borderRadius: BorderRadius.circular(13),
              items: options
                  .map((option) => DropdownMenuItem<T>(
                      value: option.value,
                      child: Text(option.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onChanged,
            ))),
      ]);
}

/// Fixed cells allow horizontal scrolling without unbounded flex layouts.
class BeeImportPreviewTable extends StatelessWidget {
  const BeeImportPreviewTable(
      {super.key, required this.rows, this.hasHeader = true});
  final List<List<String>> rows;
  final bool hasHeader;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final cards = BeeCardTheme.of(context);
    final columns = rows.fold<int>(
        0, (count, row) => row.length > count ? row.length : count);
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                    rows.length,
                    (r) => Container(
                          decoration: BoxDecoration(
                              color: r == 0 && hasHeader
                                  ? cards.soft
                                  : cards.surface,
                              border: Border(
                                  bottom: BorderSide(
                                      color: cards.divider, width: .6))),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 12),
                          child: Row(
                              children: List.generate(
                                  columns,
                                  (c) => SizedBox(
                                      width: 140,
                                      child: Text(
                                          c < rows[r].length ? rows[r][c] : '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: r == 0 && hasHeader
                                                  ? FontWeight.w600
                                                  : FontWeight.w400))))),
                        )))));
  }
}

class BeeImportStatusPanel extends StatelessWidget {
  const BeeImportStatusPanel(
      {super.key,
      required this.title,
      required this.message,
      this.progress,
      this.showProgress = true,
      this.actions = const []});
  final String title, message;
  final double? progress;
  final bool showProgress;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: BeeLineIcon('FileInput', size: 28)),
            const SizedBox(height: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(message,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Theme.of(context).hintColor)),
            if (showProgress) ...[
              const SizedBox(height: 18),
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: progress))
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions)
            ],
          ]);
}

class BeeImportAccountCurrencyReview extends StatelessWidget {
  const BeeImportAccountCurrencyReview(
      {super.key,
      required this.description,
      required this.accounts,
      this.mappings = const []});
  final String description;
  final List<String> accounts, mappings;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Theme.of(context).hintColor)),
            const SizedBox(height: 14),
            for (final account in accounts)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: BeeCardTheme.of(context).soft,
                          borderRadius: BorderRadius.circular(13)),
                      child:
                          Text(account, style: const TextStyle(fontSize: 13)))),
            if (mappings.isNotEmpty) ...[
              const Divider(),
              for (final mapping in mappings)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(mapping,
                        style: const TextStyle(fontSize: 12, height: 1.55)))
            ],
          ]);
}

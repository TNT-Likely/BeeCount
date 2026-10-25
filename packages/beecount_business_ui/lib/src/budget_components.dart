import 'package:beecount_ui/card_frame.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

enum BeeBudgetTone { normal, warning, danger, exceeded }

Color _budgetColor(BuildContext context, BeeBudgetTone tone) => switch (tone) {
      BeeBudgetTone.normal => const Color(0xff25856d),
      BeeBudgetTone.warning => const Color(0xffd79b27),
      _ => Theme.of(context).colorScheme.error,
    };

class BeeBudgetProgress extends StatelessWidget {
  const BeeBudgetProgress(
      {super.key,
      required this.progress,
      required this.tone,
      required this.label,
      this.height = 8,
      this.accentForNormal = false});
  final double progress, height;
  final bool accentForNormal;
  final BeeBudgetTone tone;
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = accentForNormal && tone == BeeBudgetTone.normal
        ? Theme.of(context).colorScheme.primary
        : _budgetColor(context, tone);
    return Semantics(
        label: label,
        child: ExcludeSemantics(
            child: LinearProgressIndicator(
                value: progress.isFinite ? progress.clamp(0, 1) : 0,
                minHeight: height,
                color: color,
                backgroundColor: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(height / 2))));
  }
}

/// Prepared monetary strings and original usage status come from the App.
class BeeBudgetOverview extends StatelessWidget {
  const BeeBudgetOverview(
      {super.key,
      required this.title,
      required this.amount,
      required this.totalLabel,
      required this.usedLabel,
      required this.used,
      required this.remainingLabel,
      required this.remaining,
      required this.daysLabel,
      required this.dailyLabel,
      required this.progress,
      required this.progressLabel,
      required this.tone,
      required this.editLabel,
      this.onEdit,
      this.negativeRemaining = false});
  final String title,
      amount,
      totalLabel,
      usedLabel,
      used,
      remainingLabel,
      remaining,
      daysLabel,
      dailyLabel,
      editLabel,
      progressLabel;
  final double progress;
  final bool negativeRemaining;
  final BeeBudgetTone tone;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), statusColor = _budgetColor(context, tone);
    Widget money(String value, double size,
            {Color? color, Alignment alignment = Alignment.centerLeft}) =>
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: Text(value,
                style: TextStyle(
                    fontSize: size,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()])));
    Widget caption(String text) => Text(text,
        style: TextStyle(fontSize: 11, height: 1.5, color: theme.hintColor));
    return BeeCardFrame(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600))),
            if (onEdit != null)
              TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(editLabel))
          ])),
      const SizedBox(height: 14),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            flex: 6,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  caption(usedLabel),
                  const SizedBox(height: 8),
                  money(used, 31)
                ])),
        const SizedBox(width: 17),
        Expanded(
            flex: 4,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              caption(remainingLabel),
              const SizedBox(height: 8),
              money(remaining, 15,
                  alignment: Alignment.centerRight,
                  color: negativeRemaining ? theme.colorScheme.error : null)
            ]))
      ]),
      const SizedBox(height: 22),
      BeeBudgetProgress(
          progress: progress,
          tone: tone,
          height: 6,
          label: '$usedLabel $progressLabel',
          accentForNormal: true),
      const SizedBox(height: 11),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 7,
          children: [
            Text('$usedLabel $progressLabel',
                style: TextStyle(fontSize: 10, color: statusColor)),
            caption('$totalLabel $amount')
          ]),
      const SizedBox(height: 16),
      Divider(height: 1, color: BeeCardTheme.of(context).divider),
      const SizedBox(height: 14),
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 16,
          runSpacing: 7,
          children: [
            caption(daysLabel),
            Text(dailyLabel, style: const TextStyle(fontSize: 11, height: 1.5))
          ])
    ]));
  }
}

class BeeBudgetCategoryRow extends StatelessWidget {
  const BeeBudgetCategoryRow(
      {super.key,
      required this.name,
      required this.amounts,
      required this.percent,
      required this.progress,
      required this.tone,
      required this.icon,
      this.onTap});
  final String name, amounts, percent;
  final double progress;
  final BeeBudgetTone tone;
  final Widget icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      button: onTap != null,
      label: '$name · $percent · $amounts',
      onTap: onTap,
      child: ExcludeSemantics(
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(13),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 80),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 2),
                      child: Row(children: [
                        Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: BeeCardTheme.of(context).soft,
                                borderRadius: BorderRadius.circular(12)),
                            child: icon),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Row(children: [
                                Expanded(
                                    child: Text(name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w500))),
                                const SizedBox(width: 8),
                                Text(percent,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color: _budgetColor(context, tone)))
                              ]),
                              const SizedBox(height: 8),
                              BeeBudgetProgress(
                                  progress: progress,
                                  tone: tone,
                                  label: percent,
                                  height: 6),
                              const SizedBox(height: 5),
                              Text(amounts,
                                  style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: Theme.of(context).hintColor))
                            ]))
                      ]))))));
}

/// The App supplies the existing identity, permitted type choices and drafts.
class BeeBudgetEditorForm extends StatelessWidget {
  const BeeBudgetEditorForm(
      {super.key,
      required this.amountController,
      required this.type,
      required this.totalLabel,
      required this.categoryTypeLabel,
      required this.categoryLabel,
      required this.categoryHint,
      required this.amountLabel,
      required this.amountHint,
      required this.symbol,
      this.categoryName,
      this.categoryIcon,
      this.amountError,
      this.onType,
      this.onCategory,
      this.onAmountChanged,
      this.editing = false,
      this.totalUnavailable = false,
      this.enabled = true});
  final TextEditingController amountController;
  final String type,
      totalLabel,
      categoryTypeLabel,
      categoryLabel,
      categoryHint,
      amountLabel,
      amountHint,
      symbol;
  final String? categoryName, amountError;
  final Widget? categoryIcon;
  final bool editing, totalUnavailable, enabled;
  final ValueChanged<String>? onType, onAmountChanged;
  final VoidCallback? onCategory;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!editing) ...[
          BeeSurface(
              child: BeeSegmented<String>(items: [
            BeeSegment('total', totalLabel, enabled: !totalUnavailable),
            BeeSegment('category', categoryTypeLabel)
          ], value: type, onChanged: enabled ? onType : null)),
          const SizedBox(height: 12)
        ],
        if (type == 'category') ...[
          BeeSurface(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              child: BeeMenuRow(
                  title: categoryLabel,
                  subtitle: categoryName ?? categoryHint,
                  leading:
                      categoryIcon ?? const BeeLineIcon('Shapes', size: 20),
                  onTap: enabled && !editing ? onCategory : null)),
          const SizedBox(height: 12)
        ],
        BeeSurface(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(amountLabel,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Theme.of(context).hintColor)),
              const SizedBox(height: 12),
              TextField(
                  controller: amountController,
                  enabled: enabled,
                  onChanged: onAmountChanged,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [
                    BeeDecimalInputFormatter(maxFractionDigits: 2)
                  ],
                  style: const TextStyle(
                      fontSize: 24, height: 1.4, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                      prefixText: '$symbol ',
                      hintText: amountHint,
                      constraints: const BoxConstraints(minHeight: 64),
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12))),
              if (amountError != null) ...[
                const SizedBox(height: 8),
                Semantics(
                    liveRegion: true,
                    child: Text(amountError!,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Theme.of(context).colorScheme.error)))
              ]
            ]))
      ]);
}

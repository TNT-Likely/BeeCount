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
      this.height = 8});
  final double progress, height;
  final BeeBudgetTone tone;
  final String label;
  @override
  Widget build(BuildContext context) {
    final color = _budgetColor(context, tone);
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
    final theme = Theme.of(context), color = _budgetColor(context, tone);
    Widget money(String value, double size, {Color? color}) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(value,
            style: TextStyle(
                fontSize: size,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: color)));
    return BeeSurface(
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
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  onPressed: onEdit,
                  child: Text(editLabel))
          ])),
      const SizedBox(height: 12),
      Row(children: [
        Semantics(
            image: true,
            label: '$usedLabel $progressLabel',
            child: ExcludeSemantics(
                child: SizedBox(
                    width: 128,
                    height: 128,
                    child: Stack(alignment: Alignment.center, children: [
                      Positioned.fill(
                          child: CircularProgressIndicator(
                              value:
                                  progress.isFinite ? progress.clamp(0, 1) : 0,
                              strokeWidth: 10,
                              color: color,
                              backgroundColor: color.withValues(alpha: .14))),
                      Padding(
                          padding: const EdgeInsets.all(18),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(usedLabel,
                                style: TextStyle(
                                    fontSize: 11,
                                    height: 1.4,
                                    color: theme.hintColor)),
                            const SizedBox(height: 4),
                            money(progressLabel, 24)
                          ]))
                    ])))),
        const SizedBox(width: 18),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(remainingLabel,
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: theme.hintColor)),
              const SizedBox(height: 5),
              money(remaining, 24,
                  color: negativeRemaining ? theme.colorScheme.error : null),
              const SizedBox(height: 8),
              Text('$totalLabel $amount',
                  style: TextStyle(
                      fontSize: 11, height: 1.5, color: theme.hintColor))
            ]))
      ]),
      const SizedBox(height: 18),
      const Divider(height: 1),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Text(usedLabel,
                  style: TextStyle(
                      fontSize: 12, height: 1.4, color: theme.hintColor)),
              const SizedBox(height: 5),
              money(used, 20)
            ])),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(daysLabel,
              style:
                  TextStyle(fontSize: 12, height: 1.4, color: theme.hintColor),
              textAlign: TextAlign.end),
          const SizedBox(height: 5),
          Text(dailyLabel,
              style: const TextStyle(
                  fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end)
        ]))
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

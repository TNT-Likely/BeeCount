import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'brand_mark.dart';

/// Controlled first-run layout. The App owns language, initialization, imports
/// and navigation; this widget only arranges the current step and its controls.
class BeeOnboardingStep extends StatelessWidget {
  const BeeOnboardingStep({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.description,
    required this.illustration,
    required this.options,
    required this.next,
    required this.restore,
    this.brandTitle = 'BeeCount',
    this.brandSubtitle = 'BeeCount',
    this.onStep,
    this.busy = false,
  });
  final int step, total;
  final String title, description, brandTitle, brandSubtitle;
  final Widget illustration, options, next, restore;
  final ValueChanged<int>? onStep;
  final bool busy;

  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: LayoutBuilder(builder: (context, bounds) {
            final header = Padding(
                padding: const EdgeInsets.fromLTRB(21, 7, 21, 0),
                child: Column(children: [
                  SizedBox(
                      height: 54,
                      child: Stack(alignment: Alignment.center, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          BeeBrandMark(
                              size: 38,
                              corner: 13,
                              background: BeeCardTheme.of(context).surface,
                              mark: illustration),
                          const SizedBox(width: 10),
                          Flexible(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(brandTitle,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text(brandSubtitle,
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: .4,
                                        color: Theme.of(context).hintColor)),
                              ])),
                        ]),
                        Positioned(
                            right: 0,
                            child: Text(
                                '${(step + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor))),
                      ])),
                  const SizedBox(height: 5),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 228),
                      child: Row(
                          children: List.generate(
                              total,
                              (i) => Expanded(
                                  child: Padding(
                                      padding: EdgeInsets.only(
                                          right: i == total - 1 ? 0 : 6),
                                      child: Semantics(
                                          selected: i == step,
                                          label: '${i + 1} / $total',
                                          child: InkWell(
                                              onTap: busy || onStep == null
                                                  ? null
                                                  : () => onStep!(i),
                                              child: SizedBox(
                                                  height: 24,
                                                  child: Center(
                                                      child: Container(
                                                          height: 3,
                                                          decoration: BoxDecoration(
                                                              color: i <= step
                                                                  ? Theme.of(context)
                                                                      .colorScheme
                                                                      .primary
                                                                  : BeeCardTheme.of(context)
                                                                      .divider,
                                                              borderRadius: BorderRadius.circular(8)))))))))))),
                ]));
            final body = Padding(
                padding: const EdgeInsets.symmetric(horizontal: 21),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 22, bottom: 25),
                          child: Column(children: [
                            Text(title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 25,
                                    height: 1.45,
                                    letterSpacing: -.7,
                                    fontWeight: FontWeight.w600)),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 9),
                              ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 300),
                                  child: Text(description,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          height: 1.85,
                                          color: Theme.of(context).hintColor))),
                            ],
                          ])),
                      IgnorePointer(ignoring: busy, child: options),
                    ]));
            final footer = Padding(
                padding: const EdgeInsets.fromLTRB(21, 25, 21, 16),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [next, restore]));
            return Column(
                mainAxisSize: bounds.hasBoundedHeight
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  header,
                  if (bounds.hasBoundedHeight)
                    Expanded(child: SingleChildScrollView(child: body))
                  else
                    body,
                  footer,
                ]);
          })));
}

/// Language and currency options share selection semantics and wrap long text.
class BeeOnboardingChoice extends StatelessWidget {
  const BeeOnboardingChoice({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.minHeight = 61,
    this.showUnselectedCheck = true,
    this.compact = false,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected, showUnselectedCheck, compact;
  final double minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 11 : 14,
                          vertical: compact ? 10 : 11),
                      child: Row(children: [
                        if (leading != null) ...[
                          SizedBox(width: 30, child: leading),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  style: TextStyle(
                                      fontSize: compact ? 12 : 14,
                                      fontWeight: FontWeight.w500)),
                              if (subtitle != null) ...[
                                const SizedBox(height: 3),
                                Text(subtitle!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).hintColor)),
                              ],
                            ])),
                        const SizedBox(width: 12),
                        Opacity(
                            opacity: selected || showUnselectedCheck ? 1 : 0,
                            child: Container(
                                width: compact ? 15 : 19,
                                height: compact ? 15 : 19,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    border: Border.all(
                                        color: selected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : BeeCardTheme.of(context)
                                                .divider)),
                                child: selected
                                    ? Center(
                                        child: BeeLineIcon('Check',
                                            size: compact ? 10 : 12,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimary))
                                    : null)),
                      ]))))));
}

/// Classification-mode options preserve the App's explanatory copy. The whole
/// card selects a draft; the preview never initializes a repository.
class BeeOnboardingModeCard extends StatelessWidget {
  const BeeOnboardingModeCard(
      {super.key,
      required this.title,
      required this.description,
      required this.icon,
      required this.preview,
      required this.selected,
      required this.onTap});
  final String title, description;
  final Widget icon, preview;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: BeeCardTheme.of(context).surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      ExcludeSemantics(
                          child: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: selected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: .12)
                                      : BeeCardTheme.of(context).soft,
                                  borderRadius: BorderRadius.circular(11)),
                              child: icon)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(description,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context).hintColor)),
                          ])),
                      const SizedBox(width: 10),
                      ExcludeSemantics(
                          child: Container(
                              width: 19,
                              height: 19,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  border: Border.all(
                                      color: selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : BeeCardTheme.of(context).divider)),
                              child: selected
                                  ? Center(
                                      child: BeeLineIcon('Check',
                                          size: 12,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary))
                                  : null)),
                    ]),
                    const SizedBox(height: 8),
                    Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: preview),
                  ])),
        ),
      ));
}

/// File picking and parsing stay in the App. Choosing a file is only a draft;
/// the separate confirmation action owns all import writes.
class BeeBackupFileCard extends StatelessWidget {
  const BeeBackupFileCard(
      {super.key,
      required this.title,
      required this.description,
      required this.icon,
      required this.actionLabel,
      required this.onChoose,
      this.fileName});
  final String title, description, actionLabel;
  final String? fileName;
  final Widget icon;
  final VoidCallback? onChoose;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ExcludeSemantics(
              child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(11)),
                  child: icon)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(description,
                    style: TextStyle(
                        fontSize: 11, color: Theme.of(context).hintColor)),
              ])),
          if (fileName != null) const BeeLineIcon('Check', size: 18),
        ]),
        const SizedBox(height: 12),
        BeeButton(
            label: actionLabel,
            kind: BeeButtonKind.secondary,
            compact: true,
            onPressed: onChoose),
        if (fileName != null) ...[
          const SizedBox(height: 10),
          Text(fileName!,
              style:
                  TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        ],
      ]));
}

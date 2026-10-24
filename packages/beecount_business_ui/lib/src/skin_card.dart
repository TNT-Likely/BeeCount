import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Preview rendering and stored skin identities are supplied by the host.
class BeeSkinChoice {
  const BeeSkinChoice(
      {required this.id,
      required this.name,
      required this.preview,
      this.animated = false,
      this.fixedPalette = false,
      this.cornerBadge});
  final String id, name;
  final Widget preview;
  final bool animated, fixedPalette;
  final String? cornerBadge;
}

class BeeSkinCard extends StatelessWidget {
  const BeeSkinCard(
      {super.key,
      required this.item,
      required this.selected,
      required this.animatedLabel,
      required this.fixedLabel,
      required this.onTap});
  final BeeSkinChoice item;
  final bool selected;
  final String animatedLabel, fixedLabel;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        cards = BeeCardTheme.of(context);
    Widget badge(String text, {bool play = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
            color: cards.soft, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (play) ...[
            const Icon(Icons.play_arrow_rounded, size: 11),
            const SizedBox(width: 2)
          ],
          Flexible(
              child: Text(text,
                  style:
                      TextStyle(fontSize: 10, color: scheme.onSurfaceVariant))),
        ]));
    final label = [
      item.name,
      if (item.animated) animatedLabel,
      if (item.fixedPalette) fixedLabel,
      if (item.cornerBadge != null) item.cornerBadge!
    ].join(' · ');
    return Semantics(
        label: label,
        selected: selected,
        button: true,
        onTap: onTap,
        enabled: onTap != null,
        child: ExcludeSemantics(
            child: Opacity(
                opacity: onTap == null ? .45 : 1,
                child: Material(
                    color: cards.surface,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                            padding: const EdgeInsets.all(8),
                            foregroundDecoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: selected
                                        ? scheme.primary
                                        : cards.divider,
                                    width: selected ? 2 : 1)),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                          height: 110,
                                          child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                item.preview,
                                                if (item.cornerBadge != null)
                                                  Positioned(
                                                      left: 6,
                                                      top: 6,
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal: 7,
                                                                  vertical: 3),
                                                          decoration: BoxDecoration(
                                                              color: const Color(
                                                                  0xfff8c91c),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      9)),
                                                          child: Text(
                                                              item.cornerBadge!,
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color:
                                                                      Color(0xff6e5104))))),
                                                if (selected)
                                                  Positioned(
                                                      right: 6,
                                                      top: 6,
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(3),
                                                          decoration: BoxDecoration(
                                                              color: scheme
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle),
                                                          child: Icon(
                                                              Icons.check,
                                                              size: 14,
                                                              color: scheme
                                                                  .onPrimary))),
                                              ]))),
                                  const SizedBox(height: 8),
                                  ConstrainedBox(
                                      constraints: BoxConstraints(
                                          minHeight:
                                              MediaQuery.textScalerOf(context)
                                                      .scale(13) *
                                                  3),
                                      child: Center(
                                          child: Text(item.name,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  height: 1.5,
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400)))),
                                  if (item.animated || item.fixedPalette) ...[
                                    const SizedBox(height: 5),
                                    Wrap(spacing: 6, runSpacing: 5, children: [
                                      if (item.animated)
                                        badge(animatedLabel, play: true),
                                      if (item.fixedPalette) badge(fixedLabel),
                                    ]),
                                  ],
                                ])))))));
  }
}

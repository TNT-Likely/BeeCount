import 'package:flutter/material.dart';

/// Neutral page heading. Navigation and business actions belong to the host.
class BeePageHeader extends StatelessWidget {
  const BeePageHeader(
      {super.key,
      required this.title,
      this.onBack,
      this.subtitle,
      this.leading,
      this.actions = const [],
      this.titleTrailing,
      this.subtitleTrailing,
      this.center,
      this.content,
      this.bottom,
      this.showTitle = true,
      this.compact = false,
      this.padding = const EdgeInsets.symmetric(horizontal: 17, vertical: 8)});
  final String title;
  final VoidCallback? onBack;
  final String? subtitle;
  final Widget? leading,
      titleTrailing,
      subtitleTrailing,
      center,
      content,
      bottom;
  final List<Widget> actions;
  final bool showTitle, compact;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
        bottom: false,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTitle)
                Padding(
                    padding: padding,
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: compact ? 40 : 48),
                        child: Row(children: [
                          if (leading != null) ...[
                            leading!,
                            const SizedBox(width: 8)
                          ],
                          Expanded(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(children: [
                                  Flexible(
                                      child: Text(title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                  fontSize: leading == null &&
                                                          onBack == null
                                                      ? 23
                                                      : 18,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                  if (titleTrailing != null) ...[
                                    const SizedBox(width: 6),
                                    titleTrailing!
                                  ]
                                ]),
                                if (subtitle != null)
                                  Row(children: [
                                    Flexible(
                                        child: Text(subtitle!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: theme.colorScheme
                                                        .onSurfaceVariant))),
                                    if (subtitleTrailing != null) ...[
                                      const SizedBox(width: 6),
                                      subtitleTrailing!
                                    ]
                                  ])
                              ])),
                          if (center != null) ...[
                            const SizedBox(width: 6),
                            center!
                          ],
                          ...actions,
                        ]))),
              if (content != null) Padding(padding: padding, child: content!),
              if (bottom != null) bottom!,
            ]));
  }
}

/// Page sections share one spacing contract without owning scroll controllers.
class BeePageBody extends StatelessWidget {
  const BeePageBody(
      {super.key,
      required this.children,
      this.controller,
      this.bottomInset = 24,
      this.physics});
  final List<Widget> children;
  final ScrollController? controller;
  final double bottomInset;
  final ScrollPhysics? physics;
  @override
  Widget build(BuildContext context) => ListView.separated(
      controller: controller,
      physics: physics,
      padding: EdgeInsets.fromLTRB(
          17, 8, 17, bottomInset + MediaQuery.paddingOf(context).bottom),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) => children[index]);
}

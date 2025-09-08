import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../styles/design.dart';

class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final Widget? content;
  final EdgeInsetsGeometry padding;
  final Widget? titleTrailing;
  final Widget? subtitleTrailing;
  final Widget? center;
  const PrimaryHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.showBack = false,
      this.actions,
      this.bottom,
      this.content,
      this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 8),
      this.titleTrailing,
      this.subtitleTrailing,
      this.center});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(primaryColorProvider);
    final titleStyle = AppTextTokens.title(context);
    final subStyle = AppTextTokens.label(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: primary,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Material(
        color: primary,
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content != null)
                Padding(
                  padding: padding,
                  child: content!,
                )
              else
                Padding(
                  padding: padding,
                  child: Row(
                    children: [
                      if (showBack)
                        IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                    child: Text(title,
                                        style: titleStyle,
                                        overflow: TextOverflow.ellipsis)),
                                if (titleTrailing != null) ...[
                                  const SizedBox(width: 6),
                                  titleTrailing!,
                                ],
                              ],
                            ),
                            if (subtitle != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                      child: Text(subtitle!,
                                          style: subStyle,
                                          overflow: TextOverflow.ellipsis)),
                                  if (subtitleTrailing != null) ...[
                                    const SizedBox(width: 6),
                                    subtitleTrailing!,
                                  ]
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (center != null) ...[
                        const SizedBox(width: 6),
                        DefaultTextStyle(
                          style: Theme.of(context).textTheme.labelMedium ??
                              const TextStyle(
                                  fontSize: 12, color: Colors.black87),
                          child: center!,
                        ),
                      ],
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}

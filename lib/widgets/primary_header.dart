import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../styles/design.dart';

class PrimaryHeader extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  // 自由布局插槽：提供后将完全替代默认的标题/副标题/居中/操作区布局
  final Widget? content;
  // 顶部区域内边距（应用于 content 或默认行）
  final EdgeInsetsGeometry padding;
  // 可选：标题右侧紧邻的小部件（例如月份旁的图标）
  final Widget? titleTrailing;
  // 可选：副标题右侧紧邻的小部件（例如当副标题显示月份时的图标）
  final Widget? subtitleTrailing;
  // 可选：主行中部的小部件（例如汇总信息），位于标题区域与右侧 actions 之间
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

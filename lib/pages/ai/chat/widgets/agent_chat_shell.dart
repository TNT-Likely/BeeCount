import 'package:flutter/material.dart';

import 'package:beecount_ui/beecount_ui.dart';
import '../../../shared/scaffold/widgets/page_scaffold.dart';

/// Agent 对话页的轻量页面壳。
///
/// 使用 v4 标题与整页皮肤，同时保留对话所需的核心操作。
class AgentChatShell extends StatelessWidget {
  const AgentChatShell({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    required this.onOpenPermissions,
    required this.onClearHistory,
    this.backTooltip,
    this.permissionsTooltip,
    this.clearTooltip,
  });

  final String title;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback onOpenPermissions;
  final VoidCallback onClearHistory;
  final String? backTooltip;
  final String? permissionsTooltip;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) => V4PageScaffold(
          body: Column(children: [
        BeePageHeader(
            title: title,
            leading: SizedBox.square(
                dimension: 44,
                child: BeeIconButton(
                    key: const ValueKey('agent-chat-back'),
                    label: backTooltip ??
                        MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const BeeLineIcon('ChevronLeft'),
                    onPressed: onBack)),
            actions: [
              SizedBox.square(
                  dimension: 44,
                  child: BeeIconButton(
                      key: const ValueKey('agent-chat-permissions'),
                      label: permissionsTooltip ?? title,
                      icon: const BeeLineIcon('SlidersHorizontal'),
                      onPressed: onOpenPermissions)),
              SizedBox.square(
                  dimension: 44,
                  child: BeeIconButton(
                      key: const ValueKey('agent-chat-clear'),
                      label: clearTooltip ??
                          MaterialLocalizations.of(context).deleteButtonTooltip,
                      icon: const BeeLineIcon('Trash2'),
                      onPressed: onClearHistory))
            ]),
        Expanded(child: child)
      ]));
}

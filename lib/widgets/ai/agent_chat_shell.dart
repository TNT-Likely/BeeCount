import 'package:flutter/material.dart';

import '../../styles/tokens.dart';
import '../ui/primary_header.dart';

/// Agent 对话页的轻量页面壳。
///
/// 使用应用统一的紧凑主标题栏，同时保留对话所需的核心操作。
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: title,
            compact: true,
            showBack: true,
            onBack: onBack,
            backButtonKey: const ValueKey('agent-chat-back'),
            actions: [
              _AgentShellAction(
                key: const ValueKey('agent-chat-permissions'),
                icon: Icons.shield_outlined,
                tooltip: permissionsTooltip,
                onPressed: onOpenPermissions,
              ),
              _AgentShellAction(
                key: const ValueKey('agent-chat-clear'),
                icon: Icons.delete_outline_rounded,
                tooltip: clearTooltip,
                onPressed: onClearHistory,
              ),
            ],
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AgentShellAction extends StatelessWidget {
  const _AgentShellAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final label = tooltip;
    final button = IconButton(
      icon: Icon(icon, size: 21, color: BeeTokens.iconPrimary(context)),
      tooltip: label,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );

    if (label == null || label.isEmpty) return button;
    return Semantics(button: true, label: label, child: button);
  }
}

import 'package:flutter/material.dart';

import '../../styles/tokens.dart';
import 'agent_brand_mark.dart';

/// Agent 对话页的轻量页面壳。
///
/// 与普通页面的 [PrimaryHeader] 不同，这里只保留一行半透明浮层操作栏，
/// 让消息区和执行过程获得更多可视空间，同时保留用户熟悉的返回、权限和清空入口。
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
    final surface = BeeTokens.surface(context);
    final borderColor = BeeTokens.border(context).withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _AgentShellAction(
                        key: const ValueKey('agent-chat-back'),
                        icon: Icons.arrow_back_rounded,
                        tooltip: backTooltip,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 2),
                      const AgentBrandMark(
                        size: 34,
                        showStatus: true,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
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
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
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
      icon: Icon(icon, size: 21),
      tooltip: label,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );

    if (label == null || label.isEmpty) return button;
    return Semantics(button: true, label: label, child: button);
  }
}

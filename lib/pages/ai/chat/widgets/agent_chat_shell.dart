import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/scaffold/widgets/page_scaffold.dart';

class AgentChatShell extends StatelessWidget {
  const AgentChatShell({
    super.key,
    required this.title,
    this.ledgerName,
    required this.child,
    required this.onBack,
    required this.onMore,
    required this.moreLabel,
    this.backTooltip,
  });
  final String title, moreLabel;
  final String? ledgerName, backTooltip;
  final Widget child;
  final VoidCallback onBack, onMore;

  @override
  Widget build(BuildContext context) => V4PageScaffold(
        body: Column(children: [
          BeePageHeader(
            title: title,
            subtitle: ledgerName,
            leading: SizedBox.square(
              dimension: 44,
              child: BeeIconButton(
                key: const ValueKey('agent-chat-back'),
                label: backTooltip ??
                    MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BeeLineIcon('ChevronLeft'),
                onPressed: onBack,
              ),
            ),
            actions: [
              SizedBox.square(
                dimension: 44,
                child: BeeIconButton(
                  key: const ValueKey('agent-chat-more'),
                  label: moreLabel,
                  icon: const BeeLineIcon('Ellipsis'),
                  onPressed: onMore,
                ),
              )
            ],
          ),
          Expanded(child: child),
        ]),
      );
}

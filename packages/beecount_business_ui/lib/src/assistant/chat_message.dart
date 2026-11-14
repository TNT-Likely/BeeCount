import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeChatMessage extends StatelessWidget {
  const BeeChatMessage(
      {super.key,
      required this.author,
      required this.content,
      this.isUser = false,
      this.status,
      this.actions = const []});
  final String author;
  final Widget content;
  final bool isUser;
  final Widget? status;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
          widthFactor: .92,
          child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .13)
                      : BeeCardTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author,
                        style: TextStyle(
                            fontSize: 11, color: Theme.of(context).hintColor)),
                    const SizedBox(height: 8),
                    content,
                    if (status != null) ...[
                      const SizedBox(height: 10),
                      status!
                    ],
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: actions)
                    ]
                  ]))));
}

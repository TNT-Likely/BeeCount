import 'package:flutter/material.dart';

/// Full-width editorial answer layout, with no avatar or bubble gutter.
/// Hosts own Markdown, bill cards and actions; the package owns composition.
class AgentAnswerView extends StatelessWidget {
  const AgentAnswerView(
      {super.key, required this.content, this.activity, this.actions});
  final Widget content;
  final Widget? activity;
  final Widget? actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (activity != null) activity!,
          content,
          if (actions != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: actions!),
        ]),
      );
}

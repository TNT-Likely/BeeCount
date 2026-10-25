import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'page_scaffold.dart';

class SupportFrame extends StatelessWidget {
  const SupportFrame(
      {super.key,
      required this.title,
      required this.body,
      this.subtitle,
      this.actions = const []});
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => V4PageScaffold(
          body: Column(children: [
        BeePageHeader(
            title: title,
            subtitle: subtitle,
            leading: const BackButton(),
            actions: actions),
        Expanded(child: body)
      ]));
}

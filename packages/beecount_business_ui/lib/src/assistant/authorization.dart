import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

class BeeAuthorization extends StatelessWidget {
  const BeeAuthorization(
      {super.key,
      required this.description,
      required this.permissions,
      required this.deny,
      required this.once,
      required this.always,
      this.configuration});
  final String description;
  final List<String> permissions;
  final Widget deny, once, always;
  final Widget? configuration;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ...permissions.map((p) => BeeMenuRow(
                title: p, leading: const BeeLineIcon('Check', size: 16))),
            if (configuration != null) configuration!,
            const SizedBox(height: 16),
            always,
            const SizedBox(height: 6),
            once,
            deny
          ]);
}

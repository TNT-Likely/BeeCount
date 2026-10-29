import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Capability identity and formatted provider labels are supplied by the App.
class BeeAICapabilityRow extends StatelessWidget {
  const BeeAICapabilityRow(
      {super.key,
      required this.title,
      required this.description,
      required this.providerName,
      required this.icon,
      required this.onSelect});
  final String title, description, providerName;
  final Widget icon;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context) => BeeMenuRow(
        title: title,
        subtitle: description,
        leading: icon,
        onTap: onSelect,
        trailing: SizedBox(
            width: 112,
            child: Row(children: [
              Expanded(
                  child: Text(providerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor))),
              if (onSelect != null) ...[
                const SizedBox(width: 6),
                const BeeLineIcon('ChevronRight', size: 16)
              ],
            ])),
      );
}

/// Consent copy remains complete; consent persistence and policy navigation are host actions.
class BeeAIConsentContent extends StatelessWidget {
  const BeeAIConsentContent(
      {super.key,
      required this.description,
      required this.policyLabel,
      required this.onPolicy});
  final String description, policyLabel;
  final VoidCallback onPolicy;
  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(description,
                style: const TextStyle(fontSize: 13, height: 1.6)),
            const SizedBox(height: 4),
            Align(
                alignment: Alignment.centerLeft,
                child:
                    TextButton(onPressed: onPolicy, child: Text(policyLabel))),
          ]);
}

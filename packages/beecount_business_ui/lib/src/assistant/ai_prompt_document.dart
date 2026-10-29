import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeePromptVariable {
  const BeePromptVariable(this.token, this.description);
  final String token, description;
}

/// Variable registry presentation; template semantics and translations belong to App.
class BeePromptVariables extends StatelessWidget {
  const BeePromptVariables(
      {super.key,
      required this.title,
      required this.hint,
      required this.variables});
  final String title, hint;
  final List<BeePromptVariable> variables;
  @override
  Widget build(BuildContext context) => BeeSurface(
      padding: const EdgeInsets.all(4),
      child: BeeAccordion(
          title: title,
          subtitle: hint,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final variable in variables)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BeeLabel(label: variable.token, accent: true),
                        const SizedBox(height: 5),
                        Text(variable.description,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color: Theme.of(context).hintColor))
                      ]))
          ])));
}

class BeePromptDocument extends StatelessWidget {
  const BeePromptDocument(
      {super.key,
      required this.title,
      required this.editor,
      required this.unsavedLabel,
      required this.dirty});
  final String title, unsavedLabel;
  final Widget editor;
  final bool dirty;
  @override
  Widget build(BuildContext context) => BeeSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (dirty) BeeLabel(label: unsavedLabel, accent: true)
            ]),
        const SizedBox(height: 12),
        editor
      ]));
}

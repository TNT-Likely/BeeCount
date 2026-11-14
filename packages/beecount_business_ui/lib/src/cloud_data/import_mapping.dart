import 'package:flutter/material.dart';

class BeeFieldMapping {
  const BeeFieldMapping(
      {required this.id,
      required this.target,
      required this.sourceOptions,
      this.source,
      this.required = false,
      this.preview});
  final String id, target;
  final List<String> sourceOptions;
  final String? source, preview;
  final bool required;
}

class BeeImportMapping extends StatelessWidget {
  const BeeImportMapping(
      {super.key,
      required this.fields,
      required this.onChanged,
      required this.sourceLabel,
      this.extra,
      this.extraLabel});
  final List<BeeFieldMapping> fields;
  final void Function(String id, String? source) onChanged;
  final String sourceLabel;
  final Widget? extra;
  final String? extraLabel;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(sourceLabel,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        ...fields.map((field) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Expanded(
                  flex: 2,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${field.target}${field.required ? ' *' : ''}',
                            style: const TextStyle(fontSize: 13)),
                        if (field.preview != null)
                          Text(field.preview!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).hintColor))
                      ])),
              const SizedBox(width: 12),
              Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                      value: field.source,
                      decoration: InputDecoration(
                          isDense: true, labelText: field.target),
                      isExpanded: true,
                      items: field.sourceOptions
                          .map((o) => DropdownMenuItem(
                              value: o,
                              child: Text(o,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => onChanged(field.id, v)))
            ]))),
        if (extra != null)
          ExpansionTile(
              title:
                  Text(extraLabel ?? '', style: const TextStyle(fontSize: 13)),
              tilePadding: EdgeInsets.zero,
              children: [extra!])
      ]);
}

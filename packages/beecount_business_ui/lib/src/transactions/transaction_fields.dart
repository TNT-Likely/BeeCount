import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

class BeeTransactionRowLabels {
  const BeeTransactionRowLabels({
    this.fieldsTitle = 'Transaction fields',
    this.moreFields,
    this.category = 'Category',
    this.account = 'Account',
    this.ledger = 'Ledger',
    this.note = 'Note',
    this.amount = 'Original amount',
    this.converted = 'Historical conversion',
    this.time = 'Date',
    this.tags = 'Tags',
    this.attachments = 'Attachments',
    this.rules = 'Counting rules',
    this.readOnly = 'Read only',
    this.access = 'Access',
  });
  final String fieldsTitle,
      category,
      account,
      ledger,
      note,
      amount,
      converted,
      time,
      tags,
      attachments,
      rules,
      readOnly,
      access;
  final String Function(int count)? moreFields;
  String more(int count) => moreFields?.call(count) ?? '$count more';
}

/// A read-only field list; navigation can be supplied without editing the row.
class BeeTransactionField {
  const BeeTransactionField(
      {required this.label, required this.value, this.onTap});
  final String label, value;
  final VoidCallback? onTap;
}

class BeeTransactionFields extends StatelessWidget {
  const BeeTransactionFields({super.key, required this.fields});
  final List<BeeTransactionField> fields;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final field in fields) ...[
            InkWell(
                onTap: field.onTap,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 80,
                              child: Text(field.label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).hintColor))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(field.value,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.5))),
                          if (field.onTap != null) ...[
                            const SizedBox(width: 6),
                            const BeeLineIcon('ChevronRight', size: 14)
                          ],
                        ]))),
            Divider(height: 1, color: Theme.of(context).dividerColor),
          ]
        ]),
      );
}

import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controlled note-history preferences. The host validates and persists input;
/// this view never queries note history or changes a repository.
class BeeNoteHistoryPreferences extends StatelessWidget {
  const BeeNoteHistoryPreferences({
    super.key,
    required this.scopeLabel,
    required this.scopeOptions,
    required this.selectedScope,
    required this.onScope,
    required this.sortLabel,
    required this.sortOptions,
    required this.selectedSort,
    required this.onSort,
    required this.limitLabel,
    required this.limitHint,
    required this.limit,
    required this.onLimit,
    this.limitError,
  });
  final String scopeLabel, sortLabel, limitLabel, limitHint, limit;
  final List<String> scopeOptions, sortOptions;
  final int selectedScope, selectedSort;
  final ValueChanged<int>? onScope, onSort;
  final ValueChanged<String>? onLimit;
  final String? limitError;

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(scopeLabel),
            for (var i = 0; i < scopeOptions.length; i++)
              BeeRadioTile<int>(
                  label: scopeOptions[i],
                  value: i,
                  groupValue: selectedScope,
                  onChanged: onScope),
            const SizedBox(height: 8),
            Text(sortLabel),
            for (var i = 0; i < sortOptions.length; i++)
              BeeRadioTile<int>(
                  label: sortOptions[i],
                  value: i,
                  groupValue: selectedSort,
                  onChanged: onSort),
            const SizedBox(height: 12),
            TextFormField(
                key: onLimit == null
                    ? ValueKey('note-history-limit-$limit')
                    : null,
                initialValue: limit,
                enabled: onLimit != null,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                    labelText: limitLabel,
                    helperText: limitHint,
                    helperMaxLines: 3,
                    errorText: limitError,
                    errorMaxLines: 3),
                onChanged: onLimit),
          ]);
}

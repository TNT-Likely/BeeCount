import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';

/// Presentation only: authentication, encryption and submission stay in the host.
class BeePinPad extends StatelessWidget {
  const BeePinPad(
      {super.key,
      required this.length,
      required this.filled,
      required this.deleteLabel,
      required this.onDigit,
      required this.onDelete,
      this.error,
      this.invalid = false,
      this.auxiliaryKey,
      this.enabled = true,
      this.cardKeys = false,
      this.compact = false});
  final int length, filled;
  final String deleteLabel;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final String? error;
  final bool enabled, invalid, cardKeys, compact;
  final Widget? auxiliaryKey;
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
            label: '$filled / $length',
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    length,
                    (i) => Container(
                        width: 12,
                        height: 12,
                        margin: EdgeInsets.all(cardKeys ? 7 : 8),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: invalid
                                ? Theme.of(context).colorScheme.error
                                : i < filled
                                    ? cardKeys
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                    : BeeCardTheme.of(context).soft,
                            border: Border.all(
                                color: Theme.of(context).dividerColor)))))),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(8),
              child: BeeStatus(label: error!, tone: BeeTone.error)),
        const SizedBox(height: 12),
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'delete']
        ])
          Padding(
              padding: EdgeInsets.only(
                  bottom: cardKeys
                      ? row.first.isEmpty
                          ? 0
                          : 9
                      : 6),
              child: Row(
                  children: cardKeys
                      ? [
                          for (var i = 0; i < row.length; i++) ...[
                            if (i > 0) const SizedBox(width: 9),
                            Expanded(
                                child: row[i].isEmpty
                                    ? auxiliaryKey ??
                                        SizedBox(height: compact ? 48 : 57)
                                    : _cardKey(context, row[i]))
                          ]
                        ]
                      : row
                          .map((v) => Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: v.isEmpty
                                      ? auxiliaryKey ??
                                          SizedBox(
                                              height: cardKeys
                                                  ? compact
                                                      ? 48
                                                      : 57
                                                  : 44)
                                      : cardKeys
                                          ? _cardKey(context, v)
                                          : BeeButton(
                                              label: v == 'delete'
                                                  ? deleteLabel
                                                  : v,
                                              kind: BeeButtonKind.secondary,
                                              onPressed: !enabled
                                                  ? null
                                                  : v == 'delete'
                                                      ? onDelete
                                                      : filled >= length
                                                          ? null
                                                          : () => onDigit(v)))))
                          .toList()))
      ]);

  Widget _cardKey(BuildContext context, String value) {
    final deleting = value == 'delete';
    final callback = !enabled
        ? null
        : deleting
            ? onDelete
            : filled >= length
                ? null
                : () => onDigit(value);
    return SizedBox(
        height: compact ? 48 : 57,
        child: FilledButton(
            onPressed: callback,
            style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: BeeCardTheme.of(context).surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                disabledBackgroundColor: BeeCardTheme.of(context).surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17))),
            child: deleting
                ? Semantics(
                    label: deleteLabel,
                    child: ExcludeSemantics(
                        child: BeeLineIcon('Delete',
                            size: 21,
                            color: Theme.of(context).colorScheme.onSurface)))
                : Text(value,
                    style: TextStyle(
                        fontSize: compact ? 22 : 25,
                        fontWeight: FontWeight.w400))));
  }
}

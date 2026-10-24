import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Values, names, timestamps and rate precedence are supplied by the App.
class BeeExchangeRateRow extends StatelessWidget {
  const BeeExchangeRateRow(
      {super.key,
      required this.code,
      required this.name,
      required this.value,
      required this.source,
      this.manual = false,
      this.stale = false,
      this.onTap});
  final String code, name, value, source;
  final bool manual, stale;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), cards = BeeCardTheme.of(context);
    final sourceColor = manual
        ? theme.colorScheme.primary
        : stale
            ? Colors.orange
            : theme.hintColor;
    final title = Row(children: [
      Expanded(
          child: Tooltip(
              message: name,
              child: Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)))),
      const SizedBox(width: 6),
      Text(code, style: TextStyle(fontSize: 12, color: theme.hintColor))
    ]);
    final status = Text(source,
        style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: sourceColor,
            fontWeight: manual ? FontWeight.w600 : null));
    final amount = Text(value,
        style: const TextStyle(
            fontSize: 13, height: 1.5, fontWeight: FontWeight.w600),
        textAlign: TextAlign.end);
    return Semantics(
        container: true,
        button: onTap != null,
        label: '$name · $code · $value · $source',
        onTap: onTap,
        child: ExcludeSemantics(
            child: Material(
                color: cards.surface,
                child: InkWell(
                    onTap: onTap,
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: LayoutBuilder(builder: (context, box) {
                          final narrow = box.maxWidth < 320 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.25;
                          if (narrow) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  title,
                                  const SizedBox(height: 4),
                                  status,
                                  const SizedBox(height: 8),
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: amount)
                                ]);
                          }
                          return Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  title,
                                  const SizedBox(height: 4),
                                  status
                                ])),
                            const SizedBox(width: 12),
                            ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: box.maxWidth * .52),
                                child: amount)
                          ]);
                        }))))));
  }
}

/// Controlled draft field; validation and persistence stay in the App.
class BeeExchangeRateField extends StatelessWidget {
  const BeeExchangeRateField(
      {super.key,
      required this.quote,
      required this.base,
      required this.controller,
      required this.inverseLabel,
      this.errorText,
      this.onChanged,
      this.autofocus = true});
  final String quote, base, inverseLabel;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
                controller: controller,
                autofocus: autofocus,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                onChanged: onChanged,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                    prefixText: '1 $quote = ',
                    suffixText: base,
                    errorText: errorText)),
            const SizedBox(height: 10),
            Text(inverseLabel,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Theme.of(context).hintColor))
          ]);
}

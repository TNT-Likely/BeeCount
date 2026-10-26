import 'package:beecount_business_ui/beecount_business_ui.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

typedef ExchangeRateDraft = ({bool reset, String rate});

/// Own the controller until the route's exit animation has finished.
class ExchangeRateEditor extends StatefulWidget {
  const ExchangeRateEditor(
      {super.key,
      required this.quote,
      required this.base,
      required this.hadManual,
      required this.initialText});
  final String quote, base, initialText;
  final bool hadManual;
  @override
  State<ExchangeRateEditor> createState() => _ExchangeRateEditorState();
}

class _ExchangeRateEditorState extends State<ExchangeRateEditor> {
  late final controller = TextEditingController(text: widget.initialText);
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context),
        parsed = double.tryParse(
            BeeDecimalInputFormatter.normalize(controller.text.trim()));
    final inverse = parsed != null && parsed > 0
        ? (1 / parsed).toStringAsPrecision(6)
        : '—';
    return BeeDialog(
        title: Text(l.rateEditTitle),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BeeExchangeRateField(
                  quote: widget.quote,
                  base: widget.base,
                  controller: controller,
                  inverseLabel:
                      l.rateInverseHint(widget.base, inverse, widget.quote),
                  errorText: error,
                  onChanged: (_) => setState(() => error = null)),
              if (widget.hadManual) ...[
                const SizedBox(height: 12),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () => Navigator.pop<ExchangeRateDraft>(
                            context, (reset: true, rate: '')),
                        child: Text(l.rateResetToAuto)))
              ],
            ]),
        actions: [
          BeeButton(
              label: l.commonCancel,
              kind: BeeButtonKind.secondary,
              onPressed: () => Navigator.pop(context)),
          BeeButton(
              label: l.commonSave,
              onPressed: () {
                final raw = BeeDecimalInputFormatter.normalize(
                        controller.text.trim()),
                    value = double.tryParse(raw);
                if (value == null || value <= 1e-6 || value >= 1e9) {
                  setState(() => error = l.commonError);
                  return;
                }
                Navigator.pop<ExchangeRateDraft>(
                    context, (reset: false, rate: raw));
              })
        ]);
  }
}

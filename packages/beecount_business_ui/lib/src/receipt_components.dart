import 'package:beecount_ui/beecount_ui.dart';
import 'package:beecount_ui/multi_select.dart';
import 'package:flutter/material.dart';

@immutable
class BeeReceiptField {
  const BeeReceiptField({required this.value, required this.label, this.key});
  final String value, label;
  final Key? key;
}

/// Modal content only. Capturing the preview and native export belong to App.
class BeeReceiptComposer extends StatelessWidget {
  const BeeReceiptComposer(
      {super.key,
      required this.title,
      required this.closeLabel,
      required this.fieldsLabel,
      required this.saveLabel,
      required this.shareLabel,
      required this.preview,
      required this.fields,
      required this.selected,
      required this.onChanged,
      required this.onClose,
      required this.onSave,
      required this.onShare,
      this.busy = false,
      this.sharing = false});
  final String title, closeLabel, fieldsLabel, saveLabel, shareLabel;
  final Widget preview;
  final List<BeeReceiptField> fields;
  final Set<String> selected;
  final ValueChanged<Set<String>>? onChanged;
  final VoidCallback? onClose, onSave;
  final ValueChanged<Rect>? onShare;
  final bool busy, sharing;
  @override
  Widget build(BuildContext context) {
    final cards = BeeCardTheme.of(context);
    return Material(
        color: cards.surface,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 6),
              child: Row(children: [
                const BeeLineIcon('ReceiptText', size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600))),
                BeeIconButton(
                    key: const ValueKey('receipt-close'),
                    label: closeLabel,
                    onPressed: busy ? null : onClose,
                    icon: const BeeLineIcon('X', size: 21))
              ])),
          Expanded(
              child: ColoredBox(
                  color: cards.canvas,
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ClipRect(
                          child: InteractiveViewer(
                              minScale: 1,
                              maxScale: 5,
                              child: Center(
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                          width: 320,
                                          child: DecoratedBox(
                                              decoration:
                                                  BoxDecoration(boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: .10),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 6))
                                              ]),
                                              child: preview))))))))),
          Flexible(
              flex: 0,
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * .30),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(fieldsLabel,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).hintColor)),
                            const SizedBox(height: 10),
                            BeeMultiSelect<String>(
                                selectedValues: selected,
                                options: [
                                  for (final f in fields)
                                    BeeMultiSelectOption(
                                        value: f.value,
                                        label: f.label,
                                        key: f.key)
                                ],
                                onChanged: busy ? null : onChanged)
                          ])))),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Row(children: [
                Expanded(
                    child: OutlinedButton.icon(
                        key: const ValueKey('receipt-save'),
                        onPressed: busy ? null : onSave,
                        icon: busy && !sharing
                            ? _spinner()
                            : const BeeLineIcon('Download', size: 18),
                        label: Text(saveLabel))),
                const SizedBox(width: 10),
                Expanded(
                    child: Builder(
                        builder: (buttonContext) => FilledButton.icon(
                            key: const ValueKey('receipt-share'),
                            onPressed: busy
                                ? null
                                : () => onShare?.call(_anchor(buttonContext)),
                            icon: busy && sharing
                                ? _spinner()
                                : const BeeLineIcon('Share', size: 18),
                            label: Text(shareLabel)))),
              ])),
        ]));
  }

  static Rect _anchor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static Widget _spinner() => const SizedBox(
      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
}

/// A neutral preview dialog; host callbacks own regeneration and native export.
class BeeAnnualPosterPreview extends StatelessWidget {
  const BeeAnnualPosterPreview(
      {super.key,
      required this.title,
      required this.closeLabel,
      required this.privacyLabel,
      required this.saveLabel,
      required this.shareLabel,
      required this.preview,
      required this.onPrivacy,
      required this.onSave,
      required this.onShare,
      required this.onClose,
      this.busy = false,
      this.hideIncome = false});
  final String title, closeLabel, privacyLabel, saveLabel, shareLabel;
  final Widget preview;
  final VoidCallback? onPrivacy, onSave, onShare, onClose;
  final bool busy, hideIncome;
  @override
  Widget build(BuildContext context) => Dialog(
      backgroundColor: BeeCardTheme.of(context).surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .85,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 8, 6),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600))),
                      BeeIconButton(
                          label: closeLabel,
                          onPressed: busy ? null : onClose,
                          icon: const BeeLineIcon('X', size: 21))
                    ])),
                Expanded(
                    child: ColoredBox(
                        color: BeeCardTheme.of(context).canvas,
                        child: SizedBox.expand(
                            child:
                                Stack(alignment: Alignment.center, children: [
                          InteractiveViewer(
                              minScale: .5, maxScale: 3, child: preview),
                          if (busy)
                            Positioned.fill(
                                child: ColoredBox(
                                    color: Colors.black.withValues(alpha: .16),
                                    child: const Center(
                                        child: CircularProgressIndicator())))
                        ])))),
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      TextButton.icon(
                          key: const ValueKey('annual-poster-privacy'),
                          onPressed: busy ? null : onPrivacy,
                          icon: BeeLineIcon(hideIncome ? 'EyeOff' : 'Eye',
                              size: 18),
                          label: Text(privacyLabel)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                key: const ValueKey('annual-poster-save'),
                                onPressed: busy ? null : onSave,
                                icon: const BeeLineIcon('Download', size: 18),
                                label: Text(saveLabel))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: FilledButton.icon(
                                key: const ValueKey('annual-poster-share'),
                                onPressed: busy ? null : onShare,
                                icon: const BeeLineIcon('Share', size: 18),
                                label: Text(shareLabel)))
                      ])
                    ])),
              ]))));
}

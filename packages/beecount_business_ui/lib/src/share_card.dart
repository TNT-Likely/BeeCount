import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

@immutable
class BeeShareCardTemplate {
  const BeeShareCardTemplate(this.id, this.label);
  final String id, label;
}

/// Shared modal/page content. The host owns data, PNG capture and platform I/O.
class BeeShareCard extends StatelessWidget {
  const BeeShareCard({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.saveLabel,
    required this.shareLabel,
    required this.generatingLabel,
    required this.retryLabel,
    required this.preview,
    required this.templates,
    required this.selected,
    this.onTemplate,
    this.onClose,
    this.onSave,
    this.onShare,
    this.onRetry,
    this.privacyLabel,
    this.onPrivacy,
    this.hideIncome = false,
    this.generating = false,
    this.busy = false,
    this.sharing = false,
    this.error,
  });
  final String title,
      closeLabel,
      saveLabel,
      shareLabel,
      generatingLabel,
      retryLabel;
  final Widget preview;
  final List<BeeShareCardTemplate> templates;
  final String selected;
  final ValueChanged<String>? onTemplate;
  final VoidCallback? onClose, onSave, onRetry, onPrivacy;
  final ValueChanged<Rect>? onShare;
  final String? privacyLabel, error;
  final bool hideIncome, generating, busy, sharing;

  @override
  Widget build(BuildContext context) {
    final cards = BeeCardTheme.of(context);
    return Material(
      color: cards.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(children: [
            const BeeLineIcon('Image', size: 21),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600))),
            BeeIconButton(
              key: const ValueKey('share-card-close'),
              label: closeLabel,
              icon: const BeeLineIcon('X', size: 21),
              onPressed: onClose,
            ),
          ]),
        ),
        if (templates.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final template in templates)
                BeeChoiceChip(
                  key: ValueKey('share-card-template-${template.id}'),
                  label: template.label,
                  compact: true,
                  selected: selected == template.id,
                  onSelected:
                      busy ? null : (_) => onTemplate?.call(template.id),
                ),
            ]),
          ),
        Expanded(
          child: ColoredBox(
            color: cards.canvas,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: generating
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(generatingLabel, textAlign: TextAlign.center),
                    ]))
                  : Center(
                      child: ClipRect(
                          child: _ShareCardPreview(
                      templates: templates,
                      selected: selected,
                      onTemplate: busy ? null : onTemplate,
                      preview: preview,
                    ))),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                  child: Text(error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
              if (onRetry != null)
                TextButton(
                    key: const ValueKey('share-card-retry'),
                    onPressed: generating || busy ? null : onRetry,
                    child: Text(retryLabel)),
            ]),
          ),
        if (privacyLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: TextButton.icon(
              key: const ValueKey('share-card-privacy'),
              onPressed: generating || busy ? null : onPrivacy,
              icon: BeeLineIcon(hideIncome ? 'EyeOff' : 'Eye', size: 18),
              label: Text(privacyLabel!),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: LayoutBuilder(builder: (context, constraints) {
            final buttons = [
              OutlinedButton.icon(
                key: const ValueKey('share-card-save'),
                onPressed: busy || generating ? null : onSave,
                icon: busy && !sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const BeeLineIcon('Download', size: 18),
                label: Text(saveLabel, textAlign: TextAlign.center),
              ),
              Builder(
                  builder: (buttonContext) => FilledButton.icon(
                        key: const ValueKey('share-card-share'),
                        onPressed: busy || generating || onShare == null
                            ? null
                            : () {
                                final box = buttonContext.findRenderObject()
                                    as RenderBox;
                                onShare!(
                                    box.localToGlobal(Offset.zero) & box.size);
                              },
                        icon: busy && sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const BeeLineIcon('Share', size: 18),
                        label: Text(shareLabel, textAlign: TextAlign.center),
                      )),
            ];
            if (MediaQuery.textScalerOf(context).scale(14) > 17 &&
                constraints.maxWidth < 340) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buttons[0],
                    const SizedBox(height: 6),
                    buttons[1]
                  ]);
            }
            return Row(children: [
              Expanded(child: buttons[0]),
              const SizedBox(width: 10),
              Expanded(child: buttons[1])
            ]);
          }),
        ),
      ]),
    );
  }
}

class _ShareCardPreview extends StatefulWidget {
  const _ShareCardPreview(
      {required this.preview,
      required this.templates,
      required this.selected,
      this.onTemplate});
  final Widget preview;
  final List<BeeShareCardTemplate> templates;
  final String selected;
  final ValueChanged<String>? onTemplate;
  @override
  State<_ShareCardPreview> createState() => _ShareCardPreviewState();
}

class _ShareCardPreviewState extends State<_ShareCardPreview> {
  final transform = TransformationController();
  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 5,
        onInteractionEnd: (details) {
          if (transform.value.getMaxScaleOnAxis() > 1.01 ||
              widget.templates.length < 2) {
            return;
          }
          final velocity = details.velocity.pixelsPerSecond.dx;
          if (velocity.abs() < 100) return;
          final current =
              widget.templates.indexWhere((t) => t.id == widget.selected);
          final next = current + (velocity < 0 ? 1 : -1);
          if (next >= 0 && next < widget.templates.length) {
            widget.onTemplate?.call(widget.templates[next].id);
          }
        },
        child: widget.preview,
      );
}

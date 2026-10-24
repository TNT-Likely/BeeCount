import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'workflow_components.dart';
import 'quick_add_fan.dart';

/// Short tap records normally. Hold 480 ms, slide and release selects a target;
/// releasing outside cancels. The visible menu also supports keyboard/screen readers.
class BeeQuickAddTrigger extends StatefulWidget {
  const BeeQuickAddTrigger(
      {super.key,
      required this.label,
      required this.menuLabel,
      required this.cancelLabel,
      required this.actions,
      required this.onTap,
      required this.onSelected,
      this.onCancel,
      this.hint = ''});
  final String label, menuLabel, cancelLabel, hint;
  final List<BeeAction> actions;
  final VoidCallback onTap;
  final ValueChanged<String> onSelected;
  final VoidCallback? onCancel;
  @override
  State<BeeQuickAddTrigger> createState() => _BeeQuickAddTriggerState();
}

class _BeeQuickAddTriggerState extends State<BeeQuickAddTrigger> {
  OverlayEntry? overlay;
  String? hover;
  final anchor = GlobalKey();
  Offset? origin;
  void close() {
    overlay?.remove();
    overlay?.dispose();
    overlay = null;
    hover = null;
    origin = null;
  }

  void open() {
    if (overlay != null) return;
    final box = anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    origin = BeeQuickAddFan.safeOrigin(
        box.localToGlobal(Offset.zero) +
            Offset(box.size.width / 2, box.size.height / 2),
        MediaQuery.sizeOf(context));
    overlay = OverlayEntry(
        builder: (context) => BeeQuickAddFan(
            origin: origin!,
            actions: widget.actions,
            title: widget.menuLabel,
            hint: widget.hint,
            cancelLabel: widget.cancelLabel,
            hoveredIndex: widget.actions.indexWhere((a) => a.id == hover),
            onSelected: (id) {
              close();
              widget.onSelected(id);
            },
            onDismiss: () {
              close();
              widget.onCancel?.call();
            }));
    Overlay.of(context).insert(overlay!);
  }

  void move(Offset position) {
    String? next;
    if (origin == null) return;
    for (var i = 0; i < widget.actions.length && i < 3; i++) {
      if ((position - BeeQuickAddFan.centerFor(origin!, i)).distance <= 27) {
        next = widget.actions[i].id;
        break;
      }
    }
    if (hover != next) {
      hover = next;
      overlay?.markNeedsBuild();
    }
  }

  void end() {
    final id = hover;
    close();
    if (id == null) {
      widget.onCancel?.call();
    } else {
      widget.onSelected(id);
    }
  }

  @override
  void dispose() {
    close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Semantics(
                button: true,
                label: widget.label,
                onLongPress: open,
                child: RawGestureDetector(
                    gestures: {
                      LongPressGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                                  LongPressGestureRecognizer>(
                              () => LongPressGestureRecognizer(
                                  duration: const Duration(milliseconds: 480)),
                              (instance) {
                        instance.onLongPressStart = (_) => open();
                        instance.onLongPressMoveUpdate =
                            (event) => move(event.globalPosition);
                        instance.onLongPressEnd = (_) => end();
                        instance.onLongPressCancel = () {
                          close();
                          widget.onCancel?.call();
                        };
                      })
                    },
                    child: GestureDetector(
                        onSecondaryTap: open,
                        child: BeeButton(
                            key: anchor,
                            label: widget.label,
                            icon: const BeeLineIcon('Plus'),
                            onPressed: widget.onTap))))),
        BeeIconButton(
            label: widget.menuLabel,
            onPressed: open,
            icon: const BeeLineIcon('Ellipsis'))
      ]);
}

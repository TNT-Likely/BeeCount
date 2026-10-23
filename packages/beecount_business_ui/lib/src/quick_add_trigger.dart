import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:beecount_ui/beecount_ui.dart';
import 'workflow_components.dart';

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
      this.onCancel});
  final String label, menuLabel, cancelLabel;
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
  final targets = <String, GlobalKey>{};
  void close() {
    overlay?.remove();
    overlay?.dispose();
    overlay = null;
    hover = null;
  }

  void open() {
    if (overlay != null) return;
    targets.clear();
    for (final a in widget.actions) {
      targets[a.id] = GlobalKey();
    }
    overlay = OverlayEntry(
        builder: (context) => Stack(children: [
              Positioned.fill(
                  child: GestureDetector(
                      onTap: () {
                        close();
                        widget.onCancel?.call();
                      },
                      child: ColoredBox(
                          color: Colors.black.withValues(alpha: .18)))),
              Positioned(
                  left: 17,
                  right: 17,
                  bottom: 110,
                  child: SafeArea(
                      child: BeeSurface(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.actions
                            .map((a) => SizedBox(
                                key: targets[a.id],
                                width: 86,
                                child: BeeButton(
                                    label: a.label,
                                    icon: a.icon,
                                    kind: hover == a.id
                                        ? BeeButtonKind.primary
                                        : BeeButtonKind.secondary,
                                    onPressed: () {
                                      close();
                                      widget.onSelected(a.id);
                                    })))
                            .toList()),
                    TextButton(
                        onPressed: () {
                          close();
                          widget.onCancel?.call();
                        },
                        child: Text(widget.cancelLabel)),
                  ])))),
            ]));
    Overlay.of(context).insert(overlay!);
  }

  void move(Offset position) {
    String? next;
    for (final e in targets.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (box.localToGlobal(Offset.zero) & box.size).contains(position)) {
        next = e.key;
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
                            label: widget.label,
                            icon: const BeeLineIcon('Plus'),
                            onPressed: widget.onTap))))),
        IconButton(
            tooltip: widget.menuLabel,
            onPressed: open,
            icon: const BeeLineIcon('Ellipsis'))
      ]);
}

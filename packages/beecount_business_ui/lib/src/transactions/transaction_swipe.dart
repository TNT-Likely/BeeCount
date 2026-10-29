import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Internal row action: reveal a 78px delete button, then ask the host to confirm.
class TransactionSwipeAction extends StatefulWidget {
  const TransactionSwipeAction(
      {super.key,
      required this.child,
      required this.onDeleteRequested,
      required this.deleteLabel});
  final Widget child;
  final Future<void> Function() onDeleteRequested;
  final String deleteLabel;

  @override
  State<TransactionSwipeAction> createState() => _TransactionSwipeActionState();
}

class _TransactionSwipeActionState extends State<TransactionSwipeAction>
    with SingleTickerProviderStateMixin {
  late final _reveal = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180));
  bool _busy = false;
  static const extent = 78.0;

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _requestDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _reveal.reverse();
    if (!mounted) return;
    try {
      await widget.onDeleteRequested();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _deleteButton(BuildContext context) => ExcludeSemantics(
      excluding: _reveal.value == 0,
      child: IgnorePointer(
          ignoring: _reveal.value == 0 || _busy,
          child: SizedBox(
              width: extent,
              height: double.infinity,
              child: Material(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xffae4e43)
                      : const Color(0xffcf6559),
                  child: InkWell(
                      key: const ValueKey('transaction-swipe-delete'),
                      onTap: _requestDelete,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const BeeLineIcon('Trash2',
                                size: 18, color: Color(0xfffff8f4)),
                            const SizedBox(height: 5),
                            Text(widget.deleteLabel,
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xfffff8f4))),
                          ]))))));

  @override
  Widget build(BuildContext context) {
    final direction =
        Directionality.of(context) == TextDirection.ltr ? -1.0 : 1.0;
    return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedBuilder(
          animation: _reveal,
          builder: (context, _) => GestureDetector(
              key: const ValueKey('transaction-swipe'),
              onTap: _reveal.value > 0 ? () => _reveal.reverse() : null,
              onHorizontalDragUpdate: _busy
                  ? null
                  : (d) {
                      _reveal.value =
                          (_reveal.value + direction * d.delta.dx / extent)
                              .clamp(0, 1);
                    },
              onHorizontalDragCancel: () => _reveal.reverse(),
              onHorizontalDragEnd: (d) {
                final v = direction * d.velocity.pixelsPerSecond.dx;
                if (v > 250 || (v >= -250 && _reveal.value > .45)) {
                  _reveal.forward();
                } else {
                  _reveal.reverse();
                }
              },
              child: Stack(children: [
                Positioned.fill(
                    child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _deleteButton(context))),
                Transform.translate(
                    offset: Offset(direction * extent * _reveal.value, 0),
                    child: AbsorbPointer(
                        absorbing: _reveal.value > .01,
                        child: ColoredBox(
                            color: BeeCardTheme.of(context).surface,
                            child: widget.child))),
              ])),
        ));
  }
}

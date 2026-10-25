import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../beecount_ui.dart';

/// A modal sheet owned by its host widget, with no route left behind on disposal.
/// Mount inside a Stack and exclude the underlying content's semantics while open.
class BeeLocalSheet extends StatelessWidget {
  const BeeLocalSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
  });
  final String title;
  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent()
          },
          child: Actions(
              actions: {
                DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) {
                  onClose();
                  return null;
                })
              },
              child: FocusScope(
                  autofocus: true,
                  child: Stack(children: [
                    Positioned.fill(
                        child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                            child: ModalBarrier(
                                color: Colors.black.withValues(alpha: .26),
                                dismissible: true,
                                onDismiss: onClose,
                                semanticsLabel:
                                    MaterialLocalizations.of(context)
                                        .modalBarrierDismissLabel))),
                    Align(
                        alignment: Alignment.bottomCenter,
                        child: Semantics(
                            scopesRoute: true,
                            namesRoute: true,
                            explicitChildNodes: true,
                            label: title,
                            child: ConstrainedBox(
                                constraints: BoxConstraints(
                                    maxWidth: 600,
                                    maxHeight:
                                        MediaQuery.sizeOf(context).height *
                                            .76),
                                child: Material(
                                    color: BeeCardTheme.of(context).surface,
                                    clipBehavior: Clip.antiAlias,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(25)),
                                    child: BeeSheet(
                                        title: title,
                                        onClose: onClose,
                                        child: child)))))
                  ])))));
}

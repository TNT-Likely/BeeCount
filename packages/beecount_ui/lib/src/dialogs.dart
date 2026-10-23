import 'package:flutter/material.dart';
import '../beecount_ui.dart';

/// Card design dialog: 20 outer / 18 inner spacing, compact 16px header,
/// independently scrolling content, equal-width actions, no Material tint.
class BeeDialog extends StatelessWidget {
  const BeeDialog(
      {super.key,
      required this.title,
      this.content,
      this.actions = const [],
      this.showClose = true});
  final Widget title;
  final Widget? content;
  final List<Widget> actions;
  final bool showClose;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final foreground =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.light
            ? const Color(0xff262829)
            : Colors.white;
    final actionTheme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(onPrimary: foreground),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: foreground,
                minimumSize: const Size(44, 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)))),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                backgroundColor: BeeCardTheme.of(context).soft,
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)))));
    return Dialog(
        backgroundColor: BeeCardTheme.of(context).surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: MediaQuery.sizeOf(context).height * .85),
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child: DefaultTextStyle.merge(
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface),
                                child: title)),
                        if (showClose)
                          SizedBox(
                              width: 36,
                              height: 36,
                              child: CloseButton(
                                  style: IconButton.styleFrom(
                                      padding: EdgeInsets.zero),
                                  onPressed: () => Navigator.maybePop(context)))
                      ]),
                      if (content != null) ...[
                        const SizedBox(height: 13),
                        Flexible(
                            child: SingleChildScrollView(
                                child: DefaultTextStyle.merge(
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color:
                                            theme.colorScheme.onSurfaceVariant),
                                    child: content!)))
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Theme(
                            data: actionTheme,
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (var i = 0; i < actions.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    Expanded(child: actions[i])
                                  ]
                                ]))
                      ],
                    ]))));
  }
}

Future<T?> showBeeDialog<T>(BuildContext context,
    {required String title,
    required Widget child,
    List<Widget> actions = const [],
    bool dismissible = true}) {
  // A previous editor must not regain focus and scroll the host on dismissal.
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: Colors.black.withValues(alpha: .26),
      builder: (_) =>
          BeeDialog(title: Text(title), content: child, actions: actions));
}

Future<bool> showBeeConfirm(BuildContext context,
        {required String title,
        required String message,
        required String confirmLabel,
        required String cancelLabel,
        bool danger = false}) async =>
    await showBeeDialog<bool>(context,
        title: title,
        child: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelLabel)),
          BeeButton(
              label: confirmLabel,
              kind: danger ? BeeButtonKind.danger : BeeButtonKind.primary,
              onPressed: () => Navigator.pop(context, true)),
        ]) ??
    false;

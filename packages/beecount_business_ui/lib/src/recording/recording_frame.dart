import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter/material.dart';

/// Fixed regions share a single layout contract. Only [category] scrolls; focus,
/// keyboard state and draft submission are supplied by the host.
class RecordingFrame extends StatelessWidget {
  const RecordingFrame(
      {super.key,
      required this.amount,
      required this.category,
      required this.details,
      required this.keypad,
      required this.actions,
      this.authors,
      this.compact = false,
      this.narrow = false,
      this.keyboardVisible = false,
      this.transparentDock = false,
      this.transfer = false});
  final Widget amount, category, details, keypad, actions;
  final Widget? authors;
  final bool compact, narrow, keyboardVisible, transparentDock, transfer;
  @override
  Widget build(BuildContext context) {
    final gap = transfer
        ? 8.0
        : compact && narrow
            ? 6.0
            : 8.0;
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), child: amount),
      SizedBox(height: gap),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: ColoredBox(
                      color: BeeCardTheme.of(context).surface,
                      child: SingleChildScrollView(
                          key: const ValueKey('recording-content'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                category,
                                if (authors != null) authors!
                              ])))))),
      SizedBox(height: gap),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16), child: details),
      Material(
          color: transparentDock
              ? Colors.transparent
              : BeeCardTheme.of(context).canvas,
          child: Padding(
              key: const ValueKey('recording-dock'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!keyboardVisible) keypad,
                    SizedBox(height: compact && narrow ? 5 : 7),
                    actions
                  ])))
    ]);
  }
}

class RecordingActions extends StatelessWidget {
  const RecordingActions(
      {super.key,
      required this.saveLabel,
      required this.onEquals,
      required this.onSave,
      this.saveNextLabel,
      this.onSaveNext,
      this.showSaveNext = false,
      this.saving = false});
  final String saveLabel;
  final String? saveNextLabel;
  final VoidCallback onEquals;
  final VoidCallback? onSave, onSaveNext;
  final bool showSaveNext, saving;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), colors = BeeCardTheme.of(context);
    Widget action(String key, Widget child, VoidCallback? callback,
            {Color? background, Color? foreground}) =>
        SizedBox(
            height: 44,
            child: FilledButton(
                key: ValueKey(key),
                onPressed: callback,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: background ?? colors.surface,
                    foregroundColor: foreground ?? theme.colorScheme.onSurface,
                    disabledBackgroundColor:
                        background?.withValues(alpha: .45) ?? colors.surface,
                    disabledForegroundColor: theme.hintColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: child));
    return Row(children: [
      if (showSaveNext) ...[
        Expanded(
            flex: 100,
            child: action(
                'recording-save-next',
                Text(saveNextLabel ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                onSaveNext)),
        const SizedBox(width: 6)
      ],
      Expanded(
          flex: 75,
          child: action('recording-equals',
              const Text('=', style: TextStyle(fontSize: 23)), onEquals,
              background: Color.alphaBlend(
                  theme.colorScheme.primary.withValues(alpha: .12),
                  colors.surface),
              foreground: Color.lerp(theme.colorScheme.primary,
                  theme.colorScheme.onSurface, .42))),
      const SizedBox(width: 6),
      Expanded(
          flex: 160,
          child: action(
              'recording-save',
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (saving)
                  const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  const BeeLineIcon('Check', size: 17),
                const SizedBox(width: 5),
                Flexible(
                    child: Text(saveLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)))
              ]),
              onSave,
              background: theme.colorScheme.primary,
              foreground: theme.colorScheme.onPrimary))
    ]);
  }
}

/// Legacy sheet still shares the controlled keypad; it owns no arithmetic,
/// double-tap timer, persistence, date picker, sound or haptic side effects.
class RecordingLegacyKeypad extends StatelessWidget {
  const RecordingLegacyKeypad(
      {super.key,
      required this.onDigit,
      required this.onBackspace,
      required this.onOperator,
      required this.onToggleFirst,
      required this.onToggleSecond,
      required this.onDate,
      required this.dateLabel,
      required this.timeLabel,
      required this.onFinish,
      required this.finishLabel,
      required this.doubleTapLabel,
      this.firstMultiplies = false,
      this.secondDivides = false,
      this.calculating = false,
      this.enabled = true,
      this.saving = false,
      this.continueAdding = false});
  final ValueChanged<String> onDigit, onOperator;
  final VoidCallback onBackspace,
      onToggleFirst,
      onToggleSecond,
      onDate,
      onFinish;
  final String dateLabel, finishLabel, doubleTapLabel;
  final String? timeLabel;
  final bool firstMultiplies,
      secondDivides,
      calculating,
      enabled,
      saving,
      continueAdding;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), text = Theme.of(context).textTheme;
    final dark = theme.brightness == Brightness.dark;
    final primaryText = dark ? Colors.white : const Color(0xff111827);
    final hint = dark ? Colors.white54 : const Color(0xff9ca3af);
    final keyColor = dark ? Colors.black : Colors.white;
    final secondary = dark ? const Color(0xff2c2c2e) : Colors.grey.shade100;
    final disabled = dark ? const Color(0xff1c1c1e) : Colors.grey.shade300;
    Widget key(Widget child, VoidCallback? tap,
            {Color? color, VoidCallback? alternate}) =>
        Expanded(
            child: Padding(
                padding: const EdgeInsets.all(6),
                child: Material(
                    color: color ?? keyColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                        onTap: tap,
                        onDoubleTap: alternate,
                        onLongPress: alternate,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                            height: 60,
                            child: Center(
                                child: FittedBox(
                                    fit: BoxFit.scaleDown, child: child)))))));
    Widget digit(String value) => key(
        Text(value,
            style: text.titleMedium?.copyWith(
                color: primaryText, fontSize: 18, fontWeight: FontWeight.w600)),
        () => onDigit(value));
    Widget operator(
        String first, String second, bool active, VoidCallback toggle) {
      TextStyle style(bool current) =>
          (text.titleMedium ?? const TextStyle()).copyWith(
              color: current ? primaryText : hint,
              fontSize: current ? 18 : 14,
              fontWeight: FontWeight.w600);
      return key(
          Text.rich(TextSpan(children: [
            TextSpan(text: first, style: style(!active)),
            TextSpan(
                text: '/',
                style: style(false).copyWith(fontWeight: FontWeight.w400)),
            TextSpan(text: second, style: style(active))
          ])),
          () => onOperator(active ? second : first),
          color: secondary, alternate: () {
        toggle();
        onOperator(active ? first : second);
      });
    }

    final finishColor = enabled ? Colors.white : hint;
    final finish = saving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
        : calculating
            ? Text('=',
                style: TextStyle(
                    color: finishColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w700))
            : continueAdding
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(finishLabel,
                        style: TextStyle(
                            color: finishColor,
                            fontSize: 15,
                            height: 1.1,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(doubleTapLabel,
                        style: TextStyle(
                            color: enabled ? Colors.white70 : hint,
                            fontSize: 9,
                            height: 1,
                            fontWeight: FontWeight.w500))
                  ])
                : Text(finishLabel,
                    style: TextStyle(
                        color: finishColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700));
    return Column(children: [
      Row(children: [
        digit('7'),
        digit('8'),
        digit('9'),
        key(
            timeLabel == null
                ? Text(dateLabel,
                    style: text.labelMedium?.copyWith(
                        color: primaryText, fontWeight: FontWeight.w600))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(dateLabel,
                        style: text.labelSmall?.copyWith(
                            color: primaryText, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(timeLabel!,
                        style: text.labelSmall?.copyWith(
                            color: hint, fontWeight: FontWeight.w500))
                  ]),
            onDate,
            color: secondary)
      ]),
      const SizedBox(height: 2),
      Row(children: [
        digit('4'),
        digit('5'),
        digit('6'),
        operator('+', '×', firstMultiplies, onToggleFirst)
      ]),
      const SizedBox(height: 2),
      Row(children: [
        digit('1'),
        digit('2'),
        digit('3'),
        operator('-', '÷', secondDivides, onToggleSecond)
      ]),
      const SizedBox(height: 2),
      Row(children: [
        digit('.'),
        digit('0'),
        key(Icon(Icons.backspace_outlined, color: primaryText), onBackspace),
        key(finish, enabled ? onFinish : null,
            color: enabled ? theme.colorScheme.primary : disabled)
      ])
    ]);
  }
}

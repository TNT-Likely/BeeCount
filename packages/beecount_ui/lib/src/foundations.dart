import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../beecount_ui.dart';

abstract final class BeeUiTokens {
  static const pageInset = 17.0;
  static const cardRadius = 22.0;
  static const controlRadius = 13.0;
  static const buttonRadius = 15.0;
  static const sheetRadius = 25.0;
  static const touchTarget = 44.0;
  static const spaces = [4.0, 6.0, 8.0, 12.0, 16.0, 20.0, 24.0, 32.0];
}

/// Theme is assembled by the host; semantic tag/finance colors stay independent.
ThemeData beeTheme(
    {Brightness brightness = Brightness.light,
    Color accent = const Color(0xfffacb16)}) {
  final cards = BeeCardTheme.fromBrightness(brightness);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
          surface: cards.surface,
          outlineVariant: cards.divider,
          onSurface: brightness == Brightness.light
              ? const Color(0xff262829)
              : const Color(0xffe5e7eb),
          primary: accent,
          onPrimary:
              ThemeData.estimateBrightnessForColor(accent) == Brightness.light
                  ? const Color(0xff262829)
                  : Colors.white);
  return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: cards.canvas,
      appBarTheme: AppBarTheme(
          backgroundColor: cards.canvas, surfaceTintColor: Colors.transparent),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cards.surface,
          indicatorColor: accent.withValues(alpha: .16)),
      extensions: [cards],
      dividerColor: cards.divider,
      dividerTheme: DividerThemeData(color: cards.divider, thickness: .6),
      inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          floatingLabelStyle:
              TextStyle(color: Color.lerp(accent, scheme.onSurface, .6)),
          filled: true,
          fillColor: cards.soft,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none)),
      textTheme: ThemeData(brightness: brightness)
          .textTheme
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface));
}

enum BeeButtonKind { primary, secondary, quiet, danger }

class BeeButton extends StatelessWidget {
  const BeeButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.kind = BeeButtonKind.primary,
      this.loading = false,
      this.compact = false});
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final BeeButtonKind kind;
  final bool loading, compact;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = switch (kind) {
      BeeButtonKind.primary => scheme.primary,
      BeeButtonKind.secondary => BeeCardTheme.of(context).soft,
      BeeButtonKind.quiet => Colors.transparent,
      BeeButtonKind.danger => scheme.errorContainer
    };
    final fg = switch (kind) {
      BeeButtonKind.primary => scheme.onPrimary,
      BeeButtonKind.danger => scheme.onErrorContainer,
      _ => scheme.onSurface
    };
    return Semantics(
        liveRegion: loading,
        child: FilledButton(
            onPressed: loading ? null : onPressed,
            style: FilledButton.styleFrom(
                backgroundColor: bg,
                foregroundColor: fg,
                minimumSize: const Size(44, 44),
                disabledBackgroundColor:
                    loading ? bg : BeeCardTheme.of(context).soft,
                disabledForegroundColor:
                    loading ? fg : scheme.onSurface.withValues(alpha: .35),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: compact ? 11 : 13, fontWeight: FontWeight.w500),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (loading)
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else if (icon != null)
                icon!,
              if (loading || icon != null) const SizedBox(width: 7),
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ])));
  }
}

class BeeField extends StatelessWidget {
  const BeeField(
      {super.key,
      required this.label,
      this.controller,
      this.hint,
      this.helper,
      this.error,
      this.enabled = true,
      this.obscure = false,
      this.onChanged,
      this.keyboardType,
      this.maxLength,
      this.maxLines = 1,
      this.readOnly = false,
      this.focusNode,
      this.prefixIcon,
      this.suffixIcon,
      this.validator,
      this.onSaved,
      this.onSubmitted,
      this.textInputAction,
      this.inputFormatters,
      this.autovalidateMode = AutovalidateMode.disabled});
  final String label;
  final TextEditingController? controller;
  final String? hint, helper, error;
  final bool enabled, obscure;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final bool readOnly;
  final FocusNode? focusNode;
  final Widget? prefixIcon, suffixIcon;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode autovalidateMode;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      child: TextFormField(
          controller: controller,
          readOnly: readOnly,
          focusNode: focusNode,
          validator: validator,
          onSaved: onSaved,
          onFieldSubmitted: onSubmitted,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          autovalidateMode: autovalidateMode,
          enabled: enabled,
          obscureText: obscure,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
              labelText: label,
              floatingLabelBehavior: FloatingLabelBehavior.always,
              labelStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              floatingLabelStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: hint,
              helperText: helper,
              errorText: error,
              filled: true,
              fillColor: BeeCardTheme.of(context).soft,
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.2)))));
}

class BeeSegment<T> {
  const BeeSegment(this.value, this.label, {this.enabled = true});
  final bool enabled;
  final T value;
  final String label;
}

class BeeSegmented<T> extends StatelessWidget {
  const BeeSegmented(
      {super.key,
      required this.items,
      required this.value,
      required this.onChanged,
      this.dense = false,
      this.scrollController});
  final List<BeeSegment<T>> items;
  final T value;
  final ValueChanged<T>? onChanged;

  /// Compact editor toolbars keep the same selection style in a 42px track.
  final bool dense;
  final ScrollController? scrollController;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        final style =
            Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 13);
        double widest = 0;
        for (final item in items) {
          final painter = TextPainter(
              text: TextSpan(text: item.label, style: style),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context))
            ..layout();
          if (painter.width > widest) widest = painter.width;
          painter.dispose();
        }
        final equal = bounds.hasBoundedWidth &&
            (widest + 24) * items.length + 8 <= bounds.maxWidth;
        Widget segment(BeeSegment<T> item) {
          final enabled = onChanged != null && item.enabled;
          return Semantics(
              selected: item.value == value,
              enabled: enabled,
              inMutuallyExclusiveGroup: true,
              child: Opacity(
                  opacity: enabled ? 1 : .45,
                  child: Material(
                      color: item.value == value
                          ? BeeCardTheme.of(context).surface
                          : Colors.transparent,
                      elevation: dense && item.value == value ? 1 : 0,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                          onTap: enabled ? () => onChanged!(item.value) : null,
                          borderRadius: BorderRadius.circular(9),
                          child: ConstrainedBox(
                              constraints:
                                  BoxConstraints(minHeight: dense ? 34 : 44),
                              child: Center(
                                  child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: dense ? 0 : 8),
                                      child: Text(item.label,
                                          style: dense
                                              ? style.copyWith(
                                                  fontWeight:
                                                      item.value == value
                                                          ? FontWeight.w500
                                                          : FontWeight.w400,
                                                  color: item.value == value
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                      : Theme.of(context)
                                                          .hintColor)
                                              : style,
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis))))))));
        }

        final row = Row(
            mainAxisSize: equal ? MainAxisSize.max : MainAxisSize.min,
            children: items
                .map((item) => equal
                    ? Expanded(child: segment(item))
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: bounds.hasBoundedWidth
                                ? bounds.maxWidth - 8
                                : double.infinity),
                        child: IntrinsicWidth(child: segment(item))))
                .toList());
        return DecoratedBox(
            decoration: BoxDecoration(
                color: BeeCardTheme.of(context).soft,
                borderRadius: BorderRadius.circular(13)),
            child: Padding(
                padding: const EdgeInsets.all(4),
                child: equal
                    ? row
                    : SingleChildScrollView(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        child: row)));
      });
}

class BeeMenuRow extends StatelessWidget {
  const BeeMenuRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.leading,
      this.trailing,
      this.onTap,
      this.onLongPress,
      this.selected = false,
      this.danger = false,
      this.divider = false});
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap, onLongPress;
  final bool selected, danger, divider;
  @override
  Widget build(BuildContext context) => Semantics(
      container: true,
      selected: selected,
      child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
              constraints: const BoxConstraints(minHeight: 53),
              decoration: BoxDecoration(
                  border: divider
                      ? Border(
                          bottom: BorderSide(
                              color: Theme.of(context).dividerColor, width: .6))
                      : null),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Row(children: [
                if (leading != null) ...[
                  SizedBox(width: 28, child: leading!),
                  const SizedBox(width: 10)
                ],
                Expanded(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              color: danger
                                  ? Theme.of(context).colorScheme.error
                                  : null)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).hintColor)),
                    ])),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else if (selected)
                  const BeeLineIcon('Check', size: 18)
                else if (onTap != null)
                  const BeeLineIcon('ChevronRight', size: 16),
              ]))));
}

class BeeSection extends StatelessWidget {
  const BeeSection(
      {super.key, required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
            child: Row(children: [
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              if (action != null) action!
            ])),
        child,
      ]);
}

enum BeeTone { neutral, success, warning, error, busy }

class BeeStatus extends StatelessWidget {
  const BeeStatus(
      {super.key,
      required this.label,
      this.detail,
      this.tone = BeeTone.neutral,
      this.action,
      this.icon,
      this.onDismiss,
      this.dismissLabel});
  final String label;
  final String? detail;
  final BeeTone tone;
  final Widget? action, icon;
  final VoidCallback? onDismiss;
  final String? dismissLabel;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      BeeTone.success =>
        dark ? const Color(0xff8bd4aa) : const Color(0xff38845c),
      BeeTone.warning =>
        dark ? const Color(0xfff5d580) : const Color(0xff88620c),
      BeeTone.error => dark ? const Color(0xffffb3b3) : const Color(0xffb54242),
      _ => Theme.of(context).colorScheme.onSurface
    };
    return Semantics(
        liveRegion: true,
        child: Row(children: [
          if (icon != null)
            icon!
          else if (tone == BeeTone.busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            BeeLineIcon(
                switch (tone) {
                  BeeTone.success => 'CircleCheck',
                  BeeTone.error => 'CircleAlert',
                  _ => 'Info'
                },
                color: color,
                size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        height: 1.5)),
                if (detail != null)
                  Text(detail!,
                      style: TextStyle(
                          fontSize: 11, color: Theme.of(context).hintColor))
              ])),
          if (action != null) action!,
          if (onDismiss != null)
            BeeIconButton(
                label: dismissLabel ??
                    MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const BeeLineIcon('X', size: 16),
                onPressed: onDismiss),
        ]));
  }
}

class BeeEmptyState extends StatelessWidget {
  const BeeEmptyState(
      {super.key, required this.title, this.message, this.icon, this.action});
  final String title;
  final String? message;
  final Widget? icon, action;
  @override
  Widget build(BuildContext context) {
    final content = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          icon ?? const BeeLineIcon('ReceiptText', size: 36),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Theme.of(context).hintColor, fontSize: 12))
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ]));
    return LayoutBuilder(builder: (context, constraints) {
      if (!constraints.hasBoundedHeight) return content;
      return SingleChildScrollView(
          child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(child: content)));
    });
  }
}

class BeeProgress extends StatelessWidget {
  const BeeProgress(
      {super.key, required this.value, required this.label, this.trailing});
  final double? value;
  final String label;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Column(children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 12))
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: value == null
                ? null
                : value!.isFinite
                    ? value!.clamp(0, 1)
                    : 0,
            borderRadius: BorderRadius.circular(4),
            minHeight: 5)
      ]);
}

class BeeSheet extends StatelessWidget {
  const BeeSheet(
      {super.key, required this.title, required this.child, this.footer});
  final String title;
  final Widget child;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 10, 20, 12 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: Container(
                        width: 32,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(2)))),
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))),
                  CloseButton()
                ]),
                Flexible(child: child),
                if (footer != null) ...[const SizedBox(height: 12), footer!],
              ])));
}

Future<T?> showBeeSheet<T>(BuildContext context,
    {required String title, required Widget child, Widget? footer}) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: BeeCardTheme.of(context).surface,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => BeeSheet(title: title, footer: footer, child: child));
}

/// The host keeps the selected value; a sheet can hold a draft until Confirm.
class BeeWheel<T> extends StatefulWidget {
  const BeeWheel(
      {super.key,
      required this.values,
      required this.value,
      required this.label,
      required this.onChanged});
  final List<T> values;
  final T value;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  @override
  State<BeeWheel<T>> createState() => _BeeWheelState<T>();
}

class _BeeWheelState<T> extends State<BeeWheel<T>> {
  late FixedExtentScrollController controller;
  int get index => widget.values.isEmpty
      ? 0
      : widget.values.indexOf(widget.value).clamp(0, widget.values.length - 1);
  @override
  void initState() {
    super.initState();
    controller = FixedExtentScrollController(initialItem: index);
  }

  bool _syncing = false;
  @override
  void didUpdateWidget(covariant BeeWheel<T> old) {
    super.didUpdateWidget(old);
    if (widget.values.isNotEmpty &&
        controller.hasClients &&
        controller.selectedItem != index) {
      _syncing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (controller.hasClients) controller.jumpToItem(index);
        _syncing = false;
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    if (!controller.hasClients || widget.values.isEmpty) return;
    final target =
        (controller.selectedItem + delta).clamp(0, widget.values.length - 1);
    controller.animateToItem(target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
        curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) => widget.values.isEmpty
      ? const SizedBox.shrink()
      : SizedBox(
          height: 220,
          child: Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _move(1);
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    _move(-1);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: CupertinoPicker(
                  scrollController: controller,
                  itemExtent: 44,
                  onSelectedItemChanged: (i) {
                    if (!_syncing && widget.values[i] != widget.value) {
                      widget.onChanged(widget.values[i]);
                    }
                  },
                  children: widget.values
                      .asMap()
                      .entries
                      .map((e) => GestureDetector(
                          onTap: () => controller.animateToItem(e.key,
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 150),
                              curve: Curves.easeOut),
                          child: Center(
                              child: Text(widget.label(e.value),
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)))))
                      .toList())));
}

class BeeNavItem {
  const BeeNavItem({required this.label, required this.icon});
  final String label;
  final Widget icon;
}

class BeeBottomBar extends StatelessWidget {
  const BeeBottomBar(
      {super.key,
      required this.items,
      required this.index,
      required this.onChanged,
      this.onRecordLongPress});
  final List<BeeNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback? onRecordLongPress;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 6, 17, 8),
          child: Material(
              color: BeeCardTheme.of(context).surface,
              borderRadius: BorderRadius.circular(30),
              child: Row(
                  children: items
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                          child: Semantics(
                              selected: e.key == index,
                              child: InkWell(
                                  onTap: () => onChanged(e.key),
                                  onLongPress: e.key == items.length ~/ 2
                                      ? onRecordLongPress
                                      : null,
                                  borderRadius: BorderRadius.circular(28),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            e.value.icon,
                                            const SizedBox(height: 2),
                                            Text(e.value.label,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: e.key == index
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : null))
                                          ]))))))
                      .toList()))));
}

/// Shared by the real App and component previews; the source keeps platform typography.
ThemeData applyBeeCardTheme(ThemeData source) {
  final cards = BeeCardTheme.fromBrightness(source.brightness);
  final contrast =
      ThemeData.estimateBrightnessForColor(source.colorScheme.primary) ==
              Brightness.light
          ? const Color(0xff25282c)
          : Colors.white;
  return source.copyWith(
    scaffoldBackgroundColor: cards.canvas,
    dividerColor: cards.divider,
    dividerTheme:
        source.dividerTheme.copyWith(color: cards.divider, thickness: .6),
    extensions: [
      ...source.extensions.values.where((e) => e is! BeeCardTheme),
      cards
    ],
    colorScheme: source.colorScheme.copyWith(
        surface: cards.surface,
        onPrimary: contrast,
        outlineVariant: cards.divider),
    appBarTheme: source.appBarTheme.copyWith(
        backgroundColor: cards.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: source.colorScheme.primary,
            foregroundColor: contrast,
            minimumSize: const Size(44, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)))),
    cardTheme: source.cardTheme.copyWith(
        color: cards.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
    dialogTheme: source.dialogTheme.copyWith(
        backgroundColor: cards.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
  );
}

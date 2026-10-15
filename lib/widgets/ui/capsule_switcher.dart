import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../styles/tokens.dart';

/// 胶囊选项配置
class CapsuleOption<T> {
  final T value;
  final String label;
  final VoidCallback? onTap; // 点击箭头的回调
  final bool showArrow;

  const CapsuleOption({
    required this.value,
    required this.label,
    this.onTap,
    this.showArrow = false,
  });
}

/// 通用单选切换器：日间黑色选中胶囊、等宽选项与可访问的选中状态。
///
/// 标签能完整放下时等宽铺满；窄屏或大字号时横向滚动，不截断标签。
/// 由调用方持有选中值，组件不承载筛选业务。
class CapsuleSwitcher<T> extends StatelessWidget {
  final T selectedValue;
  final List<CapsuleOption<T>> options;
  final ValueChanged<T> onChanged;
  final Color? backgroundColor;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? unselectedTextColor;
  final double height;
  final BorderRadius? borderRadius;

  const CapsuleSwitcher({
    super.key,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    this.backgroundColor,
    this.selectedBackgroundColor,
    this.selectedTextColor,
    this.unselectedTextColor,
    this.height = 44,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final bg = backgroundColor ?? BeeTokens.surfaceCapsule(context);
    final selectedBg = selectedBackgroundColor ??
        (BeeTokens.isDark(context) ? BeeTokens.primary(context) : Colors.black);
    final selectedFg = selectedTextColor ?? BeeTokens.textOnColor(selectedBg);
    final unselectedFg =
        unselectedTextColor ?? BeeTokens.textPrimary(context);
    final textStyle = (Theme.of(context).textTheme.bodyMedium ??
            const TextStyle(fontSize: 14))
        .copyWith(fontWeight: FontWeight.w600);
    final textScaler = MediaQuery.textScalerOf(context);
    final widths = <double>[];
    var textHeight = 0.0;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: textStyle),
        textDirection: Directionality.of(context),
        textScaler: textScaler,
      )..layout();
      widths.add(painter.width.ceilToDouble() +
          BeeDimens.p12 * 2 +
          (option.showArrow && option.onTap != null ? 22 : 0));
      textHeight = math.max(textHeight, painter.height);
      painter.dispose();
    }
    final controlHeight = math.max(height, textHeight + BeeDimens.p16 + 6);
    final radius = borderRadius ?? BorderRadius.circular(controlHeight / 2);
    final segmentRadius = BorderRadius.circular((controlHeight - 6) / 2);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    Widget buildSegment(CapsuleOption<T> option) {
      final selected = selectedValue == option.value;
      final fg = selected ? selectedFg : unselectedFg;
      return Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedContainer(
          duration: duration,
          height: controlHeight - 6,
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: segmentRadius,
          ),
          child: Material(
            type: MaterialType.transparency,
            borderRadius: segmentRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: segmentRadius,
              hoverColor: BeeTokens.surfaceHover(context),
              focusColor: BeeTokens.surfaceHover(context),
              onTap: () => onChanged(option.value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: BeeDimens.p12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(option.label,
                        maxLines: 1, style: textStyle.copyWith(color: fg)),
                    if (option.showArrow && option.onTap != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: option.onTap,
                        borderRadius: BorderRadius.circular(BeeDimens.radius12),
                        child: Icon(Icons.arrow_drop_down, size: 18, color: fg),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final equalWidth = constraints.hasBoundedWidth &&
          widths.reduce(math.max) * options.length +
                  4 * (options.length - 1) +
                  6 <=
              constraints.maxWidth;
      final children = <Widget>[
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          if (equalWidth)
            Expanded(child: buildSegment(options[i]))
          else
            SizedBox(width: widths[i], child: buildSegment(options[i])),
        ],
      ];
      final row = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      );
      return equalWidth
          ? row
          : ClipRRect(
              borderRadius: radius,
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: row),
            );
    });
  }
}

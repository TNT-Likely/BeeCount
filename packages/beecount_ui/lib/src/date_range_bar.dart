import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../beecount_ui.dart';

/// A compact visual range with full-sized controls. Dates remain App-owned.
class BeeDateRangeBar extends StatelessWidget {
  const BeeDateRangeBar({
    super.key,
    required this.label,
    required this.onChoose,
    this.onPrevious,
    this.onNext,
    this.previousLabel,
    this.nextLabel,
    this.trailingLabel,
  });
  final String label;
  final VoidCallback? onChoose, onPrevious, onNext;
  final String? previousLabel, nextLabel, trailingLabel;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).hintColor;
    Widget step(String label, String icon, VoidCallback? action) => Semantics(
        label: label,
        button: true,
        child: SizedBox(
            width: 34,
            height: 44,
            child: IconButton(
                tooltip: label,
                padding: EdgeInsets.zero,
                onPressed: action,
                icon: BeeLineIcon(icon, size: 14, color: muted))));
    final paging = previousLabel != null || nextLabel != null;
    return SizedBox(
        height: 44,
        child: Row(children: [
          if (paging) step(previousLabel ?? '', 'ChevronLeft', onPrevious),
          Expanded(
              child: TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      splashFactory: NoSplash.splashFactory),
                  onPressed: onChoose,
                  child: Row(
                      mainAxisAlignment: paging
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BeeLineIcon('CalendarDays', size: 14, color: muted),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12))),
                        const SizedBox(width: 5),
                        BeeLineIcon('ChevronDown', size: 11, color: muted),
                      ]))),
          if (paging) step(nextLabel ?? '', 'ChevronRight', onNext),
          if (!paging && trailingLabel != null)
            Text(trailingLabel!, style: TextStyle(fontSize: 9, color: muted)),
        ]));
  }
}

/// A native scrolling year/month selector; callers own the chosen period.
class BeeYearMonthWheel extends StatefulWidget {
  const BeeYearMonthWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.showMonth = true,
    this.firstYear = 2000,
    this.lastYear = 2100,
  });
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool showMonth;
  final int firstYear, lastYear;
  @override
  State<BeeYearMonthWheel> createState() => _BeeYearMonthWheelState();
}

class _BeeYearMonthWheelState extends State<BeeYearMonthWheel> {
  late int year = widget.value.year.clamp(widget.firstYear, widget.lastYear);
  late int month = widget.value.month;
  late final yearController =
      FixedExtentScrollController(initialItem: year - widget.firstYear);
  late final monthController =
      FixedExtentScrollController(initialItem: month - 1);
  @override
  void dispose() {
    yearController.dispose();
    monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget wheel(FixedExtentScrollController controller, int count,
            String Function(int) label, ValueChanged<int> change) =>
        Expanded(
            child: CupertinoPicker.builder(
                scrollController: controller,
                itemExtent: 36,
                childCount: count,
                selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                    background:
                        BeeCardTheme.of(context).soft.withValues(alpha: .65)),
                onSelectedItemChanged: change,
                itemBuilder: (context, index) => Center(
                    child: Text(label(index),
                        style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface)))));
    return SizedBox(
        height: 180,
        child: Row(children: [
          wheel(yearController, widget.lastYear - widget.firstYear + 1,
              (index) => '${widget.firstYear + index}', (index) {
            year = widget.firstYear + index;
            widget.onChanged(DateTime(year, month));
          }),
          if (widget.showMonth)
            wheel(monthController, 12, (index) => '${index + 1}', (index) {
              month = index + 1;
              widget.onChanged(DateTime(year, month));
            }),
        ]));
  }
}

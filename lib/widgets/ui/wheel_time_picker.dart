import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

class WheelTimePicker extends StatefulWidget {
  final TimeOfDay initial;

  const WheelTimePicker({
    super.key,
    required this.initial,
  });

  @override
  State<WheelTimePicker> createState() => _WheelTimePickerState();
}

Future<TimeOfDay?> showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: BeeTokens.surfaceElevated(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (ctx) => WheelTimePicker(
      initial: initial,
    ),
  );
}

class _WheelTimePickerState extends State<WheelTimePicker> {
  late int hour;
  late int minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    hour = widget.initial.hour;
    minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = BeeTokens.isDark(context);
    return Container(
      decoration: BoxDecoration(
        color: BeeTokens.surfaceElevated(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? BeeTokens.border(context)
                        : const Color(0xFFE5E5E5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      AppLocalizations.of(context)!.commonCancel,
                      style: TextStyle(
                        fontSize: 16,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.commonSelectTime,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context)
                          .pop(TimeOfDay(hour: hour, minute: minute));
                    },
                    child: Text(
                      AppLocalizations.of(context)!.commonOk,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 时间选择器
            SizedBox(
              height: 216,
              child: Row(
                children: [
                  // 小时选择器
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _hourCtrl,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          hour = index;
                        });
                      },
                      children: List.generate(24, (index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 20,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // 分隔符
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),

                  // 分钟选择器
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: _minuteCtrl,
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          minute = index;
                        });
                      },
                      children: List.generate(60, (index) {
                        return Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 20,
                              color: BeeTokens.textPrimary(context),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

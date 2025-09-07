import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:beecount/widgets/wheel_date_picker.dart';

typedef AmountEditorResult = ({double amount, String? note, DateTime date});

class AmountEditorSheet extends StatefulWidget {
  final String categoryName; // 仅用于上层提交，不在UI展示
  final DateTime initialDate;
  final double? initialAmount;
  final String? initialNote;
  final ValueChanged<AmountEditorResult> onSubmit;
  const AmountEditorSheet({
    super.key,
    required this.categoryName,
    required this.initialDate,
    this.initialAmount,
    this.initialNote,
    required this.onSubmit,
  });

  @override
  State<AmountEditorSheet> createState() => _AmountEditorSheetState();
}

class _AmountEditorSheetState extends State<AmountEditorSheet> {
  late String _amountStr;
  late DateTime _date;
  final TextEditingController _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _amountStr = (widget.initialAmount ?? 0).toStringAsFixed(2);
    _noteCtrl.text = widget.initialNote ?? '';
  }

  void _append(String s) {
    setState(() {
      if (s == '.') {
        if (_amountStr.contains('.')) return;
      }
      // 限制两位小数
      if (_amountStr.contains('.')) {
        final dot = _amountStr.indexOf('.');
        final decimals = _amountStr.length - dot - 1;
        if (s != '.' && decimals >= 2) return;
      }
      if (_amountStr == '0.00' || _amountStr == '0') {
        _amountStr = s == '.' ? '0.' : s;
      } else {
        _amountStr += s;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_amountStr.isEmpty) return;
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      if (_amountStr.isEmpty) _amountStr = '0';
    });
  }

  void _toggleSign(bool isAdd) {
    // 这里仅作为“+/-”功能位，实际金额符号在保存时按照类型决定
    // 占位：可加自定义逻辑
  }

  // _setToday 移除，改为点击日历按钮选择日期

  void _pickDate() async {
    final res = await showWheelDatePicker(
      context,
      initial: _date,
      mode: WheelDatePickerMode.ymd,
      maxDate: DateTime.now(),
    );
    if (res != null) setState(() => _date = res);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    double parsed() => double.tryParse(_amountStr) ?? 0.0;

    Widget keyBtn(String label, {Color? bg, Color? fg, VoidCallback? onTap}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              height: 60,
              alignment: Alignment.center,
              child: Text(
                label,
                style: text.titleMedium?.copyWith(
                  color: fg ?? Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      );
    }

    String fmtDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 金额单独一行（右对齐）
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                parsed().toStringAsFixed(2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // 日期单独一行（今天 显示“今天”，否则显示 yyyy/M/d）
            Builder(builder: (ctx) {
              final now = DateTime.now();
              final isToday = _date.year == now.year &&
                  _date.month == now.month &&
                  _date.day == now.day;
              final label = isToday ? '今天' : fmtDate(_date);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickDate,
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              size: 18, color: Colors.black87),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: text.titleMedium?.copyWith(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right,
                              color: Colors.black45),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            // 备注单独一行
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: '备注…',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            // 数字键盘
            LayoutBuilder(builder: (ctx, c) {
              final w = (c.maxWidth) / 4;
              return Column(
                children: [
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('7', onTap: () => _append('7'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('8', onTap: () => _append('8'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('9', onTap: () => _append('9'))),
                    SizedBox(
                      width: w,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _backspace,
                            child: const SizedBox(
                              height: 60,
                              child:
                                  Center(child: Icon(Icons.backspace_outlined)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('4', onTap: () => _append('4'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('5', onTap: () => _append('5'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('6', onTap: () => _append('6'))),
                    SizedBox(
                      width: w,
                      child: keyBtn('+',
                          fg: primary,
                          bg: Colors.grey[100],
                          onTap: () => _toggleSign(true)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('1', onTap: () => _append('1'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('2', onTap: () => _append('2'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('3', onTap: () => _append('3'))),
                    SizedBox(
                      width: w,
                      child: keyBtn('-',
                          fg: primary,
                          bg: Colors.grey[100],
                          onTap: () => _toggleSign(false)),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('.', onTap: () => _append('.'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('0', onTap: () => _append('0'))),
                    SizedBox(
                      width: w,
                      child: const SizedBox.shrink(),
                    ),
                    SizedBox(
                      width: w,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Material(
                          color: primary,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onSubmit((
                              amount: parsed(),
                              note: _noteCtrl.text.isEmpty
                                  ? null
                                  : _noteCtrl.text,
                              date: _date,
                            )),
                            child: const SizedBox(
                              height: 60,
                              child: Center(
                                child: Text(
                                  '完成',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              );
            })
          ],
        ),
      ),
    );
  }
}

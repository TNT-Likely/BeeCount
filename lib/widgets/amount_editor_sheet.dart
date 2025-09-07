import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:beecount/widgets/wheel_date_picker.dart';

typedef AmountEditorResult = ({double amount, String? note, DateTime date});

class AmountEditorSheet extends StatefulWidget {
  final String categoryName;
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

  void _setToday() {
    setState(() => _date = DateTime.now());
  }

  void _pickDate() async {
    final res = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) =>
          WheelDatePicker(initial: _date, mode: WheelDatePickerMode.ymd),
    );
    if (res != null) setState(() => _date = res);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final text = Theme.of(context).textTheme;
    double parsed() => double.tryParse(_amountStr) ?? 0.0;

    Widget keyBtn(String label, {Color? bg, Color? fg, VoidCallback? onTap}) {
      return InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg ?? Colors.white,
            border: Border.all(color: Colors.black12.withOpacity(0.06)),
          ),
          child: Text(label,
              style: text.titleMedium
                  ?.copyWith(color: fg ?? Colors.black87, fontSize: 18)),
        ),
      );
    }

    String fmtDate(DateTime d) {
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部信息行：分类与日期
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.categoryName,
                    style:
                        text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(fmtDate(_date)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 标题与金额行
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: '备注： 点击填写备注',
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Color(0xFFF7F7F7),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  parsed().toStringAsFixed(2),
                  style:
                      text.displaySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                      child: keyBtn('今天', onTap: _setToday),
                    ),
                  ]),
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
                      child: keyBtn('+', onTap: () => _toggleSign(true)),
                    ),
                  ]),
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
                      child: keyBtn('-', onTap: () => _toggleSign(false)),
                    ),
                  ]),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('.', onTap: () => _append('.'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('0', onTap: () => _append('0'))),
                    SizedBox(
                      width: w,
                      child: InkWell(
                        onTap: _backspace,
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.black12.withOpacity(0.06)),
                          ),
                          child: const Icon(Icons.backspace_outlined),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: InkWell(
                        onTap: () => widget.onSubmit((
                          amount: parsed(),
                          note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                          date: _date,
                        )),
                        child: Container(
                          height: 56,
                          alignment: Alignment.center,
                          color: primary,
                          child: const Text('完成',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16)),
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

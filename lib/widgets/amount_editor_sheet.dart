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

    String fmtDate(DateTime d) {
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd';
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    foregroundColor: Colors.black87,
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.calendar_month, size: 16),
                  label: Text(
                    fmtDate(_date),
                    style:
                        text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
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
                    decoration: InputDecoration(
                      hintText: '备注…',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  parsed().toStringAsFixed(2),
                  style: text.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
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
                      child: keyBtn('今天',
                          fg: primary, bg: Colors.grey[100], onTap: _setToday),
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

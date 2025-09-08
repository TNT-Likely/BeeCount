import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:beecount/widgets/wheel_date_picker.dart';
import '../styles/colors.dart';

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
  final bool _negative = false; // 显示用途，仅影响UI，不改变保存逻辑
  final TextEditingController _noteCtrl = TextEditingController();
  // 运算缓存：支持简单 + / - 键入累计
  double _acc = 0;
  String _op = '+'; // 最近一次运算符

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _amountStr = (widget.initialAmount ?? 0).toStringAsFixed(0);
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
      // 去除前导 0
      if (_amountStr == '0' && s != '.') {
        _amountStr = s;
      } else if (_amountStr == '-0' && s != '.') {
        _amountStr = '-$s';
      } else {
        _amountStr += s;
      }
    });
    SystemSound.play(SystemSoundType.click);
  }

  void _backspace() {
    setState(() {
      if (_amountStr.isEmpty) return;
      _amountStr = _amountStr.substring(0, _amountStr.length - 1);
      if (_amountStr.isEmpty) _amountStr = '0';
    });
    SystemSound.play(SystemSoundType.click);
  }

  // 旧 _toggleSign 已废弃，符号由类别含义决定

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

    void applyOp(String op) {
      final cur = parsed();
      if (_op == '+') {
        _acc += cur;
      } else if (_op == '-') {
        _acc -= cur;
      }
      _op = op;
      _amountStr = '0';
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
      setState(() {});
    }

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
                  color: fg ?? BeeColors.primaryText,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 运算状态符号（+ / -），更直观地展示当前累加/累减状态
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _op == '-' ? '−' : '+',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: BeeColors.primaryText,
                    ),
                  ),
                ),
                Text(
                  (_negative ? '-' : '') +
                      (() {
                        final cur = parsed();
                        final total = _op == '+' || _op == '-'
                            ? (_acc + (_op == '+' ? cur : -cur))
                            : cur;
                        // 不显示多余 0
                        final s = total.toStringAsFixed(2);
                        final r1 = s.contains('.')
                            ? s.replaceFirst(RegExp(r'0+$'), '')
                            : s;
                        final r2 = r1.endsWith('.')
                            ? r1.substring(0, r1.length - 1)
                            : r1;
                        return r2.isEmpty ? '0' : r2;
                      })(),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
              Widget dateKey() => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          SystemSound.play(SystemSoundType.click);
                          _pickDate();
                        },
                        child: SizedBox(
                          height: 60,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fmtDate(_date),
                                  style: text.labelMedium?.copyWith(
                                      color: BeeColors.primaryText,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
              Widget closeKey() => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _backspace,
                        child: const SizedBox(
                          height: 60,
                          child: Center(
                              child: Icon(Icons.close_rounded,
                                  color: BeeColors.primaryText)),
                        ),
                      ),
                    ),
                  );
              Widget doneKey() => Padding(
                    padding: const EdgeInsets.all(6),
                    child: Material(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // 计算总额（包含最后一段）
                          final cur = parsed();
                          double total = _acc;
                          if (_op == '+')
                            total += cur;
                          else if (_op == '-')
                            total -= cur;
                          else
                            total = cur;
                          HapticFeedback.lightImpact();
                          SystemSound.play(SystemSoundType.click);
                          widget.onSubmit((
                            amount: total.abs(), // 始终正数
                            note:
                                _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                            date: _date,
                          ));
                        },
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
                  );

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
                    SizedBox(width: w, child: dateKey()),
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
                            bg: Colors.grey[100], onTap: () => applyOp('+'))),
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
                            bg: Colors.grey[100], onTap: () => applyOp('-'))),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    SizedBox(
                        width: w,
                        child: keyBtn('.', onTap: () => _append('.'))),
                    SizedBox(
                        width: w,
                        child: keyBtn('0', onTap: () => _append('0'))),
                    SizedBox(width: w, child: closeKey()),
                    SizedBox(width: w, child: doneKey()),
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

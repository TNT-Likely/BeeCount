import 'package:flutter/material.dart';
import 'dart:async';

/// 打字机效果文本组件
///
/// 逐字显示文本,模拟打字机效果
class TypewriterText extends StatefulWidget {
  /// 要显示的完整文本
  final String text;

  /// 每个字符的显示间隔
  final Duration speed;

  /// 文本样式
  final TextStyle? style;

  /// 完成回调
  final VoidCallback? onComplete;

  /// 文本更新回调（每次显示新字符时调用）
  final VoidCallback? onTextChange;

  /// 是否启用动画(false则立即显示完整文本)
  final bool animate;

  const TypewriterText({
    super.key,
    required this.text,
    this.speed = const Duration(milliseconds: 50),
    this.style,
    this.onComplete,
    this.onTextChange,
    this.animate = true,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTyping();
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // 文本变化,重新开始
      _timer?.cancel();
      _currentIndex = 0;
      _displayedText = '';
      _startTyping();
    }
  }

  void _startTyping() {
    if (widget.text.isEmpty) {
      _displayedText = '';
      widget.onComplete?.call();
      return;
    }

    // 如果不启用动画,立即显示完整文本
    if (!widget.animate) {
      setState(() {
        _displayedText = widget.text;
        _currentIndex = widget.text.length;
      });
      widget.onComplete?.call();
      return;
    }

    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText = widget.text.substring(0, _currentIndex + 1);
            _currentIndex++;
          });
          // 每次文本更新时通知父组件
          widget.onTextChange?.call();
        }
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText,
      style: widget.style,
    );
  }
}

import 'package:flutter/widgets.dart';

typedef SizeChanged = void Function(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final SizeChanged onChange;
  const MeasureSize({super.key, required this.child, required this.onChange});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = context.size;
      if (size != null && _oldSize != size) {
        _oldSize = size;
        widget.onChange(size);
      }
    });
    return widget.child;
  }
}

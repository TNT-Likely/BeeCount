import 'package:flutter/material.dart';

/// A print surface, intentionally independent of the application's brightness.
/// Business content, export sizing, imagery and I/O belong to the caller.
class BeePaper extends StatelessWidget {
  const BeePaper(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.tearEdge = false,
      this.radius = 0,
      this.color = const Color(0xfffffefa),
      this.borderColor = const Color(0xffe8e7dd)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool tearEdge;
  final double radius;
  final Color color, borderColor;

  static const ink = Color(0xff292d31),
      muted = Color(0xff8c8d88),
      rule = Color(0xffe8e7dd),
      soft = Color(0xfff7f7f2);

  @override
  Widget build(BuildContext context) {
    final paper = DecoratedBox(
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: tearEdge ? null : Border.all(color: borderColor)),
        child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
                style: const TextStyle(color: ink, fontSize: 24, height: 1.45),
                child: child)));
    return tearEdge
        ? ClipPath(clipper: const _PaperEdge(), child: paper)
        : paper;
  }
}

class BeePaperRule extends StatelessWidget {
  const BeePaperRule(
      {super.key, this.dashed = false, this.color = BeePaper.rule});
  final bool dashed;
  final Color color;
  @override
  Widget build(BuildContext context) => dashed
      ? LayoutBuilder(
          builder: (_, c) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                  (c.maxWidth / 8).floor().clamp(1, 1000),
                  (_) => SizedBox(
                      width: 4, height: 1, child: ColoredBox(color: color)))))
      : SizedBox(height: 1, child: ColoredBox(color: color));
}

class _PaperEdge extends CustomClipper<Path> {
  const _PaperEdge();
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 6);
    final count = (size.width / 12).round().clamp(1, 1000),
        step = size.width / count;
    for (var i = count; i > 0; i--) {
      path
        ..lineTo((i - .5) * step, size.height)
        ..lineTo((i - 1) * step, size.height - 6);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_PaperEdge oldClipper) => false;
}

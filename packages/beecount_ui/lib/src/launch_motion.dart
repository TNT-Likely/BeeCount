import 'dart:math' as math;
import 'package:flutter/material.dart';

/// One decorative stroke. It owns neither startup work nor a completion callback.
/// Reduced motion keeps the complete background visible, without running a ticker.
class BeeTrailBackdrop extends StatefulWidget {
  const BeeTrailBackdrop({super.key, required this.focalPoint});
  final Offset focalPoint;

  @override
  State<BeeTrailBackdrop> createState() => _BeeTrailBackdropState();
}

class _BeeTrailBackdropState extends State<BeeTrailBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _stroke = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));
  bool _started = false, _motionAllowed = false, _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _motionAllowed = !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context);
    if (!_motionAllowed) {
      _stroke.stop();
      _stroke.value = 1;
      _started = true;
    } else if (!_started && _foreground) {
      _started = true;
      _stroke.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _stroke.stop();
    } else if (_motionAllowed && _stroke.value < 1) {
      _stroke.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stroke.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: IgnorePointer(
          child: CustomPaint(
              painter: _TrailPainter(
                  progress: _stroke,
                  focalPoint: widget.focalPoint,
                  accent: Theme.of(context).colorScheme.primary,
                  dark: Theme.of(context).brightness == Brightness.dark),
              child: const SizedBox.expand())));
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(
      {required this.progress,
      required this.focalPoint,
      required this.accent,
      required this.dark})
      : super(repaint: progress);

  final Animation<double> progress;
  final Offset focalPoint;
  final Color accent;
  final bool dark;
  static final _trail = Path()
    ..moveTo(16, 172)
    ..cubicTo(22, 62, 146, 28, 234, 62)
    ..cubicTo(322, 96, 308, 146, 210, 170);
  static final _metric = _trail.computeMetrics().single;

  @override
  void paint(Canvas canvas, Size size) {
    final center = focalPoint + const Offset(0, 38);
    final radius = (size.width * .9).clamp(185.0, 360.0);
    final field = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(colors: [
            dark
                ? accent.withValues(alpha: .035)
                : Color.lerp(const Color(0xffe9e3d5), accent, .07)!
                    .withValues(alpha: .82),
            dark
                ? accent.withValues(alpha: .008)
                : Color.lerp(const Color(0xfff3f0e8), accent, .03)!
                    .withValues(alpha: .7),
            (dark ? accent : Color.lerp(const Color(0xfff3f0e8), accent, .03)!)
                .withValues(alpha: 0)
          ], stops: const [
            0,
            .38,
            1
          ]).createShader(field));

    final glow =
        Rect.fromCircle(center: focalPoint + const Offset(0, 56), radius: 170);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(colors: [
            accent.withValues(alpha: dark ? .02 : .04),
            accent.withValues(alpha: 0)
          ]).createShader(glow));

    final scale = size.width < 360 ? .9 : 1.0;
    canvas.save();
    canvas.translate(focalPoint.dx - 160 * scale, focalPoint.dy - 121 * scale);
    canvas.scale(scale);
    final traceColor =
        dark ? accent : Color.lerp(const Color(0xffa99457), accent, .57)!;
    final trace = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = .9
      ..color = traceColor.withValues(alpha: dark ? .08 : .2);
    for (var start = 0.0; start < _metric.length; start += 9) {
      canvas.drawPath(_metric.extractPath(start, start + 2), trace);
    }
    final value = const Cubic(.2, .5, .3, 1).transform(progress.value);
    trace
      ..strokeWidth = 1.5
      ..color = traceColor.withValues(alpha: dark ? .45 : .66);
    canvas.drawPath(_metric.extractPath(0, _metric.length * value), trace);
    if (progress.value > .12 && progress.value < .88) {
      final point =
          _metric.getTangentForOffset(_metric.length * value)!.position;
      final opacity = math.sin(progress.value * math.pi) * .8;
      canvas.drawCircle(
          point, 2.5, Paint()..color = accent.withValues(alpha: opacity));
    }
    if (progress.value >= .8) {
      canvas.drawCircle(const Offset(210, 170), 2,
          Paint()..color = accent.withValues(alpha: .5));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrailPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.focalPoint != focalPoint ||
      oldDelegate.accent != accent ||
      oldDelegate.dark != dark;
}

/// Indeterminate activity; the static arc deliberately carries no numeric value.
class BeeActivityIndicator extends StatelessWidget {
  const BeeActivityIndicator(
      {super.key, this.size = 13, this.strokeWidth = 1.5});
  final double size, strokeWidth;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
        child: SizedBox.square(
            dimension: size,
            child: reduce
                ? CustomPaint(
                    painter: _StaticActivityPainter(color, strokeWidth))
                : CircularProgressIndicator(
                    strokeWidth: strokeWidth, color: color)));
  }
}

class _StaticActivityPainter extends CustomPainter {
  const _StaticActivityPainter(this.color, this.strokeWidth);
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color.withValues(alpha: .21);
    canvas.drawOval(ring, paint);
    paint.color = color;
    canvas.drawArc(ring, -math.pi / 2, math.pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _StaticActivityPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

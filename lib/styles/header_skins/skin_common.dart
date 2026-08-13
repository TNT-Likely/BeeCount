part of '../header_skins.dart';

// ============ 动态皮肤共用基座 ============
//
// 任何「代码绘制 + 动画」的皮肤都可以用这里的构件:坐标换算、动画骨架、
// 底色/柔光画法。首批使用者是周年款(一岁星座 / 周年蛋糕)和秋日系列。
//
// 坐标体系:设计稿一律按 viewBox 0 0 300 208 出图,`_ax/_ay/_ap` 负责换算,
// 所以 painter 里可以直接照抄设计稿上的数值。
//
// 动画纪律:单 AnimationController;周期性子动画频率**取整数**(sin(t·2π·k)),
// 否则 t 从 1 回绕到 0 会跳变;不用 MaskFilter.blur(光晕一律 RadialGradient);
// RepaintBoundary 隔离;系统「减弱动态效果」时停在静态帧。
//
// 配色纪律(设计稿称「去脏五原则」):
//   1 底色高明度低饱和  2 只用两种高纯度色  3 不用半透明大色块(改线稿)
//   4 加白描边与细节线  5 留白 ≥40%

/// 设计稿坐标 → 实际画布。设计稿按 300×208 绘制,这里按比例换算,
/// 所以 painter 里可以直接照抄设计稿的数值。
double _ax(Size s, double x) => s.width * (x / 300);
double _ay(Size s, double y) => s.height * (y / 208);
Offset _ap(Size s, double x, double y) => Offset(_ax(s, x), _ay(s, y));

/// 动态皮肤的动画骨架:单 Controller + RepaintBoundary + 减弱动态效果退静态帧。
/// 各皮肤只需提供 painter 工厂与循环时长。
class _AnimSkinShell extends StatefulWidget {
  const _AnimSkinShell({
    required this.painterFor,
    this.seconds = 12,
    // ignore: unused_element_parameter
    this.staticFrame = 0.3,
  });

  final CustomPainter Function(Animation<double> anim) painterFor;
  final int seconds;

  /// 「减弱动态效果」下停住的帧(取构图完整的一刻)。
  final double staticFrame;

  @override
  State<_AnimSkinShell> createState() => _AnimSkinShellState();
}

class _AnimSkinShellState extends State<_AnimSkinShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(seconds: widget.seconds));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = widget.staticFrame;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: widget.painterFor(_c),
          child: const SizedBox.expand(),
        ),
      );
}


/// 纵向渐变底(秋日皮肤的统一底色画法)。
void _paintVerticalBase(Canvas canvas, Size size, List<Color> colors,
    [List<double>? stops]) {
  final rect = Offset.zero & size;
  canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect));
}

/// 径向柔光(替代 blur 的唯一手段)。
void _paintRadialGlow(Canvas canvas, Size size, Offset center, double radius,
    Color color, double alpha) {
  canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(center: center, radius: radius)));
}

/// 悬浮 tab 装饰的动画骨架(与 header 同一套纪律,周期更短)。
class _AnimTabShell extends StatefulWidget {
  const _AnimTabShell({
    required this.painterFor,
    this.seconds = 10,
    // ignore: unused_element_parameter
    this.staticFrame = 0.25,
  });
  final CustomPainter Function(Animation<double> anim) painterFor;
  final int seconds;
  final double staticFrame;

  @override
  State<_AnimTabShell> createState() => _AnimTabShellState();
}

class _AnimTabShellState extends State<_AnimTabShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(seconds: widget.seconds));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = widget.staticFrame;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          painter: widget.painterFor(_c),
          child: const SizedBox.expand(),
        ),
      );
}

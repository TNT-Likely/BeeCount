part of '../header_skins.dart';

// ============ 一周年皮肤:一岁星座(Constellation No.1) ============
//
// BeeCount 首个动态皮肤,纪念 2025.9.10 首版发布一周年。
// 「你的第一年被连成一个星座」:十颗星连成数字「1」,一只发光的小蜜蜂
// 拖着彗尾绕它巡航;左上一弯金色月牙,流星偶尔划过,三颗四芒星错相
// 闪烁。亮色 = 主题色底 + 白色星光;暗色 = 纯黑底 + 主题色星光。
// 设计文档:.docs/anniversary-skin/design.md
//
// 布局(v2,修复「我的」页遮挡):首页左重、我的页中央重、子页左侧标题,
// 三种布局唯一共同净空是**右上区**——星座缩小锚定右上:
// - 星座高 = clamp(h*0.30, 34, 64),任何高度完整显示;
// - 锚点:h>=150(首页/我的页级)放 (w*.75, h*.31);h<150(子页级)放
//   (w*.76, h*.47);
// - 星径 / 线宽随星座缩放(固定 pt 时小星座的光晕会融成光棒);
// - 蜜蜂路径按实际锚点动态生成;星尘密度按面积。
//
// 动画:单 AnimationController(10s repeat)驱动全部;周期性子动画的频率
// 一律取整数(sin(t·2π·k)),保证 t=1→0 回绕处无跳变。RepaintBoundary
// 隔离重绘;系统「减弱动态效果」时停在静态帧。性能:单 Painter、无
// saveLayer、无 blur(光晕全部用 RadialGradient shader)。

/// 星座「1」的十颗星:局部坐标,原点 = 星座中心,单位 = 星座高。
/// 依次为:帽 2 颗、竖列 5 颗(主星)、底座 3 颗。
const List<Offset> _kAnnivStars = [
  // 长斜帽(「1」的起笔,短了就读不出数字)
  Offset(-0.32, -0.18),
  Offset(-0.16, -0.34),
  // 竖列(主星)
  Offset(0, -0.5),
  Offset(0, -0.27),
  Offset(0, -0.04),
  Offset(0, 0.19),
  Offset(0, 0.42),
  // 底座(加宽,底盘才稳)
  Offset(-0.27, 0.5),
  Offset(0, 0.5),
  Offset(0.27, 0.5),
];

/// 竖列(主星)在 [_kAnnivStars] 中的索引区间,画大一号。
const int _kAnnivMainStarFrom = 2, _kAnnivMainStarTo = 6;

/// 减弱动态效果时停住的静态帧(蜜蜂位于环绕段中部,构图完整)。
const double _kAnnivStaticFrame = 0.62;

// 注:铭文改回设计稿的两行定位(基线 y=185/196)后,不再需要按 header 高度给
// 预算进度条让位,原来的 _kBudgetBarH / _kHeaderWithBudgetBar 两个常量随之删除。
// 首页开了预算条时铭文会被它盖住下半 —— 设计稿的排法本来如此,不再额外规避。

/// 「我的」页级 header 的高度下限。超过它就认为是那种「中间摆大头像」的高
/// header,铭文要避开正中(见 [_paintAnnivInscription])。
const double _kAnnivTallHeader = 220;

/// 三款周年皮肤共用的铭文:小十字星 + 「1st ANNIVERSARY」/「SINCE 2025.9.10」。
///
/// **两行,排在标题行右侧那块空当里**。
///
/// 位置换过三轮:设计稿排在左下角(基线 185/196),但那是 300×208 的方画布;
/// 真实 header 是 440×172 的扁条,底部整条都被「11月 / 收入 / 支出 / 结余」
/// 占着,铭文放下去就是两层字叠着。中间还试过压成一行贴底 —— 变成一条长横幅,
/// 和设计稿对不上。
///
/// header 里唯一放得下两行的空白是**账本名右缘到右上角图标之间**(实测约
/// 120pt 宽、34pt 高)。锚点按 [topInset] 算而不是按 header 高度的百分比 ——
/// 标题行是绝对定位的,header 变高时它并不跟着往下走。
///
/// **「我的」页要挪到左上。** 那一页的 header 高得多(实测约 270pt,首页只有
/// 172pt),而且正中间是个大头像 —— 照首页的横向位置排,铭文正好被头像盖掉
/// 半截。高 header 一律靠左上,那块区域在「我的」页是空的。
void _paintAnnivInscription(
    Canvas canvas, Size size, Color color, double topInset) {
  if (size.height < 40) return; // 极端矮(预览缩略图)就不画了
  // 标题行大致是 topInset+17 ~ topInset+51,两行铭文居中排进去
  final y1 = topInset + 22, y2 = y1 + 12;
  if (y2 + 10 > size.height) return; // 放不下就不画,画出去比不画难看
  final (title, sub) = _AnnivInscription.of(color);
  // 首页 172 / 我的页 270 / 子页 107(Android 状态栏矮 30 时各减 29),
  // 220 这个阈值把「我的」页单独分出来,其余机型档位都不会误判。
  final x = size.height >= _kAnnivTallHeader ? size.width * .06 : size.width * .50;
  _drawAnnivCross(canvas, Offset(x - 9, y1 + 5), 3.4, color, .7);
  title.paint(canvas, Offset(x, y1));
  sub.paint(canvas, Offset(x, y2));
}

/// 铭文的 TextPainter 按颜色缓存 —— 布局每帧都做会白烧 CPU,
/// 而颜色只有「亮/暗 × 三款皮肤」几种取值。
class _AnnivInscription {
  static final Map<Color, (TextPainter, TextPainter)> _cache = {};

  static TextPainter _line(String text, double fs, double ls, FontWeight w,
          Color color, double alpha) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fs,
            fontWeight: w,
            letterSpacing: ls,
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['Times New Roman', 'serif'],
            color: color.withValues(alpha: alpha),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// (主标题行, SINCE 行)。字号是设计稿的 9.5 / 7.4 折算到 header 纵向单位后的值。
  static (TextPainter, TextPainter) of(Color color) => _cache.putIfAbsent(
        color,
        () => (
          _line('1st ANNIVERSARY', 7.8, 1.1, FontWeight.w700, color, .88),
          _line('SINCE 2025.9.10', 6.1, 1.6, FontWeight.w400, color, .66),
        ),
      );
}

/// 四芒十字星(铭文起头用)。
void _drawAnnivCross(
    Canvas canvas, Offset c, double r, Color color, double alpha) {
  final k = r * .2;
  canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + k, c.dy - k)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx + k, c.dy + k)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - k, c.dy + k)
        ..lineTo(c.dx - r, c.dy)
        ..lineTo(c.dx - k, c.dy - k)
        ..close(),
      Paint()..color = color.withValues(alpha: alpha));
}

class _AnniversarySkin extends StatefulWidget {
  const _AnniversarySkin(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  State<_AnniversarySkin> createState() => _AnniversarySkinState();
}

class _AnniversarySkinState extends State<_AnniversarySkin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 10));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 系统「减弱动态效果」→ 停在静态帧;否则循环播放。
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = _kAnnivStaticFrame;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ConstellationPainter(widget.primary, widget.isDark, _controller,
            MediaQuery.paddingOf(context).top),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.primary, this.isDark, this.anim, this.topInset)
      : super(repaint: anim);
  final Color primary;
  final bool isDark;
  final Animation<double> anim;

  /// 状态栏高度,铭文靠它对齐标题行。
  final double topInset;

  // 蜜蜂路径按 size 缓存(锚点/星座尺寸由尺寸唯一决定),header 尺寸不变时不重建。
  Size? _cachedSize;
  ui.PathMetric? _beeMetric;

  /// 星光主色:亮色用白,暗色用略提亮的主题色。
  Color get _fg => isDark ? _lighten(primary, 0.08) : Colors.white;

  /// 月牙 / 流星 / 十字星的暖色:亮色白,暗色固定蜜金(夜空的月亮是金色的)。
  Color get _warm => isDark ? const Color(0xFFF8C91C) : Colors.white;

  /// 铭文专用色 —— **不跟 [_fg] 走**。
  ///
  /// 铭文从左下角挪到标题行右侧后,正好落在银河带最亮的一段:亮色模式下
  /// _fg 是纯白,白字压在高亮的主题色上只剩个影子。这里改用压深的主题色,
  /// 既拉开对比又不脱离配色。暗色模式底是黑夜空,沿用星光色不动。
  ///
  /// lightness 夹在 .12~.34:主题色可能很浅(浅粉)也可能本就很深(墨蓝),
  /// 单纯减一个固定值会分别「不够深」和「黑成一团」。
  Color get _inscription {
    if (isDark) return _fg;
    final h = HSLColor.fromColor(primary);
    return h.withLightness((h.lightness - .34).clamp(.12, .34)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final t = anim.value;

    // 星座是主角:占 header 高的三分之二。之前只有 30% 时「1」读不出来,
    // 而铭文居中横跨全宽又会和它抢视线 —— 现在左右分工:
    // 右侧整块给星座,左下角放缩小的铭文。
    final constH = (h * 0.66).clamp(48.0, 144.0);
    final anchor =
        h >= 150 ? Offset(w * 0.78, h * 0.47) : Offset(w * 0.76, h * 0.5);
    // 小星座时星径 / 线宽 / 蜜蜂同步缩小,避免光晕融成一条光棒。
    final scale = (constH / 144).clamp(0.5, 1.0);

    _paintBaseGlow(canvas, size, anchor);
    _paintMilkyWay(canvas, size, t);
    _paintNebulae(canvas, size, t);
    _paintStardust(canvas, size, t);
    _paintMoon(canvas, size, t);
    _paintCrossStars(canvas, size, t);
    _paintConstellation(canvas, anchor, constH, scale, t);
    _paintShootingStars(canvas, size, t);
    // 主蜜蜂 + 身后半秒跟着的小蜜蜂(「陪伴」语义,动线也更热闹)
    _paintBee(canvas, size, anchor, constH, scale, t);
    _paintBee(canvas, size, anchor, constH, scale * 0.62, t,
        lag: 0.055, alphaFactor: 0.72);
    _paintAnnivInscription(canvas, size, _inscription, topInset);
  }

  /// 银河光带:135° 斜贯的淡光雾带 + 带内密集微星,填补左侧空区。
  void _paintMilkyWay(Canvas canvas, Size size, double t) {
    canvas.save();
    canvas.translate(size.width * .5, size.height * .5);
    canvas.rotate(-0.42);
    final band = Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 1.8,
        height: size.height * .46);
    canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _fg.withValues(alpha: 0),
              // 亮色要给到暗色的两倍多:暗色是「亮金雾叠纯黑」,一点点就跳出来;
              // 亮色是「白雾叠主题色」,同样的 alpha 在中高明度底色上几乎看不见。
              _fg.withValues(alpha: isDark ? .11 : .26),
              _fg.withValues(alpha: 0),
            ],
          ).createShader(band));
    canvas.restore();

    // 带内微星(沿带方向分布,比背景星尘更密更小)
    final rnd = math.Random(23);
    for (int i = 0; i < 30; i++) {
      final u = rnd.nextDouble();
      final x = -size.width * .07 + u * size.width * 1.14;
      final y = size.height * .82 - u * size.height * .72 +
          (rnd.nextDouble() - .5) * size.height * .2;
      final r = .6 + rnd.nextDouble() * .5;
      final freq = 2 + rnd.nextInt(3);
      final wave = .5 + .5 * math.sin(t * math.pi * 2 * freq + rnd.nextDouble() * 6.28);
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = _fg.withValues(alpha: .1 + wave * .45));
    }
  }

  /// 两团星云:主题色的**近邻**色相柔雾。色相偏移必须小(±14°)——
  /// 偏太多会在黑底上泛出脏绿/脏红,那是最容易翻车的地方。
  void _paintNebulae(Canvas canvas, Size size, double t) {
    final breathe = .5 + .5 * math.sin(t * math.pi * 2 * 1);
    final c1 = isDark ? _hueShift(primary, 14) : Colors.white;
    final c2 = isDark ? _hueShift(primary, -14) : Colors.white;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * .29, size.height * .72),
            width: size.width * .4,
            height: size.height * .38),
        Paint()
          ..shader = RadialGradient(colors: [
            c1.withValues(alpha: (isDark ? .075 : .16) + breathe * .03),
            c1.withValues(alpha: 0),
          ]).createShader(Rect.fromCenter(
              center: Offset(size.width * .29, size.height * .72),
              width: size.width * .4,
              height: size.height * .38)));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(size.width * .65, size.height * .14),
            width: size.width * .34,
            height: size.height * .3),
        Paint()
          ..shader = RadialGradient(colors: [
            c2.withValues(alpha: (isDark ? .065 : .13) + (1 - breathe) * .03),
            c2.withValues(alpha: 0),
          ]).createShader(Rect.fromCenter(
              center: Offset(size.width * .65, size.height * .14),
              width: size.width * .34,
              height: size.height * .3)));
  }

  /// 底层柔光:亮色白光 / 暗色主题色光,中心即星座锚点。
  void _paintBaseGlow(Canvas canvas, Size size, Offset anchor) {
    final glowColor = isDark ? primary : Colors.white;
    final radius = math.max(size.width, size.height) * 0.7;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        glowColor.withValues(alpha: isDark ? 0.15 : 0.28),
        glowColor.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: anchor, radius: radius));
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// 星尘:密度按面积,固定种子保证布局稳定,各自错相明灭。
  void _paintStardust(Canvas canvas, Size size, double t) {
    final n = (size.width * size.height / 2200).round().clamp(10, 32);
    final rnd = math.Random(14);
    for (int i = 0; i < n; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * 0.8;
      final freq = 2 + rnd.nextInt(3); // 整数频率,回绕无跳变
      final phase = rnd.nextDouble() * math.pi * 2;
      final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 * freq + phase);
      final alpha = 0.06 + wave * (isDark ? 0.55 : 0.5);
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = _fg.withValues(alpha: alpha));
    }
  }

  /// 左上金色月牙(缓慢呼吸)。
  void _paintMoon(Canvas canvas, Size size, double t) {
    final c = Offset(size.width * 0.13, size.height * 0.17);
    final r = (size.height * 0.055).clamp(8.0, 12.0);
    final breathe = 1 + 0.05 * math.sin(t * math.pi * 2 * 2); // 5s 一次
    final alpha = isDark ? 0.5 : 0.55;

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.32);
    canvas.scale(breathe);
    // 外圆减去偏移内圆 = 月牙(evenodd)
    final moon = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: r))
      ..addOval(Rect.fromCircle(center: Offset(r * 0.42, -r * 0.18), radius: r * 0.82));
    canvas.drawPath(moon, Paint()..color = _warm.withValues(alpha: alpha));
    canvas.restore();
  }

  /// 三颗四芒十字星,错相闪烁。
  void _paintCrossStars(Canvas canvas, Size size, double t) {
    const spots = [
      (0.16, 0.60, 5.5), // (x比例, y比例, 半径pt)
      (0.48, 0.20, 4.5),
      (0.88, 0.74, 6.0),
    ];
    for (int i = 0; i < spots.length; i++) {
      final (fx, fy, r) = spots[i];
      final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 * (2 + i) + i * 2.1);
      final alpha = 0.2 + wave * 0.75;
      final c = Offset(size.width * fx, size.height * fy);
      final k = r * 0.18; // 腰宽
      final star = Path()
        ..moveTo(c.dx, c.dy - r)
        ..lineTo(c.dx + k, c.dy - k)
        ..lineTo(c.dx + r, c.dy)
        ..lineTo(c.dx + k, c.dy + k)
        ..lineTo(c.dx, c.dy + r)
        ..lineTo(c.dx - k, c.dy + k)
        ..lineTo(c.dx - r, c.dy)
        ..lineTo(c.dx - k, c.dy - k)
        ..close();
      canvas.drawPath(star, Paint()..color = _warm.withValues(alpha: alpha));
    }
  }

  /// 流星:一圈 10s 内两颗,各自 1.1s 划过即逝。
  void _paintShootingStars(Canvas canvas, Size size, double t) {
    // 设计稿是「密集流星雨」:三条轨道各自循环,周期 3~3.8s,错相起跑,
    // 平均每秒都有星在划。原来 10s 才两颗,大部分时间天空是死的。
    // 每条轨道:(周期占总循环的比例, 相位, 起点x比例, 起点y比例, 行程)
    const lanes = [
      (0.30, 0.00, 0.08, 0.04, 170.0),
      (0.34, 0.42, 0.34, 0.16, 150.0),
      (0.38, 0.74, 0.60, 0.02, 190.0),
    ];
    const angle = 0.56; // ~32°,向右下
    final dir = Offset(math.cos(angle), math.sin(angle));
    for (final (period, phase, fx, fy, run) in lanes) {
      // 一个轨道周期里只有前 38% 在划,其余留空,不然三条同时亮太吵
      final cyc = ((t + phase) / period) % 1;
      if (cyc > 0.38) continue;
      final p = cyc / 0.38;
      final alpha = 0.9 * math.sin(math.pi * p);
      final head = Offset(size.width * fx, size.height * fy) + dir * (run * p);
      final tail = head - dir * 40;
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..shader = LinearGradient(colors: [
              _warm.withValues(alpha: 0),
              _warm.withValues(alpha: alpha),
            ]).createShader(Rect.fromPoints(tail, head))
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(head, 2, Paint()..color = _warm.withValues(alpha: alpha));
    }
  }

  /// 星座:虚线连线 + 十颗星(主星大一号),星光呼吸 + 径向渐变光晕。
  void _paintConstellation(
      Canvas canvas, Offset anchor, double constH, double scale, double t) {
    Offset star(int i) =>
        anchor + Offset(_kAnnivStars[i].dx * constH, _kAnnivStars[i].dy * constH);

    // 连线:帽 → 竖列顶 → 竖列底;底座三点横线。
    final line = Path()
      ..moveTo(star(0).dx, star(0).dy)
      ..lineTo(star(1).dx, star(1).dy)
      ..lineTo(star(2).dx, star(2).dy)
      ..lineTo(star(8).dx, star(8).dy)
      ..moveTo(star(7).dx, star(7).dy)
      ..lineTo(star(9).dx, star(9).dy);
    // 双层实线:宽光带打底 + 实线主导形状。光带太宽(≥10pt)会把「1」的
    // 转折糊掉,读成一把「剑」;虚线在放大后也撑不起主体。
    // 实线整体做**呼吸脉冲**(设计稿的 .breathe):亮度在 .72~1 之间慢慢起伏,
    // 让「1」像在发光而不是一条画死的线 —— 这是设计稿比早期实现「酷」的主因。
    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2);
    canvas.drawPath(
      line,
      Paint()
        ..color = _fg.withValues(alpha: (isDark ? .15 : .16) * (.75 + breathe * .5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = (6.5 + breathe * 1.2) * scale
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = _fg.withValues(
            alpha: (isDark ? .88 : .82) * (.78 + breathe * .22))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6 * scale
        ..strokeCap = StrokeCap.round,
    );

    // 沿着「1」跑一圈的流动高光:短亮段顺着路径推进,再叠一次「连线是活的」。
    _paintLinePulse(canvas, line, scale, t);

    // 先铺一层柔光盘,再画星点 —— 顺序不能反,否则后画的光盘会糊掉星点。
    //
    // **光盘是这款皮肤最关键的一笔**:半径 r*2.8、恒定 17% 的**实心圆**。
    // 竖列星距 = 0.23 × 星座高,主星 r=5.8 → 光盘直径 32.5,恰好略大于星距,
    // 于是五颗主星的光盘首尾相切,连成一根**发光的柱子**;「1」读起来就是
    // 一根光柱串着珠子,而不是「一串珠子加一条线」。
    // 早期用 RadialGradient 渐变(边缘淡出、半径还小一号),光盘之间连不上,
    // 这正是实现看着比设计稿寡淡的原因。
    const haloAlpha = 0.17;
    final rnd = math.Random(5);
    for (int i = 0; i < _kAnnivStars.length; i++) {
      // 主星 = 落在竖轴上的(x==0),含底座中点 —— 光柱由它们连成
      final main = _kAnnivStars[i].dx == 0;
      final r = (main ? 5.8 : 4.2) * scale;
      canvas.drawCircle(star(i), r * 2.8,
          Paint()..color = _fg.withValues(alpha: haloAlpha));
    }
    for (int i = 0; i < _kAnnivStars.length; i++) {
      final pos = star(i);
      final main = _kAnnivStars[i].dx == 0;
      final r = (main ? 5.8 : 4.2) * scale;
      final freq = 2 + rnd.nextInt(3);
      final phase = rnd.nextDouble() * math.pi * 2;
      final wave = 0.5 + 0.5 * math.sin(t * math.pi * 2 * freq + phase);
      final alpha = 0.45 + wave * 0.55;
      canvas.drawCircle(pos, r, Paint()..color = _fg.withValues(alpha: alpha));
      // 主星隔一颗带十字星芒 —— 全给会糊成一片光。
      if (main && i.isEven) {
        _drawAnnivCross(
            canvas, pos, r * 3.4 * (.85 + wave * .3), _fg, alpha * .55);
      }
    }
  }

  /// 沿星座连线推进的一小段高亮,循环一周。用 PathMetric 取子路径,
  /// 不额外分配 Path 缓存(连线每帧重建,metric 也跟着来)。
  void _paintLinePulse(Canvas canvas, Path line, double scale, double t) {
    final paint = Paint()
      ..color = _fg.withValues(alpha: isDark ? .95 : .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.9 * scale
      ..strokeCap = StrokeCap.round;
    for (final m in line.computeMetrics()) {
      final len = m.length;
      if (len <= 0) continue;
      final seg = len * .22;
      // 高亮头位置在 [-seg, len] 之间推进,保证进出两端都是渐入渐出
      final head = -seg + (len + seg) * t;
      final a = math.max(0.0, head - seg), b = math.min(len, head);
      if (b <= a) continue;
      canvas.drawPath(m.extractPath(a, b), paint);
    }
  }

  /// 蜜蜂光点:进场 → 绕星座一圈 → 右上飞出,10s 循环;彗尾 5 节。
  /// [lag] > 0 时画的是「伴飞的小蜜蜂」(落后主蜂一小段路程)。
  void _paintBee(Canvas canvas, Size size, Offset anchor, double constH,
      double scale, double t,
      {double lag = 0, double alphaFactor = 1}) {
    _ensureBeePath(size, anchor, constH);
    final metric = _beeMetric;
    if (metric == null) return;
    final bs = scale.clamp(0.7, 1.0); // 蜜蜂缩得比星座保守,保持存在感
    final bt = t - lag;
    if (bt < 0) return; // 伴飞的还没进场

    // 彗尾(从远到近画,叠在蜜蜂之下)
    for (int i = 5; i >= 1; i--) {
      final tt = bt - 0.009 * i;
      if (tt < 0) continue; // 刚进场时尾巴少几节,自然
      final tangent = metric.getTangentForOffset(metric.length * tt);
      if (tangent == null) continue;
      final r = (3.0 - (i - 1) * 0.45) * bs;
      final alpha = (0.75 - (i - 1) * 0.14) * alphaFactor;
      canvas.drawCircle(tangent.position, r,
          Paint()..color = _fg.withValues(alpha: alpha * 0.6));
    }

    final tangent = metric.getTangentForOffset(metric.length * bt);
    if (tangent == null) return;
    final pos = tangent.position;
    final angle = math.atan2(tangent.vector.dy, tangent.vector.dx);

    // 光晕
    final glowR = 10 * bs;
    canvas.drawCircle(
        pos,
        glowR,
        Paint()
          ..shader = RadialGradient(colors: [
            _fg.withValues(alpha: 0.55 * alphaFactor),
            _fg.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: pos, radius: glowR)));

    // 身体 + 双翅(随运动方向旋转;翅膀 0.14s 高频摆动模拟振翅)
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    canvas.scale(bs);
    // 伴飞的小蜜蜂错开振翅相位,两只不同步才自然
    final phase = lag * math.pi * 2 * 70;
    final flap = 0.75 + 0.35 * math.sin(t * math.pi * 2 * 70 + phase);
    final flap2 = 0.75 + 0.35 * math.sin(t * math.pi * 2 * 70 + phase + math.pi);
    final wing = Paint()..color = _fg.withValues(alpha: 0.7 * alphaFactor);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(-1, -4.5), width: 6.5, height: 3.6 * flap),
        wing);
    canvas.drawOval(
        Rect.fromCenter(
            center: const Offset(-1, 4.5), width: 6.5, height: 3.6 * flap2),
        wing);
    canvas.drawCircle(
        Offset.zero, 4, Paint()..color = _fg.withValues(alpha: alphaFactor));
    canvas.restore();
  }

  /// 路径缓存:尺寸不变则复用(锚点/星座尺寸由尺寸唯一决定)。
  void _ensureBeePath(Size size, Offset anchor, double constH) {
    if (_cachedSize == size && _beeMetric != null) return;
    _cachedSize = size;

    final w = size.width, h = size.height;
    // 环绕半径:比星座略大一圈(垂直余量给足,避免小星座时擦星而过)
    final rx = constH * 1.2, ry = constH * 0.88;
    final orbit = Rect.fromCenter(center: anchor, width: rx * 2, height: ry * 2);

    final entryY = h * 0.82;
    final path = Path()
      ..moveTo(-w * 0.08, entryY)
      // S 形进场,爬升到星座左下方(150° 弧起点)
      ..cubicTo(w * 0.12, entryY - h * 0.06, w * 0.16, h * 0.42,
          anchor.dx - rx * 0.866, anchor.dy + ry * 0.5)
      // 绕星座一整圈(顺时针),再补 120° 走到轨道顶部
      ..arcTo(orbit, math.pi * 5 / 6, math.pi * 2 - 0.001, false)
      ..arcTo(orbit, math.pi * 5 / 6, math.pi * 2 / 3, false)
      // 从顶部向右上飞出屏幕(始终在星座外侧,不穿星)
      ..cubicTo(anchor.dx + rx * 0.9, anchor.dy - ry * 1.4, w * 0.94, h * 0.10,
          w * 1.12, h * 0.05);

    final metrics = path.computeMetrics().toList();
    _beeMetric = metrics.isEmpty ? null : metrics.first;
  }

  @override
  bool shouldRepaint(covariant _ConstellationPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

/// 悬浮 tab 装饰:一颗流星每 7 秒从胶囊左侧划到右侧,其余时间无痕。
class _AnniversaryTabDeco extends StatefulWidget {
  const _AnniversaryTabDeco(this.primary, this.isDark);
  final Color primary;
  final bool isDark;

  @override
  State<_AnniversaryTabDeco> createState() => _AnniversaryTabDecoState();
}

class _AnniversaryTabDecoState extends State<_AnniversaryTabDeco>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0; // 静态时无痕
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _TabMeteorPainter(widget.primary, widget.isDark, _controller),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TabMeteorPainter extends CustomPainter {
  _TabMeteorPainter(this.primary, this.isDark, this.anim) : super(repaint: anim);
  final Color primary;
  final bool isDark;
  final Animation<double> anim;

  Color get _c => isDark ? _lighten(primary, 0.08) : primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim.value;
    final h = size.height, w = size.width;

    // 常驻的一小片夜空:淡银河 + 迷你月牙 + 右端的迷你「1」星座 +
    // 四颗错相闪烁的微星 + 两颗十字星光。
    // 之前只有 7 秒一次的流星,平时整条胶囊是空的。
    final band = Rect.fromLTWH(0, h * .1, w, h * .8);
    canvas.drawRect(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _c.withValues(alpha: 0),
              _c.withValues(alpha: isDark ? .1 : .08),
              _c.withValues(alpha: 0),
            ],
          ).createShader(band));

    _paintMiniOne(canvas, Offset(w * .93, h * .5), h * .62, t);

    final moonC = Offset(w * .045, h * .28);
    final mr = h * .17;
    final moon = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: moonC, radius: mr))
      ..addOval(Rect.fromCircle(
          center: moonC + Offset(mr * .42, -mr * .18), radius: mr * .82));
    canvas.drawPath(moon, Paint()..color = _c.withValues(alpha: isDark ? .55 : .42));

    const stars = [
      [.16, .3, 1.3],
      [.3, .72, 1.1],
      [.72, .26, 1.2],
      [.88, .68, 1.4],
    ];
    for (int i = 0; i < stars.length; i++) {
      final s = stars[i];
      final wave = .5 + .5 * math.sin((t * (2 + i) + i * .4) * math.pi * 2);
      canvas.drawCircle(Offset(w * s[0], h * s[1]), s[2],
          Paint()..color = _c.withValues(alpha: .15 + wave * (isDark ? .75 : .6)));
    }
    for (int i = 0; i < 2; i++) {
      final cx = w * (i == 0 ? .55 : .95), cy = h * (i == 0 ? .22 : .34);
      final wave = .5 + .5 * math.sin((t * (3 + i) + i * .7) * math.pi * 2);
      final r = h * .1;
      final k = r * .18;
      canvas.drawPath(
          Path()
            ..moveTo(cx, cy - r)
            ..lineTo(cx + k, cy - k)
            ..lineTo(cx + r, cy)
            ..lineTo(cx + k, cy + k)
            ..lineTo(cx, cy + r)
            ..lineTo(cx - k, cy + k)
            ..lineTo(cx - r, cy)
            ..lineTo(cx - k, cy - k)
            ..close(),
          Paint()..color = _c.withValues(alpha: .12 + wave * .6));
    }

    // 流星:前 23% 的时间在划,其余无痕
    const window = 0.23;
    _paintTabMeteor(canvas, size, t, window);
  }

  /// 胶囊右端的迷你「1」星座:和 header 用同一组星点,连线后整条 tab 才
  /// 认得出是同一款皮肤。
  void _paintMiniOne(Canvas canvas, Offset c, double hh, double t) {
    final pts = _kAnnivStars
        .map((o) => Offset(c.dx + o.dx * hh, c.dy + o.dy * hh))
        .toList();
    final line = Paint()
      ..color = _c.withValues(alpha: isDark ? .5 : .42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy)
          ..lineTo(pts[6].dx, pts[6].dy),
        line);
    canvas.drawLine(pts[7], pts[9], line);
    for (int i = 0; i < pts.length; i++) {
      final main = i >= _kAnnivMainStarFrom && i <= _kAnnivMainStarTo;
      final wave = .5 + .5 * math.sin((t * (2 + i % 3) + i * .3) * math.pi * 2);
      canvas.drawCircle(
          pts[i],
          main ? 1.7 : 1.2,
          Paint()
            ..color = _c.withValues(alpha: .3 + wave * (isDark ? .65 : .5)));
    }
  }

  void _paintTabMeteor(Canvas canvas, Size size, double t, double window) {
    final h = size.height, w = size.width;
    if (t >= window) return;
    final p = t / window;
    final x = ui.lerpDouble(-30.0, w + 30.0, p)!;
    final y = h * 0.22;
    final alpha = 0.85 * math.sin(math.pi * p); // 淡入淡出包络
    final tail = Rect.fromLTWH(x - 26, y - 1, 26, 2);
    canvas.drawRect(
        tail,
        Paint()
          ..shader = LinearGradient(colors: [
            _c.withValues(alpha: 0),
            _c.withValues(alpha: alpha),
          ]).createShader(tail));
    canvas.drawCircle(
        Offset(x, y), 2.5, Paint()..color = _c.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(covariant _TabMeteorPainter old) =>
      old.primary != primary || old.isDark != isDark;
}

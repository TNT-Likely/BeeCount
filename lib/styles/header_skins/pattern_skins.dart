part of '../header_skins.dart';

// ====== 几何图案皮肤(蜂巢 / 星河 / 斜纹)======
// 透明叠加在 header 基础色上:亮色用白色图案叠在主题色底上,暗色用偏淡主题色图案叠在纯黑底上。
// 三款共用 _PatternSkin 包装,各自只提供一个 CustomPainter。

class _PatternSkin extends StatelessWidget {
  const _PatternSkin(this.primary, this.isDark, this.painterFor);
  final Color primary;
  final bool isDark;
  final CustomPainter Function(Color patternColor) painterFor;

  @override
  Widget build(BuildContext context) {
    // 透明底:让 header 基础色透出(亮=主题色 / 暗=纯黑)。图案颜色:暗=主题色、亮=白色。
    return CustomPaint(
      painter: painterFor(isDark ? primary : Colors.white),
      child: const SizedBox.expand(),
    );
  }
}

/// 蜂巢六边形
class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const hexSize = 30.0;
    final hexHeight = hexSize * math.sqrt(3);
    final hexWidth = hexSize * 2;
    final rows = (size.height / hexHeight * 1.5).ceil() + 2;
    final cols = (size.width / (hexWidth * 0.75)).ceil() + 2;
    for (int row = -1; row < rows; row++) {
      for (int col = -1; col < cols; col++) {
        final x = col * hexWidth * 0.75;
        final y = row * hexHeight + (col.isOdd ? hexHeight / 2 : 0);
        final random = math.Random((row * 1000 + col).hashCode);
        if (random.nextDouble() > 0.3) {
          final path = Path();
          for (int i = 0; i < 6; i++) {
            final a = (math.pi / 3) * i;
            final px = x + hexSize * math.cos(a);
            final py = y + hexSize * math.sin(a);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter old) => old.color != color;
}

/// 星河(粒子 + 五角星)
class _StarryPainter extends CustomPainter {
  _StarryPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42); // 固定种子,保持一致性
    for (int i = 0; i < 35; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final particleSize = 2.0 + random.nextDouble() * 4; // 2-6 px
      final opacity = 0.1 + random.nextDouble() * 0.15; // 10%-25%
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), particleSize, paint);
      // 20% 的粒子带光晕(与原暗黑装饰一致)
      if (i % 5 == 0) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint);
      }
    }
    for (int i = 0; i < 10; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final starSize = 8.0 + random.nextDouble() * 8; // 8-16px
      final opacity = 0.15 + random.nextDouble() * 0.1;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawPath(_star(x, y, starSize, starSize * 0.4), paint);
    }
  }

  Path _star(double cx, double cy, double outer, double inner) {
    final path = Path();
    const points = 5;
    const angle = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outer : inner;
      final a = angle * i - math.pi / 2;
      final x = cx + radius * math.cos(a);
      final y = cy + radius * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _StarryPainter old) => old.color != color;
}

/// 斜纹(三组不同粗细的对角线)
class _StripesPainter extends CustomPainter {
  _StripesPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 30.0;
    final paints = [
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
      Paint()
        ..color = color.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    ];
    for (int g = 0; g < 3; g++) {
      for (double i = -size.height + spacing * g;
          i < size.width + size.height;
          i += spacing * 3) {
        canvas.drawLine(
            Offset(i, 0), Offset(i + size.height, size.height), paints[g]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StripesPainter old) => old.color != color;
}

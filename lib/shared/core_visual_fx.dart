import 'dart:math' as math;

import 'package:flutter/material.dart';

int coreVisualTierForLevel(int coreLevel) {
  const thresholds = [5, 10, 15, 20, 25, 30, 35, 40, 43];
  int tier = 0;
  for (final threshold in thresholds) {
    if (coreLevel >= threshold) tier += 1;
  }
  return tier;
}

class CoreVisualFxOverlay extends StatefulWidget {
  final int coreLevel;
  final double opacity;

  const CoreVisualFxOverlay({
    super.key,
    required this.coreLevel,
    this.opacity = 1.0,
  });

  @override
  State<CoreVisualFxOverlay> createState() => _CoreVisualFxOverlayState();
}

class _CoreVisualFxOverlayState extends State<CoreVisualFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: CoreVisualFxPainter(
              coreLevel: widget.coreLevel,
              opacity: widget.opacity,
              phase: _controller.value * math.pi * 2,
            ),
          );
        },
      ),
    );
  }
}

class CoreVisualFxPainter extends CustomPainter {
  final int coreLevel;
  final double opacity;
  final double phase;

  const CoreVisualFxPainter({
    required this.coreLevel,
    required this.phase,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    drawCoreVisualFx(
      canvas,
      Offset.zero & size,
      coreLevel: coreLevel,
      phase: phase,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(covariant CoreVisualFxPainter oldDelegate) {
    return oldDelegate.coreLevel != coreLevel ||
        oldDelegate.phase != phase ||
        oldDelegate.opacity != opacity;
  }
}

void drawCoreVisualFx(
  Canvas canvas,
  Rect rect, {
  required int coreLevel,
  required double phase,
  double opacity = 1.0,
}) {
  final tier = coreVisualTierForLevel(coreLevel);
  if (tier <= 0) return;

  final center = rect.center;
  final minSide = math.min(rect.width, rect.height);
  final orbit = minSide * 0.58;
  final primary = const Color(0xFF5EC7FF).withOpacity(opacity);
  final secondary = const Color(0xFFFFD36E).withOpacity(opacity);
  final tertiary = const Color(0xFFA88DFF).withOpacity(opacity * 0.92);

  _drawCoreSatellites(
    canvas,
    center,
    orbit: orbit,
    tier: tier,
    primary: primary,
    secondary: secondary,
    phase: phase,
  );
  if (tier >= 3) {
    _drawCoreSparkBursts(
      canvas,
      center,
      orbit: orbit * 1.04,
      tier: tier,
      color: tertiary,
      phase: phase,
    );
  }
  if (tier >= 5) {
    _drawCoreComets(
      canvas,
      center,
      orbit: orbit * 1.14,
      tier: tier,
      color: primary,
      phase: phase,
    );
  }
}

void _drawCoreSatellites(
  Canvas canvas,
  Offset center, {
  required double orbit,
  required int tier,
  required Color primary,
  required Color secondary,
  required double phase,
}) {
  final count = switch (tier) {
    <= 2 => 3,
    <= 4 => 4,
    <= 6 => 5,
    _ => 6,
  };
  for (int i = 0; i < count; i++) {
    final angle = phase * (0.42 + tier * 0.015) + i * (math.pi * 2 / count);
    final wobble = math.sin(phase * 1.7 + i) * orbit * 0.05;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * (orbit + wobble);
    final size = orbit * (0.045 + tier * 0.002);
    final color = i.isEven ? primary : secondary;
    _drawGlowDot(canvas, point, size, color);
    _drawDiamondSpark(canvas, point, size * 1.8, color.withOpacity(0.95));
  }
}

void _drawCoreSparkBursts(
  Canvas canvas,
  Offset center, {
  required double orbit,
  required int tier,
  required Color color,
  required double phase,
}) {
  final count = switch (tier) {
    <= 4 => 2,
    <= 6 => 3,
    _ => 4,
  };
  for (int i = 0; i < count; i++) {
    final angle = -phase * 0.35 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
    final radius = orbit * (0.06 + tier * 0.003);
    final paint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, orbit * 0.02);
    canvas.drawArc(
      Rect.fromCircle(center: point, radius: radius),
      phase + i,
      math.pi * 1.1,
      false,
      paint,
    );
  }
}

void _drawCoreComets(
  Canvas canvas,
  Offset center, {
  required double orbit,
  required int tier,
  required Color color,
  required double phase,
}) {
  final count = switch (tier) {
    <= 6 => 2,
    <= 8 => 3,
    _ => 4,
  };
  final paint = Paint()
    ..color = color.withOpacity(0.92)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = math.max(1.0, orbit * 0.016);
  for (int i = 0; i < count; i++) {
    final angle = phase * 0.28 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
    final tangent = Offset(-math.sin(angle), math.cos(angle));
    final length = orbit * (0.13 + tier * 0.004);
    canvas.drawLine(point - tangent * length * 0.35, point + tangent * length, paint);
  }
}

void _drawGlowDot(Canvas canvas, Offset center, double radius, Color color) {
  final glow = Paint()..color = color.withOpacity(0.18);
  canvas.drawCircle(center, radius * 2.5, glow);
  final core = Paint()..color = color;
  canvas.drawCircle(center, radius, core);
}

void _drawDiamondSpark(Canvas canvas, Offset center, double size, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, size * 0.18);
  final path = Path()
    ..moveTo(center.dx, center.dy - size)
    ..lineTo(center.dx + size * 0.7, center.dy)
    ..lineTo(center.dx, center.dy + size)
    ..lineTo(center.dx - size * 0.7, center.dy)
    ..close();
  canvas.drawPath(path, paint);
}

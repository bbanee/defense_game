import 'dart:math' as math;

import 'package:flutter/material.dart';

int towerVisualTierForLevel(int permanentLevel) {
  if (permanentLevel >= 15) return 3;
  if (permanentLevel >= 10) return 2;
  if (permanentLevel >= 5) return 1;
  return 0;
}

Color towerVisualPrimaryColor(String? rarity) {
  return switch (rarity) {
    'common' => const Color(0xFF4F8BFF),
    'rare' => const Color(0xFF17D6B0),
    'unique' => const Color(0xFFE16BFF),
    'legendary' => const Color(0xFFFFC64D),
    _ => const Color(0xFF88A1D8),
  };
}

Color towerVisualSecondaryColor(String? rarity) {
  return switch (rarity) {
    'common' => const Color(0xFFBBD3FF),
    'rare' => const Color(0xFF9AF3E0),
    'unique' => const Color(0xFFF1B0FF),
    'legendary' => const Color(0xFFFFE39A),
    _ => const Color(0xFFD4DEFA),
  };
}

class TowerVisualFxOverlay extends StatefulWidget {
  final int permanentLevel;
  final String towerId;
  final String? rarity;
  final double opacity;

  const TowerVisualFxOverlay({
    super.key,
    required this.permanentLevel,
    required this.towerId,
    required this.rarity,
    this.opacity = 1.0,
  });

  @override
  State<TowerVisualFxOverlay> createState() => _TowerVisualFxOverlayState();
}

class _TowerVisualFxOverlayState extends State<TowerVisualFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
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
            painter: TowerVisualFxPainter(
              permanentLevel: widget.permanentLevel,
              towerId: widget.towerId,
              rarity: widget.rarity,
              opacity: widget.opacity,
              phase: _controller.value * math.pi * 2,
            ),
          );
        },
      ),
    );
  }
}

class TowerVisualFxPainter extends CustomPainter {
  final int permanentLevel;
  final String towerId;
  final String? rarity;
  final double opacity;
  final double phase;

  const TowerVisualFxPainter({
    required this.permanentLevel,
    required this.towerId,
    required this.rarity,
    required this.phase,
    this.opacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    drawTowerVisualFx(
      canvas,
      Offset.zero & size,
      permanentLevel: permanentLevel,
      towerId: towerId,
      rarity: rarity,
      opacity: opacity,
      phase: phase,
    );
  }

  @override
  bool shouldRepaint(covariant TowerVisualFxPainter oldDelegate) {
    return oldDelegate.permanentLevel != permanentLevel ||
        oldDelegate.towerId != towerId ||
        oldDelegate.rarity != rarity ||
        oldDelegate.opacity != opacity ||
        oldDelegate.phase != phase;
  }
}

void drawTowerVisualFx(
  Canvas canvas,
  Rect rect, {
  required int permanentLevel,
  required String towerId,
  required String? rarity,
  required double phase,
  double opacity = 1.0,
}) {
  final tier = towerVisualTierForLevel(permanentLevel);
  if (tier == 0) return;

  final primary = towerVisualPrimaryColor(rarity);
  final secondary = towerVisualSecondaryColor(rarity);
  final center = rect.center;
  final minSide = math.min(rect.width, rect.height);
  final orbit = minSide * (tier >= 3 ? 0.62 : 0.58);
  final sparkleSize = minSide * (tier >= 3 ? 0.055 : 0.045);
  final pulse = 0.72 + (math.sin(phase * 1.4) + 1) * 0.17;
  final variant = _towerVisualVariant(towerId);

  _drawOrbitLights(
    canvas,
    center,
    orbit: orbit,
    tier: tier,
    variant: variant,
    primary: primary.withOpacity((0.78 + tier * 0.05) * opacity),
    secondary: secondary.withOpacity((0.72 + tier * 0.05) * opacity),
    sparkleSize: sparkleSize,
    phase: phase,
    pulse: pulse,
  );
  if (tier >= 2) {
    _drawPulseStars(
      canvas,
      center,
      orbit * (tier >= 3 ? 1.04 : 0.96),
      tier: tier,
      primary: primary.withOpacity((0.76 + tier * 0.05) * opacity),
      phase: phase,
      sparkleSize: sparkleSize,
    );
  }
  _drawRarityBursts(
    canvas,
    center,
    orbit: orbit,
    tier: tier,
    rarity: rarity,
    primary: primary.withOpacity((0.68 + tier * 0.04) * opacity),
    phase: phase,
  );
}

int _towerVisualVariant(String towerId) {
  return switch (towerId) {
    'cannon_basic' => 0,
    'rapid_basic' => 1,
    'shotgun_basic' => 2,
    'frost_basic' => 3,
    'drone_basic' => 4,
    'chain_basic' => 0,
    'missile_basic' => 1,
    'support_basic' => 2,
    'laser_basic' => 3,
    'sniper_basic' => 4,
    'gravity_basic' => 0,
    'infection_basic' => 1,
    'chrono_basic' => 2,
    'singularity_basic' => 3,
    'mortar_basic' => 4,
    _ => towerId.hashCode.abs() % 5,
  };
}

void _drawOrbitLights(
  Canvas canvas,
  Offset center, {
  required double orbit,
  required int tier,
  required int variant,
  required Color primary,
  required Color secondary,
  required double sparkleSize,
  required double phase,
  required double pulse,
}) {
  final count = switch (tier) {
    1 => 3,
    2 => 5,
    _ => 7,
  };
  final speed = 0.55 + variant * 0.12;
  final direction = variant.isEven ? 1.0 : -1.0;
  final size = sparkleSize * pulse;
  for (int i = 0; i < count; i++) {
    final ratio = i / count;
    final angle = phase * speed * direction + ratio * math.pi * 2;
    final wobble = math.sin(phase * (1.2 + i * 0.15) + variant) * orbit * 0.06;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * (orbit + wobble);
    final color = i.isEven ? secondary : primary;
    _drawGlowDot(canvas, point, size * (i.isEven ? 1.0 : 0.82), color);
    _drawSparkle(
      canvas,
      point,
      size * (tier >= 3 ? 1.35 : 1.1),
      color.withOpacity(0.95),
    );
  }
}

void _drawPulseStars(
  Canvas canvas,
  Offset center,
  double orbit, {
  required int tier,
  required Color primary,
  required double phase,
  required double sparkleSize,
}) {
  final count = tier >= 3 ? 3 : 2;
  for (int i = 0; i < count; i++) {
    final angle = phase * 0.45 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
    final pulse = 0.75 + (math.sin(phase * 2.2 + i * 1.4) + 1) * 0.22;
    _drawSparkle(canvas, point, sparkleSize * 1.7 * pulse, primary.withOpacity(0.96));
  }
}

void _drawRarityBursts(
  Canvas canvas,
  Offset center, {
  required double orbit,
  required int tier,
  required String? rarity,
  required Color primary,
  required double phase,
}) {
  switch (rarity) {
    case 'common':
      _drawCommonBursts(canvas, center, orbit, tier, primary, phase);
      break;
    case 'rare':
      _drawRareBursts(canvas, center, orbit, tier, primary, phase);
      break;
    case 'unique':
      _drawUniqueBursts(canvas, center, orbit, tier, primary, phase);
      break;
    case 'legendary':
      _drawLegendaryBursts(canvas, center, orbit, tier, primary, phase);
      break;
  }
}

void _drawCommonBursts(
  Canvas canvas,
  Offset center,
  double orbit,
  int tier,
  Color color,
  double phase,
) {
  final paint = Paint()
    ..color = color.withOpacity(0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, orbit * 0.03);
  final count = tier >= 3 ? 3 : 2;
  for (int i = 0; i < count; i++) {
    final angle = phase * 0.5 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * (orbit * 0.92);
    canvas.drawLine(
      point + Offset(-orbit * 0.08, 0),
      point + Offset(orbit * 0.08, 0),
      paint,
    );
  }
}

void _drawRareBursts(
  Canvas canvas,
  Offset center,
  double orbit,
  int tier,
  Color color,
  double phase,
) {
  final paint = Paint()
    ..color = color.withOpacity(0.82)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, orbit * 0.028);
  final count = tier >= 3 ? 4 : 3;
  for (int i = 0; i < count; i++) {
    final angle = -phase * 0.45 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
    final path = Path()
      ..moveTo(point.dx, point.dy - orbit * 0.06)
      ..lineTo(point.dx + orbit * 0.05, point.dy)
      ..lineTo(point.dx, point.dy + orbit * 0.06)
      ..lineTo(point.dx - orbit * 0.05, point.dy)
      ..close();
    canvas.drawPath(path, paint);
  }
}

void _drawUniqueBursts(
  Canvas canvas,
  Offset center,
  double orbit,
  int tier,
  Color color,
  double phase,
) {
  final paint = Paint()
    ..color = color.withOpacity(0.84)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.25, orbit * 0.03);
  final count = tier >= 3 ? 3 : 2;
  for (int i = 0; i < count; i++) {
    final angle = phase * 0.38 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * (orbit * 1.02);
    canvas.drawArc(
      Rect.fromCircle(center: point, radius: orbit * 0.08),
      phase + i,
      math.pi * 1.3,
      false,
      paint,
    );
  }
}

void _drawLegendaryBursts(
  Canvas canvas,
  Offset center,
  double orbit,
  int tier,
  Color color,
  double phase,
) {
  final paint = Paint()
    ..color = color.withOpacity(0.88)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.35, orbit * 0.032);
  final count = tier >= 3 ? 5 : 4;
  for (int i = 0; i < count; i++) {
    final angle = phase * 0.6 + i * (math.pi * 2 / count);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * (orbit * 1.06);
    _drawSparkle(canvas, point, orbit * (tier >= 3 ? 0.11 : 0.09), color);
    canvas.drawCircle(point, orbit * 0.035, Paint()..color = color.withOpacity(0.95));
    canvas.drawCircle(point, orbit * 0.07, paint);
  }
}

void _drawGlowDot(Canvas canvas, Offset center, double radius, Color color) {
  final glow = Paint()..color = color.withOpacity(0.18);
  canvas.drawCircle(center, radius * 2.3, glow);
  final core = Paint()..color = color;
  canvas.drawCircle(center, radius, core);
}

void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.0, size * 0.28);
  canvas.drawLine(center + Offset(-size, 0), center + Offset(size, 0), paint);
  canvas.drawLine(center + Offset(0, -size), center + Offset(0, size), paint);
}

import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:tower_defense/game/tower_defense_game.dart';

const bool kHideTowerEffectSpritesForDebug = false;

class TowerEffect extends PositionComponent {
  final TowerDefenseGame gameRef;
  final String spritePath;
  double life = 1.0;
  double maxLife = 1.0;
  Sprite? sprite;

  TowerEffect({
    required this.gameRef,
    required this.spritePath,
    required Vector2 worldPos,
    required Vector2 size,
  }) {
    position = worldPos;
    this.size = size;
    anchor = Anchor.center;
    priority = 850;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      sprite = await gameRef.loadSprite(spritePath);
    } catch (_) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (kHideTowerEffectSpritesForDebug) return;
    if (sprite == null) return;
    final t = (life / maxLife).clamp(0.0, 1.0);
    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(t);
    sprite!.render(
      canvas,
      position: Vector2(-size.x / 2, -size.y / 2),
      size: size,
      overridePaint: paint,
    );
  }
}

class EnemyAttachedTowerEffect extends PositionComponent {
  final TowerDefenseGame gameRef;
  final Enemy target;
  final String spritePath;
  final Vector2 offset;
  double life;
  final double maxLife;
  Sprite? sprite;

  EnemyAttachedTowerEffect({
    required this.gameRef,
    required this.target,
    required this.spritePath,
    required Vector2 size,
    Vector2? offset,
    this.life = 1.2,
  })  : offset = offset ?? Vector2(20, 0),
        maxLife = life {
    this.size = size;
    anchor = Anchor.center;
    priority = 875;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      sprite = await gameRef.loadSprite(spritePath);
      position = target.effectCenter + offset;
    } catch (_) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (target.isRemoved) {
      removeFromParent();
      return;
    }
    position = target.effectCenter + offset;
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite == null) return;
    final t = (life / maxLife).clamp(0.0, 1.0);
    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(t);
    sprite!.render(
      canvas,
      position: Vector2(-size.x / 2, -size.y / 2),
      size: size,
      overridePaint: paint,
    );
  }
}

class SpriteHitscanEffect extends PositionComponent {
  final TowerDefenseGame gameRef;
  final String spritePath;
  final Vector2 start;
  final Vector2 end;
  double life;
  final double maxLife;
  final double lengthScale;
  final double thicknessScale;
  Sprite? sprite;

  SpriteHitscanEffect({
    required this.gameRef,
    required this.spritePath,
    required this.start,
    required this.end,
    this.life = 0.09,
    this.lengthScale = 1.0,
    this.thicknessScale = 1.0,
  }) : maxLife = life {
    anchor = Anchor.center;
    priority = 900;

    final delta = end - start;
    final length = delta.length;
    final angle = math.atan2(delta.y, delta.x);
    position = start + delta / 2;
    this.angle = angle;
    size = Vector2(length * lengthScale, gameRef.tileSize * 0.42 * thicknessScale);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      sprite = await gameRef.loadSprite(spritePath);
    } catch (_) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (kHideTowerEffectSpritesForDebug) return;
    if (sprite == null) return;
    final t = (life / maxLife).clamp(0.0, 1.0);
    final paint = Paint()..color = const Color(0xFFFFFFFF).withOpacity(t);
    sprite!.render(
      canvas,
      position: Vector2(-size.x / 2, -size.y / 2),
      size: size,
      overridePaint: paint,
    );
  }
}

class TowerEffectProjectile extends PositionComponent {
  final TowerDefenseGame gameRef;
  final String spritePath;
  final Vector2 targetPos;
  final Enemy target;
  final double speed;
  final double sizeScale;
  final Color? glowColor;
  final double glowScale;
  final double glowOpacity;
  final double lingerDuration;
  final VoidCallback onArrive;
  Sprite? sprite;
  late final Vector2 direction;
  bool arrived = false;
  double linger = 0.0;

  TowerEffectProjectile({
    required this.gameRef,
    required this.spritePath,
    required Vector2 start,
    required this.targetPos,
    required this.target,
    required this.speed,
    this.sizeScale = 1.0,
    this.glowColor,
    this.glowScale = 1.0,
    this.glowOpacity = 0.5,
    this.lingerDuration = 0.0,
    required this.onArrive,
  }) {
    position = start;
    size = Vector2(gameRef.tileSize * 0.8 * sizeScale, gameRef.tileSize * 0.8 * sizeScale);
    anchor = Anchor.center;
    priority = 860;
    direction = (targetPos - start).normalized();
    angle = math.atan2(direction.y, direction.x);
    linger = lingerDuration;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      sprite = await gameRef.loadSprite(spritePath);
    } catch (_) {
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (sprite == null) return;
    if (arrived) {
      linger -= dt;
      if (linger <= 0) {
        removeFromParent();
      }
      return;
    }
    final step = speed * dt;
    final toTarget = targetPos - position;
    if (toTarget.length2 > 0) {
      angle = math.atan2(toTarget.y, toTarget.x);
    }
    if (toTarget.length <= step) {
      position = targetPos;
      arrived = true;
      if (!target.isRemoved) {
        onArrive();
      }
      if (linger <= 0) {
        removeFromParent();
      }
      return;
    }
    position += direction * step;
  }

  @override
  void render(Canvas canvas) {
    if (kHideTowerEffectSpritesForDebug) return;
    if (sprite == null) return;
    if (glowColor != null) {
      final r = (size.x > size.y ? size.x : size.y) * 0.5 * glowScale;
      final paint = Paint()
        ..color = glowColor!.withOpacity(glowOpacity)
        ..blendMode = BlendMode.plus;
      canvas.drawCircle(Offset.zero, r, paint);
    }
    sprite!.render(
      canvas,
      position: Vector2(-size.x / 2, -size.y / 2),
      size: size,
    );
  }
}

class ShockwaveEffect extends PositionComponent {
  final Color color;
  final double maxRadius;
  final double strokeWidth;
  double life;
  final double maxLife;

  ShockwaveEffect({
    required Vector2 worldPos,
    required this.color,
    required this.maxRadius,
    required this.strokeWidth,
    required this.life,
  })  : maxLife = life {
    position = worldPos;
    anchor = Anchor.center;
    priority = 855;
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (1.0 - life / maxLife).clamp(0.0, 1.0);
    final r = maxRadius * t;
    final paint = Paint()
      ..color = color.withOpacity(1.0 - t)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * (1.0 - t * 0.3);
    canvas.drawCircle(Offset.zero, r, paint);
  }
}

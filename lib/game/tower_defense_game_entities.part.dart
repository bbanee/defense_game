part of 'tower_defense_game.dart';

class DamageText extends TextComponent {
  final double lifeTime;
  double life = 0;

  DamageText({
    required String text,
    required Vector2 position,
    this.lifeTime = 0.6,
  }) : super(
          text: text,
          position: position,
          anchor: Anchor.center,
          priority: 900,
          textRenderer: TextPaint(
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

  @override
  void update(double dt) {
    super.update(dt);
    life += dt;
    position += Vector2(0, -18 * dt);
    final t = (1.0 - life / lifeTime).clamp(0.0, 1.0);
    textRenderer = TextPaint(
      style: TextStyle(
        color: const Color(0xFFFFFFFF).withOpacity(t),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(color: Color(0xFF3B82F6), blurRadius: 2, offset: Offset(0, 0)),
        ],
      ),
    );
    if (life >= lifeTime) {
      removeFromParent();
    }
  }
}

class Enemy extends SpriteAnimationGroupComponent<EnemyAnim> {
  final TowerDefenseGame gameRef;
  final EnemyType type;
  final EnemyDef def;
  final List<GridPoint> path;
  final double hpMultiplier;
  final double speedMultiplier;
  final double rewardMultiplier;

  late double speed;
  late double hp;
  late double maxHp;

  int pathIndex = 0;
  bool reachedGoal = false;
  bool atCore = false;
  double attackTimer = 0;
  final double attackInterval = 1.0;
  final double attackDamage = 5;
  double progress = 0;

  double hitTimer = 0;
  bool isDying = false;
  double deathTimer = 0;

  final EnemyStatus enemyStatus = EnemyStatus();

  EnemyAnim lastMoveAnim = EnemyAnim.right;
  Vector2 lastScale = Vector2(1, 1);
  double attackPulse = 0;
  double attackNudge = 0;
  Vector2 attackDir = Vector2.zero();
  double dotTextCooldown = 0;
  double dotTextAccum = 0;

  static final Map<EnemyType, Vector2> _visualOffsetCache = {};
  Vector2 visualOffset = Vector2.zero();

  Vector2 get visualCenter => position + Vector2(visualOffset.x * scale.x, visualOffset.y * scale.y);

  Vector2 _hpBarOffset() {
    return switch (type) {
      EnemyType.grunt => Vector2(-4, 0),
      EnemyType.sprinter => Vector2(0, 0),
      EnemyType.tank => Vector2(0, 0),
      EnemyType.brute => Vector2(0, 0),
      EnemyType.scout => Vector2(0, 0),
      EnemyType.spitter => Vector2(0, 0),
      EnemyType.armored => Vector2(0, 0),
      EnemyType.swarm => Vector2(0, 0),
      EnemyType.elite => Vector2(0, 0),
      EnemyType.boss => Vector2(0, 0),
    };
  }

  Vector2 get effectCenter {
    final local = position - gameRef.mapOrigin;
    final x = (local.x / gameRef.tileSize).floor();
    final y = (local.y / gameRef.tileSize).floor();
    final clampedX = x.clamp(0, gameRef.gridWidth - 1);
    final clampedY = y.clamp(0, gameRef.gridHeight - 1);
    return gameRef.mapOrigin + Vector2(
      (clampedX + 0.5) * gameRef.tileSize,
      (clampedY + 0.5) * gameRef.tileSize,
    );
  }

  static const double _frameTime = 0.12;
  static const int _frames = 5;
  static const double _hitDuration = _frames * _frameTime;
  static const double _dieDuration = _frames * _frameTime;
  static const double _attackPulseDuration = 0.18;
  static const double _attackPulseScale = 0.12;
  static const double _attackNudgeDuration = 0.12;
  static const double _attackNudgeScale = 0.18;

  Enemy({
    required this.gameRef,
    required this.type,
    required this.def,
    required this.path,
    required this.hpMultiplier,
    required this.speedMultiplier,
    required this.rewardMultiplier,
  }) : super() {
    final tile = gameRef.tileSize;
    size = Vector2(tile * 1.47, tile * 1.47);
    anchor = Anchor.center;

    speed = def.speed * speedMultiplier;
    maxHp = def.hp * hpMultiplier;
    hp = maxHp;
    position = path.first.toWorld(gameRef);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final image = await gameRef.images.load(_enemySpritePath(type));
    final sheet = SpriteSheet.fromColumnsAndRows(
      image: image,
      columns: 5,
      rows: 4,
    );

    // Avoid texture bleeding between frames when scaled.
    paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    animations = {
      EnemyAnim.right: sheet.createAnimation(
        row: 0,
        stepTime: _frameTime,
        from: 0,
        to: _frames,
      ),
      EnemyAnim.up: sheet.createAnimation(
        row: 1,
        stepTime: _frameTime,
        from: 0,
        to: _frames,
      ),
      EnemyAnim.hit: sheet.createAnimation(
        row: 2,
        stepTime: _frameTime,
        from: 0,
        to: _frames,
        loop: false,
      ),
      EnemyAnim.die: sheet.createAnimation(
        row: 3,
        stepTime: _frameTime,
        from: 0,
        to: _frames,
        loop: false,
      ),
    };
    current = EnemyAnim.right;
    scale = Vector2(1, 1);

    if (_visualOffsetCache.containsKey(type)) {
      visualOffset = _visualOffsetCache[type]!.clone();
    } else {
      final rawOffset =
          await _computeVisualOffset(image, columns: 5, rows: 4);
      final frameW = image.width / 5.0;
      final frameH = image.height / 4.0;
      final scaleX = size.x / frameW;
      final scaleY = size.y / frameH;
      visualOffset = Vector2(rawOffset.x * scaleX, rawOffset.y * scaleY);
      _visualOffsetCache[type] = visualOffset.clone();
    }
  }

  Future<Vector2> _computeVisualOffset(ui.Image image,
      {required int columns, required int rows}) async {
    final data =
        await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return Vector2.zero();
    final bytes = data.buffer.asUint8List();
    final width = image.width;
    final height = image.height;
    final frameW = (width / columns).floor();
    final frameH = (height / rows).floor();

    double sumX = 0;
    double sumY = 0;
    int count = 0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < columns; col++) {
        final x0 = col * frameW;
        final y0 = row * frameH;
        int minX = frameW;
        int minY = frameH;
        int maxX = -1;
        int maxY = -1;

        for (int y = y0; y < y0 + frameH; y++) {
          for (int x = x0; x < x0 + frameW; x++) {
            final idx = (y * width + x) * 4 + 3;
            if (bytes[idx] > 0) {
              final localX = x - x0;
              final localY = y - y0;
              if (localX < minX) minX = localX;
              if (localY < minY) minY = localY;
              if (localX > maxX) maxX = localX;
              if (localY > maxY) maxY = localY;
            }
          }
        }

        if (maxX >= 0 && maxY >= 0) {
          final centerX = (minX + maxX) / 2.0;
          final centerY = (minY + maxY) / 2.0;
          final offsetX = centerX - frameW / 2.0;
          final offsetY = centerY - frameH / 2.0;
          sumX += offsetX;
          sumY += offsetY;
          count++;
        }
      }
    }

    if (count == 0) return Vector2.zero();
    return Vector2(sumX / count, sumY / count);
  }

  void updateWorldPosition() {
    position = path[pathIndex].toWorld(gameRef);
  }

  void _applyDirection(Vector2 dir) {
    final dx = dir.x;
    final dy = dir.y;
    if (dx.abs() >= dy.abs()) {
      if (dx >= 0) {
        current = EnemyAnim.right;
        scale = Vector2(1, 1);
      } else {
        current = EnemyAnim.right;
        scale = Vector2(-1, 1);
      }
    } else {
      if (dy >= 0) {
        current = EnemyAnim.up;
        scale = Vector2(1, -1);
      } else {
        current = EnemyAnim.up;
        scale = Vector2(1, 1);
      }
    }
    lastMoveAnim = current ?? EnemyAnim.right;
    lastScale = scale.clone();
  }

  @override
  void update(double dt) {
    super.update(dt);
    enemyStatus.update(dt);
    if (dotTextCooldown > 0) {
      dotTextCooldown = (dotTextCooldown - dt).clamp(0.0, double.infinity);
    }
    if (dotTextCooldown <= 0 && dotTextAccum > 0) {
      gameRef.spawnDamageText(effectCenter, dotTextAccum);
      dotTextAccum = 0;
      dotTextCooldown = 0.25;
    }
    if (enemyStatus.isFrozen) {
      if (atCore) {
        _applyAttackPulse();
        return;
      }
    }

    if (attackPulse > 0) {
      attackPulse = (attackPulse - dt).clamp(0.0, _attackPulseDuration);
    }
    if (attackNudge > 0) {
      attackNudge = (attackNudge - dt).clamp(0.0, _attackNudgeDuration);
    }
    if (isDying) {
      deathTimer += dt;
      if (deathTimer >= _dieDuration) {
        removeFromParent();
      }
      return;
    }
    if (hitTimer > 0) {
      hitTimer -= dt;
      if (hitTimer <= 0) {
        current = lastMoveAnim;
        scale = lastScale.clone();
      }
    }
    final dotDamage = enemyStatus.consumeDotDamage(dt);
    if (dotDamage > 0) {
      final applied = takeDamage(dotDamage, showText: false);
      if (applied > 0) {
        dotTextAccum += applied;
      }
      if (isDying || isRemoved) {
        return;
      }
    }
    final pullSteps = enemyStatus.consumePullSteps();
    if (pullSteps > 0) {
      final nextIndex = (pathIndex - pullSteps).clamp(0, path.length - 1);
      pathIndex = nextIndex;
      atCore = false;
      attackTimer = 0;
      position = path[pathIndex].toWorld(gameRef);
      final denom = (path.length - 1);
      if (denom > 0) {
        progress = (pathIndex / denom).clamp(0.0, 1.0);
      } else {
        progress = 0;
      }
      return;
    }
    if (atCore) {
      attackTimer += dt * enemyStatus.timeDilationMultiplier;
      if (attackTimer >= attackInterval) {
        attackTimer = 0;
        gameRef.damageCore(attackDamage * enemyStatus.attackWeakenMultiplier);
        final effectPos =
            gameRef.core.position.clone() + Vector2(-gameRef.tileSize * 0.35, 0);
        gameRef.spawnEnemyEffect(type, effectPos, scale: 2.24);
        attackPulse = _attackPulseDuration;
        final dir = (gameRef.core.position - position);
        attackDir = dir.length > 0 ? dir.normalized() : Vector2(0, 1);
        attackNudge = _attackNudgeDuration;
      }
      _applyAttackPulse();
      return;
    }

    if (pathIndex >= path.length - 1) {
      if (gameRef.loopEnemiesOnPath) {
        pathIndex = 0;
        position = path.first.toWorld(gameRef);
        progress = 0;
        return;
      }
      atCore = true;
      position = path.last.toWorld(gameRef) + Vector2(-gameRef.tileSize, 0);
      progress = 1;
      return;
    }

    final target = path[pathIndex + 1].toWorld(gameRef);
    final toTarget = target - position;
    final distance = toTarget.length;

    if (hitTimer <= 0) {
      _applyDirection(toTarget);
    }
    _applyAttackPulse();

    final moveSpeed =
        speed * enemyStatus.slowMultiplier * enemyStatus.timeDilationMultiplier;
    if (enemyStatus.isFrozen) {
      return;
    }

    if (distance < moveSpeed * dt) {
      position = target;
      pathIndex++;
    } else {
      position += toTarget.normalized() * moveSpeed * dt;
    }

    final denom = (path.length - 1);
    if (denom > 0) {
      progress = (pathIndex / denom).clamp(0.0, 1.0);
    }
  }

  double takeDamage(double dmg, {bool showText = true}) {
    final adjustedDamage = dmg * enemyStatus.vulnerabilityMultiplier;
    if (showText) {
      gameRef.spawnDamageText(effectCenter, adjustedDamage);
    }
    if (gameRef.debugInfiniteEnemyHp) {
      return 0;
    }
    hp -= adjustedDamage;
    if (hp <= 0) {
      gameRef.registerEnemyKill(def);
      gameRef.addBattleGoldScaled(
        def.rewardBattleGold,
        extraMultiplier: rewardMultiplier,
      );
      if (!isDying) {
        isDying = true;
        deathTimer = 0;
        current = EnemyAnim.die;
      }
      return adjustedDamage;
    }
    if (!isDying) {
      hitTimer = _hitDuration;
      current = EnemyAnim.hit;
    }
    return adjustedDamage;
  }


  @override
  void render(Canvas canvas) {
    if (attackNudge > 0) {
      final t = (attackNudge / _attackNudgeDuration).clamp(0.0, 1.0);
      final offset = attackDir * (size.x * _attackNudgeScale * t);
      canvas.save();
      canvas.translate(offset.x, offset.y);
      super.render(canvas);
      canvas.restore();
    } else {
      super.render(canvas);
    }

    final hpWidth = size.x * 0.7;
    final hpHeight = 3.0;
    final hpRatio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);

    final bgPaint = Paint()..color = const Color(0xFF2B2B2B);
    final fgColor = hpRatio <= 0.2
        ? const Color(0xFFE53935)
        : (hpRatio <= 0.5 ? const Color(0xFFFFC107) : const Color(0xFF8BC34A));
    final fgPaint = Paint()..color = fgColor;

    final baseOffset = Vector2(size.x * 0.46, 0);
    final offset = baseOffset + _hpBarOffset();
    final barX = offset.x;
    final barY = -hpHeight / 2 + offset.y;
    canvas.drawRect(
      Rect.fromLTWH(barX - hpWidth / 2, barY, hpWidth, hpHeight),
      bgPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(barX - hpWidth / 2, barY, hpWidth * hpRatio, hpHeight),
      fgPaint,
    );

  }

  void _applyAttackPulse() {
    if (attackPulse <= 0) {
      scale = lastScale.clone();
      return;
    }
    final t = (attackPulse / _attackPulseDuration).clamp(0.0, 1.0);
    final s = 1.0 + _attackPulseScale * t;
    scale = Vector2(lastScale.x * s, lastScale.y * s);
  }
}

class Projectile extends PositionComponent {
  final TowerDefenseGame gameRef;
  final Vector2 targetPos;
  final Enemy target;
  final double damage;
  final double speed;
  final double sizePx;
  final Color? color;
  final String towerId;
  final bool isUltimate;

  late final Vector2 direction;

  Projectile({
    required this.gameRef,
    required Vector2 origin,
    required this.targetPos,
    required this.target,
    required this.damage,
    required this.speed,
    required this.sizePx,
    this.color,
    required this.towerId,
    required this.isUltimate,
  }) {
    position = origin;
    size = Vector2(sizePx, sizePx);
    anchor = Anchor.center;
    direction = (targetPos - origin).normalized();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final step = speed * dt;
    final toTarget = targetPos - position;
    if (toTarget.length <= step) {
      position = targetPos;
      _impact();
      return;
    }
    position += direction * step;
  }

  void _impact() {
    if (!target.isRemoved) {
      final hitRadius = math.max(6, target.size.x * 0.4);
      if (target.position.distanceTo(position) <= hitRadius) {
        target.takeDamage(damage);
      }
    }
    gameRef.spawnTowerEffect(towerId, isUltimate ? 3 : 2, position.clone());
    removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = color ?? const Color(0xFFFFD54F);
    canvas.drawCircle(Offset.zero, size.x * 0.5, paint);
  }
}

class HitscanEffect extends PositionComponent {
  final Vector2 start;
  final Vector2 end;
  double life;
  final Color? color;
  final double strokeWidth;

  HitscanEffect({
    required this.start,
    required this.end,
    this.color,
    this.strokeWidth = 2,
    double life = 0.08,
  }) : life = life {
    priority = 900;
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
    final paint = Paint()
      ..color = color ?? const Color(0xFFFF8F00)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(start.x, start.y), Offset(end.x, end.y), paint);
  }
}



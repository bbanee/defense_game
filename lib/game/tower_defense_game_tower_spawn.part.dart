part of 'tower_defense_game.dart';

class Tower extends PositionComponent {
  final TowerDefenseGame gameRef;
  final String towerId;
  final GridPoint grid;
  final TowerDef def;
  final int initialCost;
  final TowerLobbyUpgradeProgress lobbyUpgrade;
  final Map<String, dynamic>? lobbyPreset;

  late double range;
  late double damage;
  late double fireRate;
  late Paint paint;
  Sprite? leftDownSprite;
  Sprite? rightDownSprite;
  Sprite? currentSprite;

  double cooldown = 0;
  late final TowerRuntimeState state;

  Tower({
    required this.gameRef,
    required this.towerId,
    required this.grid,
    required this.def,
    required this.initialCost,
    required this.lobbyUpgrade,
    required this.lobbyPreset,
  }) {
    final tile = gameRef.tileSize;
    size = Vector2(tile * 1.5, tile * 1.5);
    anchor = Anchor.center;
    updateWorldPosition();

    final permanentLevel = gameRef._getTowerPermanentLevel(def.id);
    state = TowerRuntimeState(
      initialCost: initialCost,
      permanentLevel: permanentLevel,
      growthConfig: gameRef.balanceConfig.growthForTower(def.id),
      lobbyDamageMultiplier: 1.0 + _operationsBonusFor('stat.damage_pct'),
      lobbyFireRateMultiplier:
          (1.0 - _operationsBonusFor('stat.fire_rate_pct')).clamp(0.7, 1.0),
      lobbyRangePercent: _operationsBonusFor('stat.range_pct'),
    );
    _applyStatsFromState();
    paint = Paint()..color = _rarityColor(def.rarity);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final path = _towerSpritePath(towerId);
    if (path == null) return;
    try {
      final image = await gameRef.images.load(path);
      final sheet =
          SpriteSheet.fromColumnsAndRows(image: image, columns: 2, rows: 1);
      // frame 0: left-down, frame 1: right-down (assumed)
      leftDownSprite = sheet.getSprite(0, 0);
      rightDownSprite = sheet.getSprite(0, 1);
      currentSprite = rightDownSprite;
    } catch (_) {
      leftDownSprite = null;
      rightDownSprite = null;
      currentSprite = null;
    }
  }

  void updateWorldPosition() {
    position = grid.toWorld(gameRef);
  }

  void updateTower(double dt, List<Enemy> enemies) {
    cooldown -= dt;
    if (cooldown > 0) return;

    final target = _findTarget(enemies);
    if (target == null) {
      _resetFacing();
      return;
    }
    _updateFacing(target.position - position);

    final isUltimate =
        def.ultimateChance > 0 && gameRef.rng.nextDouble() < def.ultimateChance;
    final finalDamage =
        isUltimate ? damage * def.ultimateDamageMultiplier : damage;
    unawaited(
      AppAudioService.instance.playTowerAttack(
        towerId,
        isUltimate: isUltimate,
        attackIntervalSec: fireRate / gameRef.timeScale,
        sourceKey: '${grid.x},${grid.y}',
      ),
    );

    void applyHit(Enemy hitTarget) {
      final hitDamage = _applySynergyDamageMultiplier(hitTarget, finalDamage);
      gameRef.spawnTowerEffect(
        towerId,
        2,
        hitTarget.effectCenter,
        scale: isUltimate ? 2.2 : 2.0,
      );
      hitTarget.takeDamage(hitDamage);
      _applyProjectileSplash(hitTarget, hitDamage);
      for (final baseSpec in def.effects) {
        final spec = _applyIdentityModifier(baseSpec);
        if (!spec.appliesAtLevel(state.level)) continue;
        if (spec.chance != null && gameRef.rng.nextDouble() > spec.chance!) {
          continue;
        }
        if (spec.type == 'max_hp_burst') {
          final ratio = (spec.value ?? 0.0).clamp(0.0, 0.25);
          final capMult = (spec.durationSec ?? 1.5).clamp(0.5, 3.0);
          final bonus = math.min(hitTarget.maxHp * ratio, hitDamage * capMult);
          if (bonus > 0) {
            hitTarget.takeDamage(bonus);
            _showSpecialHitEffect(hitTarget);
          }
          continue;
        }
        if (spec.type == 'chain_arc') {
          _applyChainArc(hitTarget, hitDamage, spec);
          continue;
        }
        _applyEnemyStatusEffect(hitTarget, spec);
      }
      if (isUltimate) {
        _applyUltimateAlpha(hitTarget, hitDamage);
      }
    }

    final targetPos = target.effectCenter;
    final fireDir = (targetPos - position);
    final startPos = fireDir.length2 > 0
        ? position + fireDir.normalized() * (gameRef.tileSize * 0.22)
        : position.clone();
    if (def.attackType == 'hitscan') {
      final beam = SpriteHitscanEffect(
        gameRef: gameRef,
        spritePath: _towerEffectPath(towerId, isUltimate ? 3 : 1),
        start: startPos,
        end: targetPos,
        life: isUltimate ? 1.0 : 0.09,
        lengthScale: isUltimate ? 2.0 : 1.0,
        thicknessScale: isUltimate ? 3.7 : 1.0,
      );
      gameRef.add(beam);
      applyHit(target);
      cooldown = fireRate;
      return;
    }
    final effect = TowerEffectProjectile(
      gameRef: gameRef,
      spritePath: _towerEffectPath(towerId, isUltimate ? 3 : 1),
      start: startPos,
      target: target,
      targetPos: targetPos,
      speed: isUltimate
          ? 650
          : (def.projectileSpeed > 0 ? def.projectileSpeed : 700),
      sizeScale: isUltimate ? 3.8 : 2.0,
      lingerDuration: isUltimate ? 0.5 : 0.0,
      onArrive: () => applyHit(target),
    );
    gameRef.add(effect);
    cooldown = fireRate;
  }

  void _applyProjectileSplash(Enemy primary, double baseDamage) {
    if (def.attackType != 'projectile') return;
    if (def.projectileSize < 30) return;

    final ratio = switch (towerId) {
      'mortar_basic' => 0.45,
      'cannon_basic' => 0.35,
      'singularity_basic' => 0.25,
      _ => 0.3,
    };
    final radiusTiles = (def.projectileSize / 24.0).clamp(1.0, 1.8);
    final splashDamage = baseDamage * ratio;

    for (final enemy in _nearbyEnemies(primary, radiusTiles: radiusTiles, maxTargets: 4)) {
      enemy.takeDamage(splashDamage);
      gameRef.spawnTowerEffect(towerId, 2, enemy.effectCenter, scale: 1.1);
    }
  }

  void _applyChainArc(Enemy primary, double baseDamage, TowerEffectSpec spec) {
    final ratio = (spec.value ?? 0.35).clamp(0.05, 1.2);
    final maxTargets = (spec.maxStack ?? 1).clamp(1, 5);
    final radiusTiles = (spec.durationSec ?? 1.4).clamp(0.5, 3.0);
    final arcDamage = baseDamage * ratio;

    for (final enemy in _nearbyEnemies(primary, radiusTiles: radiusTiles, maxTargets: maxTargets)) {
      enemy.takeDamage(arcDamage);
      gameRef.spawnTowerEffect(towerId, 2, enemy.effectCenter, scale: 1.2);
      _showSpecialHitEffect(enemy);
    }
  }

  void _applyUltimateAlpha(Enemy primary, double hitDamage) {
    switch (towerId) {
      case 'cannon_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.6, maxTargets: 3)) {
          enemy.takeDamage(hitDamage * 0.55);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'slow', value: 0.12, durationSec: 1.1),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.3);
        }
        break;
      case 'rapid_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.3, maxTargets: 4)) {
          enemy.takeDamage(hitDamage * 0.38);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'vulnerability',
              value: 0.12,
              durationSec: 1.2,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.45);
        }
        break;
      case 'shotgun_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.15, maxTargets: 3)) {
          enemy.takeDamage(hitDamage * 0.45);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'slow', value: 0.22, durationSec: 1.2),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.2);
        }
        break;
      case 'frost_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.2, maxTargets: 2)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
                type: 'freeze', durationSec: 0.45, stackThreshold: 0),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.2);
        }
        break;
      case 'drone_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.5, maxTargets: 4)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'attack_weaken',
              value: 0.2,
              durationSec: 2.4,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.2);
        }
        break;
      case 'chain_basic':
        gameRef.spawnTowerEffect(towerId, 3, primary.effectCenter, scale: 1.45);
        _applyChainArc(
          primary,
          hitDamage,
          const TowerEffectSpec(
            type: 'chain_arc',
            value: 0.5,
            maxStack: 4,
            durationSec: 1.9,
          ),
        );
        break;
      case 'missile_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.8, maxTargets: 4)) {
          enemy.takeDamage(hitDamage * 0.6);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'vulnerability',
              value: 0.18,
              durationSec: 2.2,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.35);
        }
        break;
      case 'support_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.9, maxTargets: 5)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'vulnerability',
              value: 0.14,
              durationSec: 2.3,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.1);
        }
        gameRef.coreShield =
            (gameRef.coreShield + 2.0).clamp(0.0, gameRef.coreMaxShield);
        gameRef.core.setStats(
          gameRef.coreHp,
          gameRef.coreMaxHp,
          gameRef.coreShield,
          gameRef.coreMaxShield,
        );
        break;
      case 'laser_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.4, maxTargets: 3)) {
          _applyEnemyStatusEffect(
            enemy,
            TowerEffectSpec(
              type: 'dot',
              value: math.max(6.0, hitDamage * 0.18),
              durationSec: 2.2,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.18);
        }
        break;
      case 'sniper_basic':
        final hpRatio = primary.maxHp > 0 ? primary.hp / primary.maxHp : 1.0;
        if (hpRatio <= 0.22) {
          primary.takeDamage(math.max(0, hitDamage * 1.1));
          _showSpecialHitEffect(primary);
        }
        final extra = _nearbyEnemies(primary, radiusTiles: 2.2, maxTargets: 1);
        if (extra.isNotEmpty) {
          extra.first.takeDamage(hitDamage * 0.65);
          _showSpecialHitEffect(extra.first);
          gameRef.spawnTowerEffect(
            towerId,
            3,
            extra.first.effectCenter,
            scale: 1.2,
          );
        }
        break;
      case 'gravity_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.6, maxTargets: 4)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'pull', value: 2, chance: 1.0),
          );
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'slow', value: 0.16, durationSec: 1.3),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.2);
        }
        break;
      case 'infection_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.5, maxTargets: 4)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'dot', value: 12, durationSec: 2.8),
          );
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'vulnerability',
              value: 0.08,
              durationSec: 1.8,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.15);
        }
        break;
      case 'chrono_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 1.55, maxTargets: 5)) {
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'time_dilate',
              value: 0.45,
              durationSec: 1.6,
            ),
          );
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'slow', value: 0.12, durationSec: 1.0),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.25);
        }
        break;
      case 'singularity_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 2.0, maxTargets: 6)) {
          enemy.takeDamage(hitDamage * 0.55);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(type: 'pull', value: 2, chance: 1.0),
          );
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'max_hp_burst',
              value: 0.03,
              durationSec: 1.2,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.35);
        }
        break;
      case 'mortar_basic':
        for (final enemy
            in _nearbyEnemies(primary, radiusTiles: 2.0, maxTargets: 5)) {
          enemy.takeDamage(hitDamage * 0.35);
          _applyEnemyStatusEffect(
            enemy,
            const TowerEffectSpec(
              type: 'slow',
              value: 0.2,
              durationSec: 2.0,
              maxStack: 4,
            ),
          );
          gameRef.spawnTowerEffect(towerId, 3, enemy.effectCenter, scale: 1.28);
        }
        break;
    }
  }

  void _applyEnemyStatusEffect(Enemy enemy, TowerEffectSpec spec) {
    enemy.enemyStatus.apply(spec);
    _showSpecialHitEffect(enemy);
  }

  void _showSpecialHitEffect(Enemy enemy, {double scale = 1.2}) {
    gameRef.spawnTowerSpecialEffect(towerId, enemy, scale: scale);
  }

  List<Enemy> _nearbyEnemies(
    Enemy primary, {
    required double radiusTiles,
    required int maxTargets,
  }) {
    final radius = gameRef.tileSize * radiusTiles;
    final radiusSq = radius * radius;
    final filtered = <(double, Enemy)>[];
    for (final e in gameRef.enemies) {
      if (e.isRemoved || e.isDying || e == primary) continue;
      final dSq = e.position.distanceToSquared(primary.position);
      if (dSq > radiusSq) continue;
      filtered.add((dSq, e));
      if (filtered.length >= maxTargets * 3) break;
    }
    filtered.sort((a, b) => a.$1.compareTo(b.$1));
    return filtered.take(maxTargets).map((e) => e.$2).toList();
  }

  double _trackBonus(String trackId) {
    final entry = lobbyPreset?[trackId];
    if (entry is! Map<String, dynamic>) return 0.0;
    final perLevel = (entry['perLevel'] as num?)?.toDouble() ?? 0.0;
    final cap = (entry['cap'] as num?)?.toDouble() ?? 0.0;
    final level = switch (trackId) {
      'identity' => lobbyUpgrade.identity,
      'operations' => lobbyUpgrade.operations,
      'synergy' => lobbyUpgrade.synergy,
      _ => 0,
    };
    return math.min(cap, perLevel * level);
  }

  double _operationsBonusFor(String key) {
    final entry = lobbyPreset?['operations'];
    if (entry is! Map<String, dynamic>) return 0.0;
    if (entry['key'] != key) return 0.0;
    return _trackBonus('operations');
  }

  TowerEffectSpec _applyIdentityModifier(TowerEffectSpec spec) {
    final entry = lobbyPreset?['identity'];
    if (entry is! Map<String, dynamic>) return spec;
    final key = entry['key']?.toString() ?? '';
    final bonus = _trackBonus('identity');
    if (bonus <= 0) return spec;

    final prefix = 'effect.${spec.type}.';
    if (!key.startsWith(prefix)) return spec;
    final suffix = key.substring(prefix.length);

    switch (suffix) {
      case 'value':
        return spec.copyWith(value: (spec.value ?? 0) + bonus);
      case 'value_pct':
        return spec.copyWith(value: (spec.value ?? 0) * (1.0 + bonus));
      case 'duration_pct':
        return spec.copyWith(
            durationSec: (spec.durationSec ?? 0) * (1.0 + bonus));
      case 'chance_flat':
        return spec.copyWith(
            chance: ((spec.chance ?? 0) + bonus).clamp(0.0, 1.0));
      case 'max_targets':
        return spec.copyWith(maxStack: (spec.maxStack ?? 1) + bonus.round());
      default:
        return spec;
    }
  }

  double _applySynergyDamageMultiplier(Enemy target, double baseDamage) {
    final entry = lobbyPreset?['synergy'];
    if (entry is! Map<String, dynamic>) return baseDamage;
    final key = entry['key']?.toString() ?? '';
    final bonus = _trackBonus('synergy');
    if (bonus <= 0) return baseDamage;

    bool active = false;
    if (key == 'vs.vulnerable_damage_pct' && target.enemyStatus.isVulnerable) {
      active = true;
    } else if (key == 'vs.slowed_damage_pct' &&
        target.enemyStatus.slowMultiplier < 1.0) {
      active = true;
    } else if (key == 'vs.frozen_damage_pct' && target.enemyStatus.isFrozen) {
      active = true;
    } else if (key == 'vs.dot_target_damage_pct' &&
        target.enemyStatus.isInfected) {
      active = true;
    } else if (key == 'vs.time_dilated_damage_pct' &&
        target.enemyStatus.isTimeDilated) {
      active = true;
    }

    if (!active) return baseDamage;
    return baseDamage * (1.0 + bonus);
  }

  int get nextUpgradeCost {
    final multiplier = 1.0 + (state.level * def.upgradeCostMultiplier);
    return (def.upgradeCostBase *
            multiplier *
            gameRef.difficultyDef.towerUpgradeCostMultiplier)
        .round();
  }

  int get sellRefund {
    return (state.totalSpent *
            def.sellRefundRate *
            gameRef.difficultyDef.sellRefundMultiplier)
        .round();
  }

  void upgrade() {
    final cost = nextUpgradeCost;
    state.upgrade(cost: cost);
    _applyStatsFromState();
  }

  void cycleModule() {
    final values = TacticalModule.values;
    final nextIndex = (state.module.index + 1) % values.length;
    state.setModule(values[nextIndex]);
    _applyStatsFromState();
  }

  Enemy? _findTarget(List<Enemy> enemies) {
    final rangeSq = range * range;

    // nearest: 정렬 없이 선형 탐색으로 최소 거리 적만 반환
    if (gameRef.currentRule == TargetingRule.nearest) {
      Enemy? best;
      double bestDSq = double.infinity;
      for (final enemy in enemies) {
        if (enemy.isRemoved) continue;
        final dSq = enemy.position.distanceToSquared(position);
        if (dSq <= rangeSq && dSq < bestDSq) {
          bestDSq = dSq;
          best = enemy;
        }
      }
      return best;
    }

    // 그 외 타겟팅 규칙: 범위 내 적 필터링 후 비교
    final inRange = <Enemy>[];
    for (final enemy in enemies) {
      if (enemy.isRemoved) continue;
      if (enemy.position.distanceToSquared(position) <= rangeSq) {
        inRange.add(enemy);
      }
    }
    if (inRange.isEmpty) return null;

    return switch (gameRef.currentRule) {
      TargetingRule.farthestProgress =>
        inRange.reduce((a, b) => a.progress >= b.progress ? a : b),
      TargetingRule.highestHp =>
        inRange.reduce((a, b) => a.hp >= b.hp ? a : b),
      TargetingRule.lowestHp =>
        inRange.reduce((a, b) => a.hp <= b.hp ? a : b),
      _ => inRange.first,
    };
  }

  @override
  void render(Canvas canvas) {
    if (currentSprite != null) {
      currentSprite!.render(
        canvas,
        position: Vector2.zero(),
        size: size,
      );
    } else {
      final rect = Rect.fromLTWH(0, 0, size.x, size.y);
      canvas.drawRect(rect, paint);

      final barrelPaint = Paint()..color = const Color(0xFF1C1C1C);
      canvas.drawRect(Rect.fromLTWH(size.x / 2 - 4, 0, 8, 12), barrelPaint);
    }
    drawTowerVisualFx(
      canvas,
      Rect.fromLTWH(0, 0, size.x, size.y),
      permanentLevel: state.permanentLevel,
      towerId: towerId,
      rarity: def.rarity,
      phase: gameRef.visualFxTime,
      opacity: 0.95,
    );
  }

  void _updateFacing(Vector2 dir) {
    if (rightDownSprite == null || leftDownSprite == null) return;
    if (dir.x >= 0) {
      currentSprite = rightDownSprite;
    } else {
      currentSprite = leftDownSprite;
    }
  }

  void _resetFacing() {
    if (rightDownSprite == null) return;
    currentSprite = rightDownSprite;
  }

  void _applyStatsFromState() {
    final baseDamage = def.baseDamage * state.permanentDamageMultiplier;
    final baseFireRate = def.fireRate * state.permanentFireRateMultiplier;
    final baseRange = def.range + state.permanentRangeBonus;

    damage = baseDamage *
        state.damageMultiplier *
        state.moduleDamageMultiplier *
        state.lobbyDamageMultiplier;
    fireRate = (baseFireRate *
            state.fireRateMultiplier *
            state.moduleFireRateMultiplier *
            state.lobbyFireRateMultiplier)
        .clamp(0.15, 10.0);
    range = baseRange +
        state.rangeBonus +
        state.moduleRangeBonus +
        def.range * state.lobbyRangePercent;
  }
}

class TowerRuntimeState {
  int level = 1;
  int totalSpent = 0;
  double damageMultiplier = 1.0;
  double fireRateMultiplier = 1.0;
  double rangeBonus = 0;
  int permanentLevel = 1;
  double permanentDamageMultiplier = 1.0;
  double permanentFireRateMultiplier = 1.0;
  double permanentRangeBonus = 0;
  TacticalModule module = TacticalModule.none;
  double moduleDamageMultiplier = 1.0;
  double moduleFireRateMultiplier = 1.0;
  double moduleRangeBonus = 0;
  double lobbyDamageMultiplier = 1.0;
  double lobbyFireRateMultiplier = 1.0;
  double lobbyRangePercent = 0.0;
  final PermanentGrowthConfig growthConfig;

  TowerRuntimeState({
    required int initialCost,
    required this.permanentLevel,
    required this.growthConfig,
    this.lobbyDamageMultiplier = 1.0,
    this.lobbyFireRateMultiplier = 1.0,
    this.lobbyRangePercent = 0.0,
  }) {
    totalSpent = initialCost;
    _applyPermanentLevel(permanentLevel);
  }

  void upgrade({required int cost}) {
    level += 1;
    totalSpent += cost;
    damageMultiplier *= 1.10;
    fireRateMultiplier *= 0.95;
    rangeBonus += 2;
  }

  void setModule(TacticalModule next) {
    module = next;
    moduleDamageMultiplier = 1.0;
    moduleFireRateMultiplier = 1.0;
    moduleRangeBonus = 0;

    switch (module) {
      case TacticalModule.none:
        break;
      case TacticalModule.focus:
        moduleDamageMultiplier = 1.5;
        break;
      case TacticalModule.overclock:
        moduleFireRateMultiplier = 1.6;
        break;
      case TacticalModule.range:
        moduleRangeBonus = 16;
        break;
    }
  }

  void _applyPermanentLevel(int level) {
    final lv = level.clamp(1, 15);
    final bonusLevel = lv - 1;
    permanentDamageMultiplier =
        1.0 + bonusLevel * growthConfig.damagePercentPerLevel;
    // fireRate is attack interval(seconds), so lower is faster.
    permanentFireRateMultiplier =
        (1.0 - bonusLevel * growthConfig.fireRatePercentPerLevel)
            .clamp(0.35, 1.0);
    if (growthConfig.rangeBonusEveryLevels > 0) {
      permanentRangeBonus = bonusLevel >= growthConfig.rangeBonusEveryLevels
          ? growthConfig.rangeBonusPerStep *
              (bonusLevel ~/ growthConfig.rangeBonusEveryLevels)
          : 0.0;
    } else {
      permanentRangeBonus = 0.0;
    }
  }
}

class SpawnController extends Component {
  final TowerDefenseGame game;
  WaveDef waveDef;
  double timer = 0;
  int index = 0;
  int remainingInEntry = 0;
  double nextSpawnAt = 0;
  bool paused = false;
  int remainingTotal = 0;

  SpawnController({required this.game, required this.waveDef});

  @override
  void onMount() {
    super.onMount();
    _recalculateRemaining();
  }

  @override
  void update(double dt) {
    if (paused) return;
    timer += dt;
    // 서브스텝당 최대 스폰 수 제한 — 4x 이상 배속에서 한 프레임에
    // 적이 폭발적으로 쏟아지는 현상 방지
    int spawnedThisStep = 0;
    const maxSpawnsPerStep = 6;
    while (index < waveDef.spawns.length && spawnedThisStep < maxSpawnsPerStep) {
      final entry = waveDef.spawns[index];
      if (remainingInEntry == 0) {
        if (timer < entry.at) {
          break;
        }
        remainingInEntry = entry.count;
        nextSpawnAt = timer;
      }

      if (timer >= nextSpawnAt) {
        game.spawnEnemyById(entry.enemyId);
        remainingInEntry--;
        spawnedThisStep++;
        if (remainingInEntry > 0) {
          nextSpawnAt += entry.intervalMs / 1000.0;
        } else {
          index++;
        }
        remainingTotal -= 1;
        continue;
      }
      break;
    }
  }

  void pauseSpawning() {
    paused = true;
  }

  bool get isFinished => index >= waveDef.spawns.length;

  double get totalDurationSec {
    if (waveDef.spawns.isEmpty) return 0;
    var latest = 0.0;
    for (final entry in waveDef.spawns) {
      final endAt = entry.at +
          ((entry.count - 1).clamp(0, 9999) * entry.intervalMs / 1000.0);
      if (endAt > latest) {
        latest = endAt;
      }
    }
    return latest;
  }

  void resetWith(WaveDef nextWave) {
    waveDef = nextWave;
    timer = 0;
    index = 0;
    remainingInEntry = 0;
    nextSpawnAt = 0;
    paused = false;
    _recalculateRemaining();
  }

  void _recalculateRemaining() {
    remainingTotal = 0;
    for (final entry in waveDef.spawns) {
      remainingTotal += entry.count;
    }
  }
}

class _HudButtonData {
  final String towerId;
  final String name;
  final Color color;
  Sprite? sprite;

  _HudButtonData(this.towerId, this.name, this.color);
}

import 'dart:math' as math;

import 'package:tower_defense/domain/models/definitions.dart';

class EnemyStatus {
  double slowMultiplier = 1.0;
  double slowTimer = 0.0;
  int slowStacks = 0;
  int maxSlowStacks = 5;

  double freezeTimer = 0.0;
  double timeDilationMultiplier = 1.0;
  double timeDilationTimer = 0.0;
  int pendingPullSteps = 0;
  double dotDps = 0.0;
  double dotTimer = 0.0;
  double attackWeakenMultiplier = 1.0;
  double attackWeakenTimer = 0.0;
  double vulnerabilityMultiplier = 1.0;
  double vulnerabilityTimer = 0.0;

  bool get isFrozen => freezeTimer > 0;
  bool get isTimeDilated => timeDilationMultiplier < 1.0 && timeDilationTimer > 0;
  bool get isInfected => dotDps > 0 && dotTimer > 0;
  bool get isAttackWeakened => attackWeakenMultiplier < 1.0 && attackWeakenTimer > 0;
  bool get isVulnerable => vulnerabilityMultiplier > 1.0 && vulnerabilityTimer > 0;

  void update(double dt) {
    if (slowTimer > 0) {
      slowTimer = (slowTimer - dt).clamp(0.0, double.infinity);
      if (slowTimer <= 0) {
        slowMultiplier = 1.0;
        slowStacks = 0;
      }
    }

    if (freezeTimer > 0) {
      freezeTimer = (freezeTimer - dt).clamp(0.0, double.infinity);
      if (freezeTimer < 0) {
        freezeTimer = 0;
      }
    }

    if (timeDilationTimer > 0) {
      timeDilationTimer = (timeDilationTimer - dt).clamp(0.0, double.infinity);
      if (timeDilationTimer <= 0) {
        timeDilationTimer = 0;
        timeDilationMultiplier = 1.0;
      }
    }

    if (vulnerabilityTimer > 0) {
      vulnerabilityTimer = (vulnerabilityTimer - dt).clamp(0.0, double.infinity);
      if (vulnerabilityTimer <= 0) {
        vulnerabilityTimer = 0;
        vulnerabilityMultiplier = 1.0;
      }
    }

    if (dotTimer > 0) {
      dotTimer = (dotTimer - dt).clamp(0.0, double.infinity);
      if (dotTimer <= 0) {
        dotTimer = 0;
        dotDps = 0.0;
      }
    }

    if (attackWeakenTimer > 0) {
      attackWeakenTimer = (attackWeakenTimer - dt).clamp(0.0, double.infinity);
      if (attackWeakenTimer <= 0) {
        attackWeakenTimer = 0;
        attackWeakenMultiplier = 1.0;
      }
    }
  }

  void apply(TowerEffectSpec effect) {
    switch (effect.type) {
      case 'slow':
        final rawValue = effect.value ?? 0.0;
        final factor = math.max(0.0, math.min(0.95, rawValue));
        slowMultiplier = (slowMultiplier * (1.0 - factor)).clamp(0.1, 1.0);
        slowTimer = effect.durationSec ?? 1.0;
        if (effect.maxStack != null && effect.maxStack! > 0) {
          maxSlowStacks = effect.maxStack!;
        }
        slowStacks = (slowStacks + 1).clamp(0, maxSlowStacks);
        break;
      case 'freeze':
        final threshold = effect.stackThreshold ?? 0;
        if (threshold <= 0 || slowStacks >= threshold) {
          freezeTimer = effect.durationSec ?? effect.freezeDurationSec ?? 0.0;
          slowStacks = 0;
        }
        break;
      case 'vulnerability':
        final rawValue = effect.value ?? 0.0;
        final bonus = math.max(0.0, math.min(1.5, rawValue));
        vulnerabilityMultiplier = math.max(vulnerabilityMultiplier, 1.0 + bonus);
        vulnerabilityTimer = math.max(vulnerabilityTimer, effect.durationSec ?? 1.5);
        break;
      case 'time_dilate':
        final rawValue = effect.value ?? 0.0;
        final factor = math.max(0.0, math.min(0.8, rawValue));
        final multiplier = (1.0 - factor).clamp(0.2, 1.0);
        timeDilationMultiplier = math.min(timeDilationMultiplier, multiplier);
        timeDilationTimer = math.max(timeDilationTimer, effect.durationSec ?? 1.2);
        break;
      case 'pull':
        final rawValue = effect.value ?? 1.0;
        final steps = math.max(1, math.min(4, rawValue.round()));
        pendingPullSteps = (pendingPullSteps + steps).clamp(0, 8);
        break;
      case 'dot':
        final rawValue = effect.value ?? 0.0;
        final dps = math.max(0.0, rawValue);
        dotDps = math.max(dotDps, dps);
        dotTimer = math.max(dotTimer, effect.durationSec ?? 2.0);
        break;
      case 'attack_weaken':
        final rawValue = effect.value ?? 0.0;
        final factor = math.max(0.0, math.min(0.8, rawValue));
        final next = (1.0 - factor).clamp(0.2, 1.0);
        attackWeakenMultiplier = math.min(attackWeakenMultiplier, next);
        attackWeakenTimer = math.max(attackWeakenTimer, effect.durationSec ?? 2.0);
        break;
      default:
        break;
    }
  }

  int consumePullSteps() {
    final steps = pendingPullSteps;
    pendingPullSteps = 0;
    return steps;
  }

  double consumeDotDamage(double dt) {
    if (dotTimer <= 0 || dotDps <= 0) {
      return 0.0;
    }
    return dotDps * dt;
  }

  void reset() {
    slowMultiplier = 1.0;
    slowTimer = 0.0;
    slowStacks = 0;
    maxSlowStacks = 5;
    freezeTimer = 0.0;
    timeDilationMultiplier = 1.0;
    timeDilationTimer = 0.0;
    pendingPullSteps = 0;
    dotDps = 0.0;
    dotTimer = 0.0;
    attackWeakenMultiplier = 1.0;
    attackWeakenTimer = 0.0;
    vulnerabilityMultiplier = 1.0;
    vulnerabilityTimer = 0.0;
  }
}

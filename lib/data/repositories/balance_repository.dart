import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

class BalanceConfig {
  final PermanentGrowthConfig defaultPermanentGrowth;
  final Map<String, PermanentGrowthConfig> towerGrowthOverrides;
  final CoreBalanceConfig core;

  const BalanceConfig({
    required this.defaultPermanentGrowth,
    required this.towerGrowthOverrides,
    required this.core,
  });

  factory BalanceConfig.fromJson(Map<String, dynamic> json) {
    final overrides = <String, PermanentGrowthConfig>{};
    final rawOverrides = json['towerGrowthOverrides'] as Map<String, dynamic>? ?? {};
    rawOverrides.forEach((key, value) {
      overrides[key] = PermanentGrowthConfig.fromJson(value as Map<String, dynamic>);
    });

    return BalanceConfig(
      defaultPermanentGrowth: PermanentGrowthConfig.fromJson(
        json['defaultPermanentGrowth'] as Map<String, dynamic>,
      ),
      towerGrowthOverrides: overrides,
      core: CoreBalanceConfig.fromJson(
        json['core'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  PermanentGrowthConfig growthForTower(String towerId) {
    return towerGrowthOverrides[towerId] ?? defaultPermanentGrowth;
  }
}

class CoreBalanceConfig {
  final CoreUpgradeTrack hp;
  final CoreUpgradeTrack shield;
  final CoreUpgradeTrack defense;

  const CoreBalanceConfig({
    required this.hp,
    required this.shield,
    required this.defense,
  });

  factory CoreBalanceConfig.fromJson(Map<String, dynamic> json) {
    return CoreBalanceConfig(
      hp: CoreUpgradeTrack.fromJson(
        json['hp'] as Map<String, dynamic>? ??
            const {
              'baseCost': 3000,
              'costMultiplier': 1.55,
              'growthMultiplier': 1.02,
            },
      ),
      shield: CoreUpgradeTrack.fromJson(
        json['shield'] as Map<String, dynamic>? ??
            const {
              'baseCost': 5000,
              'costMultiplier': 1.68,
              'growthMultiplier': 1.03,
            },
      ),
      defense: CoreUpgradeTrack.fromJson(
        json['defense'] as Map<String, dynamic>? ??
            const {
              'baseCost': 10000,
              'costMultiplier': 1.85,
              'flatIncrease': 0.008,
              'cap': 0.45,
            },
      ),
    );
  }
}

class CoreUpgradeTrack {
  final int baseCost;
  final double costMultiplier;
  final int maxLevel;
  final double? growthMultiplier;
  final double? flatIncrease;
  final double? cap;

  const CoreUpgradeTrack({
    required this.baseCost,
    required this.costMultiplier,
    required this.maxLevel,
    this.growthMultiplier,
    this.flatIncrease,
    this.cap,
  });

  factory CoreUpgradeTrack.fromJson(Map<String, dynamic> json) {
    return CoreUpgradeTrack(
      baseCost: json['baseCost'] as int? ?? 100,
      costMultiplier: (json['costMultiplier'] as num? ?? 1.4).toDouble(),
      maxLevel: json['maxLevel'] as int? ?? 15,
      growthMultiplier: (json['growthMultiplier'] as num?)?.toDouble(),
      flatIncrease: (json['flatIncrease'] as num?)?.toDouble(),
      cap: (json['cap'] as num?)?.toDouble(),
    );
  }

  int costForLevel(int currentLevel) {
    final exponent = currentLevel <= 1 ? 0 : currentLevel - 1;
    return (baseCost * math.pow(costMultiplier, exponent)).round();
  }
}

class PermanentGrowthConfig {
  final double damagePercentPerLevel;
  final double fireRatePercentPerLevel;
  final int rangeBonusEveryLevels;
  final double rangeBonusPerStep;

  const PermanentGrowthConfig({
    required this.damagePercentPerLevel,
    required this.fireRatePercentPerLevel,
    required this.rangeBonusEveryLevels,
    required this.rangeBonusPerStep,
  });

  factory PermanentGrowthConfig.fromJson(Map<String, dynamic> json) {
    return PermanentGrowthConfig(
      damagePercentPerLevel: (json['damagePercentPerLevel'] as num).toDouble(),
      fireRatePercentPerLevel: (json['fireRatePercentPerLevel'] as num).toDouble(),
      rangeBonusEveryLevels: json['rangeBonusEveryLevels'] as int,
      rangeBonusPerStep: (json['rangeBonusPerStep'] as num).toDouble(),
    );
  }
}

class BalanceRepository {
  static const String _path = 'assets/data/balance/growth.json';
  static const String _waveScalingPath =
      'assets/data/balance/wave_scaling.json';

  Future<BalanceConfig> load() async {
    final raw = await rootBundle.loadString(_path);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return BalanceConfig.fromJson(json);
  }

  Future<WaveScalingConfig> loadWaveScaling() async {
    final raw = await rootBundle.loadString(_waveScalingPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return WaveScalingConfig.fromJson(json);
  }
}

class WaveScalingConfig {
  final List<ScalingBand> hpPerWaveBands;
  final List<ScalingBand> speedPerWaveBands;
  final List<ScalingBand> rewardPerWaveBands;
  final List<int> bossWaves;
  final double bossHpBonus;
  final double bossSpeedBonus;
  final double bossRewardBonus;

  const WaveScalingConfig({
    required this.hpPerWaveBands,
    required this.speedPerWaveBands,
    required this.rewardPerWaveBands,
    required this.bossWaves,
    required this.bossHpBonus,
    required this.bossSpeedBonus,
    required this.bossRewardBonus,
  });

  factory WaveScalingConfig.fromJson(Map<String, dynamic> json) {
    List<ScalingBand> _bands(String key, List<Map<String, Object>> fallback) {
      final raw = json[key] as List<dynamic>?;
      if (raw == null || raw.isEmpty) {
        return fallback
            .map((e) => ScalingBand.fromJson(e))
            .toList(growable: false);
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ScalingBand.fromJson)
          .toList(growable: false);
    }

    return WaveScalingConfig(
      hpPerWaveBands: _bands(
        'hpPerWaveBands',
        const [
          {'from': 1, 'to': 10, 'value': 0.04},
          {'from': 11, 'to': 20, 'value': 0.05},
          {'from': 21, 'to': 30, 'value': 0.06},
          {'from': 31, 'to': 40, 'value': 0.07},
          {'from': 41, 'to': 50, 'value': 0.08},
        ],
      ),
      speedPerWaveBands: _bands(
        'speedPerWaveBands',
        const [
          {'from': 1, 'to': 10, 'value': 0.005},
          {'from': 11, 'to': 20, 'value': 0.007},
          {'from': 21, 'to': 30, 'value': 0.009},
          {'from': 31, 'to': 40, 'value': 0.011},
          {'from': 41, 'to': 50, 'value': 0.013},
        ],
      ),
      rewardPerWaveBands: _bands(
        'rewardPerWaveBands',
        const [
          {'from': 1, 'to': 10, 'value': 0.02},
          {'from': 11, 'to': 20, 'value': 0.025},
          {'from': 21, 'to': 30, 'value': 0.03},
          {'from': 31, 'to': 40, 'value': 0.035},
          {'from': 41, 'to': 50, 'value': 0.04},
        ],
      ),
      bossWaves: (json['bossWaves'] as List<dynamic>? ?? const [10, 20, 30, 40, 50])
          .whereType<int>()
          .toList(growable: false),
      bossHpBonus: (json['bossHpBonus'] as num? ?? 0.35).toDouble(),
      bossSpeedBonus: (json['bossSpeedBonus'] as num? ?? 0.05).toDouble(),
      bossRewardBonus: (json['bossRewardBonus'] as num? ?? 0.25).toDouble(),
    );
  }

  double hpMultiplierForWave(int waveNumber) {
    return _bandMultiplier(hpPerWaveBands, waveNumber, bossHpBonus);
  }

  double speedMultiplierForWave(int waveNumber) {
    return _bandMultiplier(speedPerWaveBands, waveNumber, bossSpeedBonus);
  }

  double rewardMultiplierForWave(int waveNumber) {
    return _bandMultiplier(rewardPerWaveBands, waveNumber, bossRewardBonus);
  }

  double _bandMultiplier(
    List<ScalingBand> bands,
    int waveNumber,
    double bossBonus,
  ) {
    if (waveNumber <= 1) {
      return bossWaves.contains(waveNumber) ? 1.0 + bossBonus : 1.0;
    }

    double bonus = 0.0;
    for (final band in bands) {
      if (waveNumber <= band.from) {
        continue;
      }
      final end = math.min(waveNumber, band.to + 1);
      final steps = end - band.from;
      if (steps > 0) {
        bonus += steps * band.value;
      }
      if (waveNumber <= band.to) {
        break;
      }
    }

    final total = 1.0 + bonus;
    if (bossWaves.contains(waveNumber)) {
      return total * (1.0 + bossBonus);
    }
    return total;
  }
}

class ScalingBand {
  final int from;
  final int to;
  final double value;

  const ScalingBand({
    required this.from,
    required this.to,
    required this.value,
  });

  factory ScalingBand.fromJson(Map<String, dynamic> json) {
    return ScalingBand(
      from: json['from'] as int? ?? 1,
      to: json['to'] as int? ?? 1,
      value: (json['value'] as num? ?? 0).toDouble(),
    );
  }
}

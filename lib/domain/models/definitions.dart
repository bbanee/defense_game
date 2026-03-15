class TowerDef {
  final String id;
  final String nameKey;
  final String descKey;
  final String rarity;
  final double baseDamage;
  final double fireRate;
  final double range;
  final String attackType;
  final double projectileSpeed;
  final double projectileSize;
  final int buildCost;
  final int upgradeCostBase;
  final double upgradeCostMultiplier;
  final double sellRefundRate;
  final int unlockShards;
  final int levelUpShardsBase;
  final double levelUpShardsMultiplier;
  final double ultimateChance;
  final double ultimateDamageMultiplier;
  final List<TowerEffectSpec> effects;

  const TowerDef({
    required this.id,
    required this.nameKey,
    required this.descKey,
    required this.rarity,
    required this.baseDamage,
    required this.fireRate,
    required this.range,
    required this.attackType,
    required this.projectileSpeed,
    required this.projectileSize,
    required this.buildCost,
    required this.upgradeCostBase,
    required this.upgradeCostMultiplier,
    required this.sellRefundRate,
    required this.unlockShards,
    required this.levelUpShardsBase,
    required this.levelUpShardsMultiplier,
    required this.ultimateChance,
    required this.ultimateDamageMultiplier,
    required this.effects,
  });

  factory TowerDef.fromJson(Map<String, dynamic> json) {
    return TowerDef(
      id: json['id'] as String,
      nameKey: json['nameKey'] as String,
      descKey: json['descKey'] as String,
      rarity: json['rarity'] as String,
      baseDamage: (json['baseDamage'] as num).toDouble(),
      fireRate: (json['fireRate'] as num).toDouble(),
      range: (json['range'] as num).toDouble(),
      attackType: (json['attackType'] as String?) ?? 'hitscan',
      projectileSpeed: (json['projectileSpeed'] as num?)?.toDouble() ?? 260.0,
      projectileSize: (json['projectileSize'] as num?)?.toDouble() ?? 6.0,
      buildCost: (json['buildCost'] as int?) ?? 100,
      upgradeCostBase: (json['upgradeCostBase'] as int?) ?? 80,
      upgradeCostMultiplier: (json['upgradeCostMultiplier'] as num?)?.toDouble() ?? 0.6,
      sellRefundRate: (json['sellRefundRate'] as num?)?.toDouble() ?? 0.75,
      unlockShards: (json['unlockShards'] as int?) ?? 10,
      levelUpShardsBase: (json['levelUpShardsBase'] as int?) ?? 10,
      levelUpShardsMultiplier: (json['levelUpShardsMultiplier'] as num?)?.toDouble() ?? 1.2,
      ultimateChance: (json['ultimateChance'] as num?)?.toDouble() ?? 0.0,
      ultimateDamageMultiplier:
          (json['ultimateDamageMultiplier'] as num?)?.toDouble() ?? 2.0,
      effects: (json['effects'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((e) => TowerEffectSpec.fromJson(e))
          .toList(),
    );
  }
}

class TowerEffectSpec {
  final String type;
  final int? atLevel;
  final double? chance;
  final double? value;
  final double? durationSec;
  final double? slowCap;
  final int? maxStack;
  final double? stackValue;
  final int? stackThreshold;
  final double? freezeDurationSec;

  const TowerEffectSpec({
    required this.type,
    this.atLevel,
    this.chance,
    this.value,
    this.durationSec,
    this.slowCap,
    this.maxStack,
    this.stackValue,
    this.stackThreshold,
    this.freezeDurationSec,
  });

  factory TowerEffectSpec.fromJson(Map<String, dynamic> json) {
    return TowerEffectSpec(
      type: json['type']?.toString() ?? '',
      atLevel: json['atLevel'] as int?,
      chance: (json['chance'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      durationSec: (json['durationSec'] as num?)?.toDouble(),
      slowCap: (json['slowCap'] as num?)?.toDouble(),
      maxStack: json['maxStack'] as int?,
      stackValue: (json['stackValue'] as num?)?.toDouble(),
      stackThreshold: json['stackThreshold'] as int?,
      freezeDurationSec: (json['freezeDurationSec'] as num?)?.toDouble(),
    );
  }

  bool appliesAtLevel(int level) {
    if (atLevel == null) return true;
    return level >= atLevel!;
  }

  TowerEffectSpec copyWith({
    String? type,
    int? atLevel,
    double? chance,
    double? value,
    double? durationSec,
    double? slowCap,
    int? maxStack,
    double? stackValue,
    int? stackThreshold,
    double? freezeDurationSec,
  }) {
    return TowerEffectSpec(
      type: type ?? this.type,
      atLevel: atLevel ?? this.atLevel,
      chance: chance ?? this.chance,
      value: value ?? this.value,
      durationSec: durationSec ?? this.durationSec,
      slowCap: slowCap ?? this.slowCap,
      maxStack: maxStack ?? this.maxStack,
      stackValue: stackValue ?? this.stackValue,
      stackThreshold: stackThreshold ?? this.stackThreshold,
      freezeDurationSec: freezeDurationSec ?? this.freezeDurationSec,
    );
  }
}

class EnemyDef {
  final String id;
  final String nameKey;
  final String archetype;
  final double hp;
  final double speed;
  final int rewardBattleGold;

  const EnemyDef({
    required this.id,
    required this.nameKey,
    required this.archetype,
    required this.hp,
    required this.speed,
    required this.rewardBattleGold,
  });

  factory EnemyDef.fromJson(Map<String, dynamic> json) {
    return EnemyDef(
      id: json['id'] as String,
      nameKey: json['nameKey'] as String,
      archetype: json['archetype'] as String,
      hp: (json['hp'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      rewardBattleGold: json['rewardBattleGold'] as int,
    );
  }
}

class StageDef {
  final String id;
  final String mapId;
  final String modeId;
  final int energyCost;
  final StageReward reward;
  final List<String> allowedDifficulties;
  final List<String> waveIds;
  final Map<String, String> generatedWavePrefixes;
  final int generatedWaveCount;

  const StageDef({
    required this.id,
    required this.mapId,
    required this.modeId,
    required this.energyCost,
    required this.reward,
    required this.allowedDifficulties,
    required this.waveIds,
    required this.generatedWavePrefixes,
    required this.generatedWaveCount,
  });

  factory StageDef.fromJson(Map<String, dynamic> json) {
    final generatedWavePrefixes =
        (json['generatedWavePrefixes'] as Map<String, dynamic>? ?? const {})
            .map((key, value) => MapEntry(key, value as String));
    return StageDef(
      id: json['id'] as String,
      mapId: json['mapId'] as String,
      modeId: json['modeId'] as String? ?? 'story_defense',
      energyCost: json['energyCost'] as int,
      reward: StageReward.fromJson(json['reward'] as Map<String, dynamic>),
      allowedDifficulties: (json['allowedDifficulties'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      waveIds: (json['waveIds'] as List<dynamic>? ?? ['wave_01'])
          .map((e) => e as String)
          .toList(),
      generatedWavePrefixes: generatedWavePrefixes,
      generatedWaveCount: json['generatedWaveCount'] as int? ?? 0,
    );
  }

  List<String> waveIdsForDifficulty(String difficultyId) {
    final prefix = generatedWavePrefixes[difficultyId];
    if (prefix == null || generatedWaveCount <= 0) {
      return waveIds;
    }
    return List<String>.generate(
      generatedWaveCount,
      (index) => '$prefix${(index + 1).toString().padLeft(2, '0')}',
      growable: false,
    );
  }
}

class StageReward {
  final int accountGold;
  final int towerShard;

  const StageReward({
    required this.accountGold,
    required this.towerShard,
  });

  factory StageReward.fromJson(Map<String, dynamic> json) {
    return StageReward(
      accountGold: json['accountGold'] as int,
      towerShard: json['towerShard'] as int,
    );
  }
}

class DifficultyDef {
  final String id;
  final String nameKey;
  final double hpMultiplier;
  final double speedMultiplier;
  final double rewardMultiplier;
  final int startingBattleGold;
  final double buildCostMultiplier;
  final double towerUpgradeCostMultiplier;
  final double sellRefundMultiplier;

  const DifficultyDef({
    required this.id,
    required this.nameKey,
    required this.hpMultiplier,
    required this.speedMultiplier,
    required this.rewardMultiplier,
    required this.startingBattleGold,
    required this.buildCostMultiplier,
    required this.towerUpgradeCostMultiplier,
    required this.sellRefundMultiplier,
  });

  factory DifficultyDef.fromJson(Map<String, dynamic> json) {
    return DifficultyDef(
      id: json['id'] as String,
      nameKey: json['nameKey'] as String,
      hpMultiplier: (json['hpMultiplier'] as num).toDouble(),
      speedMultiplier: (json['speedMultiplier'] as num).toDouble(),
      rewardMultiplier: (json['rewardMultiplier'] as num).toDouble(),
      startingBattleGold: json['startingBattleGold'] as int? ?? 200,
      buildCostMultiplier:
          (json['buildCostMultiplier'] as num?)?.toDouble() ?? 1.0,
      towerUpgradeCostMultiplier:
          (json['towerUpgradeCostMultiplier'] as num?)?.toDouble() ?? 1.0,
      sellRefundMultiplier:
          (json['sellRefundMultiplier'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class ModeDef {
  final String id;
  final String nameKey;
  final String winCondition;
  final String loseCondition;

  const ModeDef({
    required this.id,
    required this.nameKey,
    required this.winCondition,
    required this.loseCondition,
  });

  factory ModeDef.fromJson(Map<String, dynamic> json) {
    return ModeDef(
      id: json['id'] as String,
      nameKey: json['nameKey'] as String,
      winCondition: json['winCondition'] as String,
      loseCondition: json['loseCondition'] as String,
    );
  }
}

class GachaBannerDef {
  final String bannerId;
  final GachaCost cost;
  final List<GachaRate> rates;

  const GachaBannerDef({
    required this.bannerId,
    required this.cost,
    required this.rates,
  });

  factory GachaBannerDef.fromJson(Map<String, dynamic> json) {
    return GachaBannerDef(
      bannerId: json['bannerId'] as String,
      cost: GachaCost.fromJson(json['cost'] as Map<String, dynamic>),
      rates: (json['rates'] as List<dynamic>)
          .map((e) => GachaRate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GachaCost {
  final String currency;
  final int amount;

  const GachaCost({
    required this.currency,
    required this.amount,
  });

  factory GachaCost.fromJson(Map<String, dynamic> json) {
    return GachaCost(
      currency: json['currency'] as String,
      amount: json['amount'] as int,
    );
  }
}

class GachaRate {
  final String rarity;
  final double percent;

  const GachaRate({
    required this.rarity,
    required this.percent,
  });

  factory GachaRate.fromJson(Map<String, dynamic> json) {
    return GachaRate(
      rarity: json['rarity'] as String,
      percent: (json['percent'] as num).toDouble(),
    );
  }
}

class MapPoint {
  final int x;
  final int y;

  const MapPoint({required this.x, required this.y});

  factory MapPoint.fromList(List<dynamic> data) {
    return MapPoint(
      x: data[0] as int,
      y: data[1] as int,
    );
  }
}

class MapDef {
  final String id;
  final int gridWidth;
  final int gridHeight;
  final List<MapPoint> path;
  final List<MapPoint> buildCells;
  final MapPoint corePosition;

  const MapDef({
    required this.id,
    required this.gridWidth,
    required this.gridHeight,
    required this.path,
    required this.buildCells,
    required this.corePosition,
  });

  factory MapDef.fromJson(Map<String, dynamic> json) {
    final rawPath = (json['path'] as List<dynamic>)
        .map((e) => MapPoint.fromList(e as List<dynamic>))
        .toList();
    final rawBuild = (json['buildCells'] as List<dynamic>? ?? [])
        .map((e) => MapPoint.fromList(e as List<dynamic>))
        .toList();
    final core = json['corePosition'] as List<dynamic>?;
    return MapDef(
      id: json['id'] as String,
      gridWidth: json['gridWidth'] as int,
      gridHeight: json['gridHeight'] as int,
      path: rawPath,
      buildCells: rawBuild,
      corePosition: core != null ? MapPoint.fromList(core) : rawPath.last,
    );
  }
}

class WaveSpawn {
  final String enemyId;
  final double at;
  final int count;
  final int intervalMs;

  const WaveSpawn({
    required this.enemyId,
    required this.at,
    required this.count,
    required this.intervalMs,
  });

  factory WaveSpawn.fromJson(Map<String, dynamic> json) {
    return WaveSpawn(
      enemyId: json['enemyId'] as String,
      at: (json['at'] as num).toDouble(),
      count: json['count'] as int? ?? 1,
      intervalMs: json['intervalMs'] as int? ?? 0,
    );
  }
}

class WaveDef {
  final String id;
  final List<WaveSpawn> spawns;
  final int waveClearReward;

  const WaveDef({
    required this.id,
    required this.spawns,
    required this.waveClearReward,
  });

  factory WaveDef.fromJson(Map<String, dynamic> json) {
    return WaveDef(
      id: json['id'] as String,
      spawns: (json['spawns'] as List<dynamic>)
          .map((e) => WaveSpawn.fromJson(e as Map<String, dynamic>))
          .toList(),
      waveClearReward: json['waveClearReward'] as int? ?? 0,
    );
  }
}

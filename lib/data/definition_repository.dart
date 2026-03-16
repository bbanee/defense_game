import 'package:tower_defense/data/json_asset_loader.dart';
import 'package:tower_defense/domain/models/definitions.dart';

class DefinitionRepository {
  final JsonAssetLoader loader;
  static final RegExp _generatedWaveIdPattern = RegExp(
    r'^wave_(easy|normal|hard|endless)_(\d{2})$',
  );
  static Future<Map<String, dynamic>>? _waveOverridesFuture;

  const DefinitionRepository({this.loader = const JsonAssetLoader()});

  Future<TowerDef> loadTower(String id) async {
    final json = await loader.loadObject('assets/data/towers/$id.json');
    return TowerDef.fromJson(json);
  }

  Future<EnemyDef> loadEnemy(String id) async {
    final json = await loader.loadObject('assets/data/enemies/$id.json');
    return EnemyDef.fromJson(json);
  }

  Future<StageDef> loadStage(String id) async {
    final json = await loader.loadObject('assets/data/stages/$id.json');
    return StageDef.fromJson(json);
  }

  Future<DifficultyDef> loadDifficulty(String id) async {
    final json = await loader.loadObject('assets/data/difficulties/$id.json');
    return DifficultyDef.fromJson(json);
  }

  Future<ModeDef> loadMode(String id) async {
    final json = await loader.loadObject('assets/data/modes/$id.json');
    return ModeDef.fromJson(json);
  }

  Future<GachaBannerDef> loadGachaBanner(String id) async {
    final json = await loader.loadObject('assets/data/gacha/$id.json');
    return GachaBannerDef.fromJson(json);
  }

  Future<MapDef> loadMap(String id) async {
    final json = await loader.loadObject('assets/data/maps/$id.json');
    return MapDef.fromJson(json);
  }

  Future<WaveDef> loadWave(String id) async {
    final generatedMatch = _generatedWaveIdPattern.firstMatch(id);
    if (generatedMatch != null) {
      var wave = _buildGeneratedStoryWave(
        id,
        difficultyId: generatedMatch.group(1)!,
        waveNumber: int.parse(generatedMatch.group(2)!),
      );
      final overrides = await _loadWaveOverrides();
      wave = _applyWaveOverride(
        wave,
        difficultyId: generatedMatch.group(1)!,
        waveNumber: int.parse(generatedMatch.group(2)!),
        overrides: overrides,
      );
      return wave;
    }
    final json = await loader.loadObject('assets/data/waves/$id.json');
    return WaveDef.fromJson(json);
  }

  Future<Map<String, dynamic>> loadUltimateFx() async {
    return loader.loadObject('assets/data/ultimate_fx.json');
  }

  Future<Map<String, dynamic>> loadLobbyUpgradeConfig() async {
    return loader.loadObject('assets/data/lobby_upgrades/config.json');
  }

  Future<Map<String, dynamic>> loadLobbyUpgradePresets() async {
    return loader.loadObject('assets/data/lobby_upgrades/presets_by_tower.json');
  }

  Future<Map<String, dynamic>> loadLobbyUpgradeDefaultState() async {
    return loader.loadObject('assets/data/lobby_upgrades/default_player_state.json');
  }

  Future<List<Map<String, dynamic>>> loadAttendanceRewards() async {
    final list = await loader.loadList('assets/data/attendance_rewards.json');
    return list.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Future<Map<String, dynamic>> _loadWaveOverrides() {
    _waveOverridesFuture ??= _safeLoadWaveOverrides();
    return _waveOverridesFuture!;
  }

  Future<Map<String, dynamic>> _safeLoadWaveOverrides() async {
    try {
      return await loader.loadObject('assets/data/waves/wave_overrides.json');
    } catch (_) {
      return const {};
    }
  }

  WaveDef _buildGeneratedStoryWave(
    String id, {
    required String difficultyId,
    required int waveNumber,
  }) {
    final profile = _waveProfileForDifficulty(difficultyId);
    final adjustedWave = waveNumber + profile.tierOffset;
    final isBossWave = waveNumber % 10 == 0;

    final spawns = isBossWave
        ? _buildBossWaveSpawns(adjustedWave, difficultyId)
        : _buildNormalWaveSpawns(adjustedWave, difficultyId);

    final rewardBase = isBossWave
        ? 90 + waveNumber * 12
        : 28 + waveNumber * 7;
    final reward = (rewardBase * profile.rewardScale).round();

    return WaveDef(
      id: id,
      spawns: spawns,
      waveClearReward: reward,
    );
  }

  WaveDef _applyWaveOverride(
    WaveDef wave, {
    required String difficultyId,
    required int waveNumber,
    required Map<String, dynamic> overrides,
  }) {
    final difficultyOverrides =
        overrides[difficultyId] as Map<String, dynamic>? ?? const {};
    final waveOverride =
        difficultyOverrides['$waveNumber'] as Map<String, dynamic>? ?? const {};
    if (waveOverride.isEmpty) {
      return wave;
    }

    var spawns = List<WaveSpawn>.from(wave.spawns);
    if (waveOverride['replaceSpawns'] is List<dynamic>) {
      spawns = (waveOverride['replaceSpawns'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(WaveSpawn.fromJson)
          .toList(growable: true);
    }

    if (waveOverride['removeEnemyIds'] is List<dynamic>) {
      final removeIds = (waveOverride['removeEnemyIds'] as List<dynamic>)
          .whereType<String>()
          .toSet();
      spawns.removeWhere((spawn) => removeIds.contains(spawn.enemyId));
    }

    if (waveOverride['modifySpawns'] is List<dynamic>) {
      final modifyDefs = (waveOverride['modifySpawns'] as List<dynamic>)
          .whereType<Map<String, dynamic>>();
      for (final modify in modifyDefs) {
        spawns = _applySpawnModification(spawns, modify);
      }
    }

    if (waveOverride['addSpawns'] is List<dynamic>) {
      final addSpawns = (waveOverride['addSpawns'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(WaveSpawn.fromJson);
      spawns.addAll(addSpawns);
      spawns.sort((a, b) => a.at.compareTo(b.at));
    }

    return WaveDef(
      id: wave.id,
      spawns: spawns,
      waveClearReward:
          waveOverride['waveClearReward'] as int? ?? wave.waveClearReward,
    );
  }

  List<WaveSpawn> _applySpawnModification(
    List<WaveSpawn> spawns,
    Map<String, dynamic> modify,
  ) {
    final enemyId = modify['enemyId'] as String?;
    if (enemyId == null) return spawns;

    final matchAt = (modify['matchAt'] as num?)?.toDouble();
    final countDelta = modify['countDelta'] as int? ?? 0;
    final overrideCount = modify['count'] as int?;
    final overrideAt = (modify['at'] as num?)?.toDouble();
    final overrideInterval = modify['intervalMs'] as int?;

    var changed = false;
    final next = spawns.map((spawn) {
      final matchesEnemy = spawn.enemyId == enemyId;
      final matchesAt = matchAt == null || spawn.at == matchAt;
      if (!matchesEnemy || !matchesAt || changed) {
        return spawn;
      }
      changed = true;
      return WaveSpawn(
        enemyId: spawn.enemyId,
        at: overrideAt ?? spawn.at,
        count: (overrideCount ?? (spawn.count + countDelta)).clamp(1, 999),
        intervalMs: overrideInterval ?? spawn.intervalMs,
      );
    }).toList(growable: false);
    return next;
  }

  List<WaveSpawn> _buildNormalWaveSpawns(int waveNumber, String difficultyId) {
    final profile = _waveProfileForDifficulty(difficultyId);
    final countScale = profile.countScale;
    final spawns = <WaveSpawn>[
      WaveSpawn(
        enemyId: 'grunt_basic',
        at: 0.5,
        count: _scaledCount(4 + waveNumber ~/ 3, countScale),
        intervalMs: 540,
      ),
      if (waveNumber >= 2)
        WaveSpawn(
          enemyId: 'sprinter_basic',
          at: 2.2,
          count: _scaledCount(2 + waveNumber ~/ 5, countScale),
          intervalMs: 420,
        ),
      if (waveNumber >= 4)
        WaveSpawn(
          enemyId: waveNumber >= 18 ? 'brute_basic' : 'tank_basic',
          at: 4.8,
          count: _scaledCount(1 + waveNumber ~/ 10, countScale),
          intervalMs: 1000,
        ),
      if (waveNumber >= 8)
        WaveSpawn(
          enemyId: 'scout_basic',
          at: 6.9,
          count: _scaledCount(2 + waveNumber ~/ 8, countScale),
          intervalMs: 360,
        ),
      if (waveNumber >= 9)
        WaveSpawn(
          enemyId: 'swarm_basic',
          at: 8.1,
          count: _scaledCount(3 + waveNumber ~/ 7, countScale),
          intervalMs: 240,
        ),
      if (waveNumber >= 12)
        WaveSpawn(
          enemyId: 'spitter_basic',
          at: 9.1,
          count: _scaledCount(1 + waveNumber ~/ 11, countScale),
          intervalMs: 920,
        ),
      if (waveNumber >= 14)
        WaveSpawn(
          enemyId: 'swarm_basic',
          at: 11.0,
          count: _scaledCount(4 + waveNumber ~/ 6, countScale),
          intervalMs: 240,
        ),
      if (waveNumber >= 15)
        WaveSpawn(
          enemyId: 'armored_basic',
          at: 13.0,
          count: _scaledCount(1 + waveNumber ~/ 12, countScale),
          intervalMs: 1250,
        ),
      if (waveNumber >= 20)
        WaveSpawn(
          enemyId: 'elite_basic',
          at: 15.5,
          count: _scaledCount(1 + waveNumber ~/ 18, countScale),
          intervalMs: 1600,
        ),
    ];

    if (waveNumber >= 36) {
      spawns.add(
        WaveSpawn(
          enemyId: 'armored_basic',
          at: 18.0,
          count: _scaledCount(2 + waveNumber ~/ 14, countScale),
          intervalMs: 980,
        ),
      );
    }

    if (difficultyId == 'hard' && waveNumber >= 28) {
      spawns.add(
        WaveSpawn(
          enemyId: 'elite_basic',
          at: 20.0,
          count: _scaledCount(1 + waveNumber ~/ 20, countScale),
          intervalMs: 1450,
        ),
      );
    }

    if (difficultyId == 'endless') {
      if (waveNumber >= 10) {
        spawns.add(
          WaveSpawn(
            enemyId: 'armored_basic',
            at: 10.8,
            count: _scaledCount(1 + waveNumber ~/ 11, countScale),
            intervalMs: 980,
          ),
        );
      }
      if (waveNumber >= 16) {
        spawns.add(
          WaveSpawn(
            enemyId: 'brute_basic',
            at: 13.8,
            count: _scaledCount(1 + waveNumber ~/ 14, countScale),
            intervalMs: 1150,
          ),
        );
      }
      if (waveNumber >= 22) {
        spawns.add(
          WaveSpawn(
            enemyId: 'elite_basic',
            at: 17.2,
            count: _scaledCount(1 + waveNumber ~/ 18, countScale),
            intervalMs: 1320,
          ),
        );
      }
      if (waveNumber >= 28) {
        spawns.add(
          WaveSpawn(
            enemyId: 'swarm_basic',
            at: 19.0,
            count: _scaledCount(5 + waveNumber ~/ 7, countScale),
            intervalMs: 210,
          ),
        );
      }
    }

    return spawns;
  }

  List<WaveSpawn> _buildBossWaveSpawns(int waveNumber, String difficultyId) {
    final profile = _waveProfileForDifficulty(difficultyId);
    final countScale = profile.countScale;
    final spawns = <WaveSpawn>[
      WaveSpawn(
        enemyId: 'grunt_basic',
        at: 0.5,
        count: _scaledCount(4 + waveNumber ~/ 8, countScale),
        intervalMs: 420,
      ),
      if (waveNumber >= 12)
        WaveSpawn(
          enemyId: 'sprinter_basic',
          at: 2.0,
          count: _scaledCount(3 + waveNumber ~/ 10, countScale),
          intervalMs: 320,
        ),
      if (waveNumber >= 18)
        WaveSpawn(
          enemyId: 'armored_basic',
          at: 4.0,
          count: _scaledCount(1 + waveNumber ~/ 16, countScale),
          intervalMs: 1000,
        ),
      const WaveSpawn(
        enemyId: 'boss_basic',
        at: 6.0,
        count: 1,
        intervalMs: 0,
      ),
      if (waveNumber >= 24)
        WaveSpawn(
          enemyId: 'elite_basic',
          at: 8.5,
          count: _scaledCount(1 + waveNumber ~/ 20, countScale),
          intervalMs: 1200,
        ),
      if (difficultyId != 'easy')
        WaveSpawn(
          enemyId: 'swarm_basic',
          at: 10.5,
          count: _scaledCount(5 + waveNumber ~/ 8, countScale),
          intervalMs: 220,
        ),
    ];

    if (difficultyId == 'endless') {
      if (waveNumber >= 20) {
        spawns.add(
          const WaveSpawn(
            enemyId: 'boss_basic',
            at: 11.8,
            count: 1,
            intervalMs: 0,
          ),
        );
      }
      if (waveNumber >= 30) {
        spawns.add(
          const WaveSpawn(
            enemyId: 'boss_basic',
            at: 13.4,
            count: 1,
            intervalMs: 0,
          ),
        );
      }
      spawns.add(
        WaveSpawn(
          enemyId: 'armored_basic',
          at: 8.8,
          count: _scaledCount(2 + waveNumber ~/ 12, countScale),
          intervalMs: 900,
        ),
      );
      spawns.add(
        WaveSpawn(
          enemyId: 'brute_basic',
          at: 9.6,
          count: _scaledCount(1 + waveNumber ~/ 15, countScale),
          intervalMs: 1100,
        ),
      );
      spawns.add(
        WaveSpawn(
          enemyId: 'elite_basic',
          at: 12.2,
          count: _scaledCount(1 + waveNumber ~/ 18, countScale),
          intervalMs: 1200,
        ),
      );
      spawns.add(
        WaveSpawn(
          enemyId: 'spitter_basic',
          at: 14.6,
          count: _scaledCount(2 + waveNumber ~/ 16, countScale),
          intervalMs: 980,
        ),
      );
    }

    return spawns;
  }

  int _scaledCount(int base, double scale) {
    return (base * scale).round().clamp(1, 999);
  }

  _GeneratedWaveProfile _waveProfileForDifficulty(String difficultyId) {
    return switch (difficultyId) {
      'easy' => const _GeneratedWaveProfile(
          countScale: 1.1,
          rewardScale: 0.78,
          tierOffset: 0,
        ),
      'hard' => const _GeneratedWaveProfile(
          countScale: 1.8,
          rewardScale: 0.92,
          tierOffset: 14,
        ),
      'endless' => const _GeneratedWaveProfile(
          countScale: 1.68,
          rewardScale: 0.88,
          tierOffset: 12,
        ),
      _ => const _GeneratedWaveProfile(
          countScale: 1.55,
          rewardScale: 0.82,
          tierOffset: 10,
        ),
    };
  }
}

class _GeneratedWaveProfile {
  final double countScale;
  final double rewardScale;
  final int tierOffset;

  const _GeneratedWaveProfile({
    required this.countScale,
    required this.rewardScale,
    required this.tierOffset,
  });
}

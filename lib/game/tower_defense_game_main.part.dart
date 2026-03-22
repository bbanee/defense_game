part of 'tower_defense_game.dart';

class TowerDefenseGame extends FlameGame with TapCallbacks {
  static const int maxPlacedTowers = 10;
  static const bool showDebugUi = !bool.fromEnvironment('dart.vm.product');
  static const int _maxDamageTextsPerFrame = 18;
  static const int _maxVisualEffectsPerFrame = 36;
  final VoidCallback? onExitToLobby;
  final String difficultyId;
  final String stageId;
  final AccountProgress accountProgress;
  final bool showDamage;
  final math.Random rng = math.Random();

  TowerDefenseGame({
    this.onExitToLobby,
    required this.difficultyId,
    required this.stageId,
    required this.accountProgress,
    required this.showDamage,
  });
  late int gridWidth;
  late int gridHeight;

  double tileSize = 32;
  Vector2 mapOrigin = Vector2.zero();

  late final MapComponent map;
  Sprite? mapBackground;
  late final List<GridPoint> path;
  late final Map<GridPoint, Tower> towers;
  late final List<Enemy> enemies;
  late final SpawnController spawner;
  late final Set<GridPoint> buildCells;
  late final List<WaveDef> waves;
  int currentWaveIndex = 0;
  late final CoreBuilding core;
  late final Map<String, EnemyDef> enemyDefs;
  late final BattleHud hud;
  late final StageDef stageDef;
  late final DifficultyDef difficultyDef;
  late final ModeDef modeDef;
  late final Map<String, TowerDef> towerDefs;
  late final BalanceConfig balanceConfig;
  late final WaveScalingConfig waveScalingConfig;
  late Map<String, UltimateFxDef> ultimateFx;
  Map<String, dynamic> lobbyUpgradeConfig = const {};
  Map<String, dynamic> lobbyUpgradePresets = const {};

  double coreHp = 100;
  double coreMaxHp = 100;
  double coreShield = 0;
  double coreMaxShield = 0;
  double coreDefenseRate = 0;
  bool defeated = false;
  ResultOverlay? resultOverlay;
  ContinueOverlay? continueOverlay;
  SpeedAdOverlay? speedAdOverlay;
  int battleGold = 200;
  int accountGold = 0;
  bool waveClearRewarded = false;
  double waveAdvanceDelayTimer = 0;
  bool victory = false;
  TargetingRule currentRule = TargetingRule.nearest;
  double timeScale = 1.0;
  bool debugOpen = false;
  bool debugInfiniteGold = false;
  bool debugShowDps = false;
  bool debugInfiniteWaves = false;
  bool debugInfiniteCore = false;
  bool debugInfiniteEnemyHp = false;
  bool loopEnemiesOnPath = false;
  double visualFxTime = 0.0;
  double buildLimitNoticeCooldown = 0.0;
  int completedWaveCount = 0;
  bool endRewardsGranted = false;
  bool endRewardsDoubled = false;
  int endRewardGold = 0;
  int endRewardTickets = 0;
  bool stageRankingSaved = false;
  int enemyKillScore = 0;
  int highestPlacedTowerCount = 0;
  int infiniteWaveNumber = 1;
  int finalInfiniteScore = 0;
  bool infiniteScoreSaved = false;
  bool resultActionPending = false;
  bool continueUsed = false;
  bool adSpeedUnlocked = false;
  Future<void>? _endRewardsFuture;
  Future<void>? _stageRankingFuture;
  Future<void>? _infiniteScoreFuture;
  int _damageTextsSpawnedThisFrame = 0;
  int _visualEffectsSpawnedThisFrame = 0;

  TowerPicker? picker;
  TowerActionPanel? towerPanel;
  TowerInfoPanel? towerInfoPanel;
  bool _ready = false;

  Future<Sprite?> _loadMapBackground(String stageId) async {
    if (stageId == 'test_u_stage') {
      return null;
    }
    try {
      return await loadSprite('maps/map_01.png');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final repo = DefinitionRepository();
    stageDef = await repo.loadStage(stageId);
    loopEnemiesOnPath = stageDef.id == 'test_u_stage';
    modeDef = await repo.loadMode(stageDef.modeId);
    difficultyDef = await repo.loadDifficulty(difficultyId);
    battleGold = difficultyDef.startingBattleGold;
    final balanceRepo = BalanceRepository();
    balanceConfig = await balanceRepo.load();
    waveScalingConfig = await balanceRepo.loadWaveScaling();
    try {
      lobbyUpgradeConfig = await repo.loadLobbyUpgradeConfig();
      lobbyUpgradePresets = await repo.loadLobbyUpgradePresets();
    } catch (_) {
      lobbyUpgradeConfig = const {};
      lobbyUpgradePresets = const {};
    }
    final mapDef = await repo.loadMap(stageDef.mapId);
    mapBackground = await _loadMapBackground(stageDef.id);
    waves = [];
    for (final id in stageDef.waveIdsForDifficulty(difficultyId)) {
      waves.add(await repo.loadWave(id));
    }
    enemyDefs = {
      'grunt_basic': await repo.loadEnemy('grunt_basic'),
      'sprinter_basic': await repo.loadEnemy('sprinter_basic'),
      'tank_basic': await repo.loadEnemy('tank_basic'),
      'brute_basic': await repo.loadEnemy('brute_basic'),
      'scout_basic': await repo.loadEnemy('scout_basic'),
      'spitter_basic': await repo.loadEnemy('spitter_basic'),
      'armored_basic': await repo.loadEnemy('armored_basic'),
      'swarm_basic': await repo.loadEnemy('swarm_basic'),
      'elite_basic': await repo.loadEnemy('elite_basic'),
      'boss_basic': await repo.loadEnemy('boss_basic'),
    };
    final defs = <String, TowerDef>{};
    for (final id in kAllTowerIds) {
      defs[id] = await repo.loadTower(id);
    }
    towerDefs = defs;
    ultimateFx = _parseUltimateFx(await repo.loadUltimateFx());
    gridWidth = mapDef.gridWidth;
    gridHeight = mapDef.gridHeight;

    path = mapDef.path.map((p) => GridPoint(p.x, p.y)).toList();
    buildCells = _buildCellsFromDef(mapDef);
    towers = {};
    enemies = [];

    final coreProgress = accountProgress.core;
    coreMaxHp = coreProgress.hp.toDouble();
    coreHp = coreMaxHp;
    coreMaxShield = coreProgress.shield.toDouble();
    coreShield = coreMaxShield;
    coreDefenseRate = coreProgress.defenseRate;

    map = MapComponent(gameRef: this, path: path, background: mapBackground);
    add(map);

    // Start/end markers disabled (path guide only).
    core = CoreBuilding(gameRef: this, positionCell: path.last);
    core.setStats(coreHp, coreMaxHp, coreShield, coreMaxShield);
    add(core);
    hud = BattleHud(gameRef: this);
    add(hud);

    spawner = SpawnController(game: this, waveDef: waves[currentWaveIndex]);
    add(spawner);

    _ready = true;
    if (size.x > 0 && size.y > 0) {
      onGameResize(size);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_ready) return;

    final tileX = (size.x / gridWidth).floorToDouble();
    final tileY = (size.y / gridHeight).floorToDouble();
    final raw = math.min(tileX, tileY) * 0.95;
    tileSize = raw.floorToDouble().clamp(16.0, 80.0);

    final mapWidth = gridWidth * tileSize;
    final mapHeight = gridHeight * tileSize;
    mapOrigin = Vector2(
      (size.x - mapWidth) / 2,
      (size.y - mapHeight) / 2,
    );

    if (!_ready) return;

    map.position = mapOrigin;
    map.size = Vector2(mapWidth, mapHeight);
    hud.onGameResize(size);

    core.size = Vector2(tileSize * 1.92, tileSize * 1.92);
    core.visualOffset = Vector2(tileSize * 0.95, tileSize * 0.95);
    core.position = path.last.toWorld(this) + core.visualOffset;

    for (final tower in towers.values) {
      tower.updateWorldPosition();
    }

    for (final enemy in enemies) {
      enemy.updateWorldPosition();
    }

    picker?.updateLayout();
    towerInfoPanel?.updateLayout();
    towerPanel?.updateLayout();
  }

  @override
  void update(double dt) {
    _damageTextsSpawnedThisFrame = 0;
    _visualEffectsSpawnedThisFrame = 0;
    if (defeated || victory) {
      super.update(dt);
      return;
    }
    final scaledDt = dt * timeScale;
    const maxStep = 1 / 30;
    var remaining = scaledDt;
    while (remaining > 0) {
      final step = math.min(remaining, maxStep);
      _updateSimulationStep(step);
      remaining -= step;
    }
  }

  void _updateSimulationStep(double dt) {
    visualFxTime += dt;
    if (buildLimitNoticeCooldown > 0) {
      buildLimitNoticeCooldown =
          (buildLimitNoticeCooldown - dt).clamp(0.0, double.infinity);
    }
    super.update(dt);
    if (debugInfiniteGold) {
      battleGold = 999999;
    }
    for (final tower in towers.values) {
      tower.updateTower(dt, enemies);
    }

    enemies.removeWhere((enemy) => enemy.isRemoved);

    if (spawner.isFinished) {
      waveAdvanceDelayTimer += dt;
    } else {
      waveAdvanceDelayTimer = 0;
    }

    if (!waveClearRewarded &&
        spawner.isFinished &&
        enemies.isEmpty &&
        waveAdvanceDelayTimer < 15) {
      addBattleGoldScaled(
        waves[currentWaveIndex].waveClearReward,
        extraMultiplier: waveScalingConfig.rewardMultiplierForWave(
          displayedWaveNumber,
        ),
      );
      waveClearRewarded = true;
      completedWaveCount = math.max(completedWaveCount, currentWaveIndex + 1);
    }

    if (spawner.isFinished && waveAdvanceDelayTimer >= 15) {
      _advanceWaveIfPossible();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (continueOverlay != null) {
      final action = continueOverlay?.hitTest(event.canvasPosition);
      if (action != null && !resultActionPending) {
        resultActionPending = true;
        unawaited(_handleContinueOverlayAction(action));
      }
      return;
    }
    if (speedAdOverlay != null) {
      final action = speedAdOverlay?.hitTest(event.canvasPosition);
      if (action != null && !resultActionPending) {
        resultActionPending = true;
        unawaited(_handleSpeedAdOverlayAction(action));
      }
      return;
    }
    if (defeated || victory) {
      final action = resultOverlay?.hitTest(event.canvasPosition);
      if (action != null && !resultActionPending) {
        resultActionPending = true;
        unawaited(_handleResultOverlayAction(action));
      }
      return;
    }
    if (showDebugUi && hud.hitDebugButton(event.canvasPosition)) {
      debugOpen = !debugOpen;
      debugInfiniteWaves = debugOpen;
      debugInfiniteCore = debugOpen;
      return;
    }
    final pos = event.canvasPosition;

    if (picker != null) {
      final selected = picker!.hitTest(pos);
      if (selected != null) {
        _buildTower(picker!.cell, selected);
      }
      _closePicker();
      return;
    }
    if (towerPanel != null) {
      final action = towerPanel!.hitTest(pos);
      if (action != null) {
        _handleTowerAction(towerPanel!.cell, action);
      }
      _closeTowerPanel();
      return;
    }
    if (showDebugUi && debugOpen && hud.hitDebugPanel(pos, this)) {
      return;
    }
    if (hud.hitSpeedButton(pos)) {
      if (adSpeedUnlocked) {
        _toggleSpeed();
      } else {
        speedAdOverlay = SpeedAdOverlay(gameRef: this);
        add(speedAdOverlay!);
      }
      return;
    }

    final cell = _worldToGrid(pos);
    if (cell == null) return;
    if (towers.containsKey(cell)) {
      _openTowerPanel(cell);
      return;
    }
    if (!_isBuildable(cell)) return;

    _openPicker(cell);
  }

  void _openPicker(GridPoint cell) {
    _closePicker();
    _closeTowerPanel();
    picker = TowerPicker(gameRef: this, cell: cell);
    add(picker!);
  }

  void _closePicker() {
    picker?.removeFromParent();
    picker = null;
  }

  void _buildTower(GridPoint cell, String towerId) {
    final def = towerDefs[towerId];
    if (def == null) return;
    if (!_isTowerUnlocked(def.id)) return;
    if (towers.length >= maxPlacedTowers) {
      unawaited(AppAudioService.instance.playTowerPlaceFail());
      if (buildLimitNoticeCooldown <= 0) {
        spawnBattleNotice(
            '타워는 최대 ${TowerDefenseGame.maxPlacedTowers}개까지 설치할 수 있습니다.');
        buildLimitNoticeCooldown = 0.8;
      }
      return;
    }
    final cost = (def.buildCost * difficultyDef.buildCostMultiplier).round();
    if (battleGold < cost) {
      unawaited(AppAudioService.instance.playTowerPlaceFail());
      return;
    }
    battleGold -= cost;
    final tower = Tower(
      gameRef: this,
      towerId: towerId,
      grid: cell,
      def: def,
      initialCost: cost,
      lobbyUpgrade: _getTowerLobbyUpgrade(def.id),
      lobbyPreset: _getTowerLobbyPreset(def.id),
    );
    towers[cell] = tower;
    if (towers.length > highestPlacedTowerCount) {
      highestPlacedTowerCount = towers.length;
    }
    add(tower);
    unawaited(AppAudioService.instance.playTowerPlace());
  }

  bool _isTowerUnlocked(String towerId) {
    if (debugOpen) return true;
    final progress = accountProgress.towers[towerId];
    return progress?.unlocked ?? false;
  }

  int _getTowerPermanentLevel(String towerId) {
    return accountProgress.towers[towerId]?.level ?? 1;
  }

  TowerLobbyUpgradeProgress _getTowerLobbyUpgrade(String towerId) {
    return accountProgress.lobbyUpgrades[towerId] ??
        TowerLobbyUpgradeProgress(towerId: towerId);
  }

  Map<String, dynamic>? _getTowerLobbyPreset(String towerId) {
    final towers = lobbyUpgradePresets['towers'] as Map<String, dynamic>?;
    final raw = towers?[towerId];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    return null;
  }

  void _openTowerPanel(GridPoint cell) {
    _closePicker();
    _closeTowerPanel();
    towerInfoPanel = TowerInfoPanel(gameRef: this, cell: cell);
    add(towerInfoPanel!);
    towerPanel = TowerActionPanel(gameRef: this, cell: cell);
    add(towerPanel!);
  }

  void _closeTowerPanel() {
    towerPanel?.removeFromParent();
    towerPanel = null;
    towerInfoPanel?.removeFromParent();
    towerInfoPanel = null;
  }

  void _handleTowerAction(GridPoint cell, Object action) {
    final tower = towers[cell];
    if (tower == null) return;
    if (action == TowerAction.upgrade) {
      final cost = tower.nextUpgradeCost;
      if (battleGold >= cost) {
        battleGold -= cost;
        tower.upgrade();
        unawaited(AppAudioService.instance.playTowerUpgrade());
      } else {
        unawaited(AppAudioService.instance.playTowerPlaceFail());
      }
    } else if (action == TowerAction.sell) {
      final refund = tower.sellRefund;
      battleGold += refund;
      tower.removeFromParent();
      towers.remove(cell);
    }
  }

  GridPoint? _worldToGrid(Vector2 pos) {
    final local = pos - mapOrigin;
    if (local.x < 0 || local.y < 0) return null;
    final x = (local.x / tileSize).floor();
    final y = (local.y / tileSize).floor();
    if (x < 0 || y < 0 || x >= gridWidth || y >= gridHeight) return null;
    return GridPoint(x, y);
  }

  bool _isBuildable(GridPoint cell) => buildCells.contains(cell);

  Set<GridPoint> _buildCellsFromDef(MapDef mapDef) {
    if (mapDef.buildCells.isNotEmpty) {
      return mapDef.buildCells.map((p) => GridPoint(p.x, p.y)).toSet();
    }
    final pathSet = path.toSet();
    final cells = <GridPoint>{};
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final cell = GridPoint(x, y);
        if (!pathSet.contains(cell)) {
          cells.add(cell);
        }
      }
    }
    return cells;
  }

  void spawnEnemy(EnemyType type, EnemyDef def) {
    final waveNumber = displayedWaveNumber;
    final waveDef = waves[currentWaveIndex];
    final enemy = Enemy(
      gameRef: this,
      type: type,
      def: def,
      path: path,
      hpMultiplier: difficultyDef.hpMultiplier *
          waveScalingConfig.hpMultiplierForWave(waveNumber) *
          waveDef.hpMultiplierBonus,
      speedMultiplier: difficultyDef.speedMultiplier *
          waveScalingConfig.speedMultiplierForWave(waveNumber) *
          waveDef.speedMultiplierBonus,
      rewardMultiplier: waveScalingConfig.rewardMultiplierForWave(waveNumber),
    );
    enemies.add(enemy);
    add(enemy);
  }

  void spawnEnemyById(String enemyId) {
    final def = enemyDefs[enemyId];
    if (def == null) return;
    final type = switch (enemyId) {
      'sprinter_basic' => EnemyType.sprinter,
      'tank_basic' => EnemyType.tank,
      'brute_basic' => EnemyType.brute,
      'scout_basic' => EnemyType.scout,
      'spitter_basic' => EnemyType.spitter,
      'armored_basic' => EnemyType.armored,
      'swarm_basic' => EnemyType.swarm,
      'elite_basic' => EnemyType.elite,
      'boss_basic' => EnemyType.boss,
      _ => EnemyType.grunt,
    };
    spawnEnemy(type, def);
  }

  void damageCore(double amount) {
    if (debugInfiniteCore) {
      coreHp = coreMaxHp;
      coreShield = coreMaxShield;
      core.setStats(coreHp, coreMaxHp, coreShield, coreMaxShield);
      return;
    }
    unawaited(AppAudioService.instance.playCoreHit());
    final reduced = amount * (1.0 - coreDefenseRate).clamp(0.0, 1.0);
    var remaining = reduced;
    if (coreShield > 0) {
      final used = coreShield >= remaining ? remaining : coreShield;
      coreShield -= used;
      remaining -= used;
    }
    if (remaining > 0) {
      coreHp = (coreHp - remaining).clamp(0, coreMaxHp);
    }
    core.setStats(coreHp, coreMaxHp, coreShield, coreMaxShield);
    if (coreHp <= 0 && _isLoseCondition('coreDestroyed')) {
      _onDefeat();
    }
  }

  void spawnTowerEffect(String towerId, int index, Vector2 worldPos,
      {double scale = 1.0}) {
    if (_visualEffectsSpawnedThisFrame >= _maxVisualEffectsPerFrame) return;
    _visualEffectsSpawnedThisFrame++;
    final path = _towerEffectPath(towerId, index);
    final size = Vector2(tileSize * 0.9 * scale, tileSize * 0.9 * scale);
    final effect = TowerEffect(
      gameRef: this,
      spritePath: path,
      worldPos: worldPos,
      size: size,
    );
    add(effect);
  }

  void spawnTowerSpecialEffect(String towerId, Enemy target,
      {double scale = 1.0}) {
    if (_visualEffectsSpawnedThisFrame >= _maxVisualEffectsPerFrame) return;
    _visualEffectsSpawnedThisFrame++;
    final effect = EnemyAttachedTowerEffect(
      gameRef: this,
      target: target,
      spritePath: _towerSpecialEffectPath(towerId),
      size: Vector2(tileSize * 1.0 * scale, tileSize * 1.0 * scale),
    );
    add(effect);
  }

  void spawnDamageText(Vector2 worldPos, double amount) {
    if (!showDamage) return;
    if (_damageTextsSpawnedThisFrame >= _maxDamageTextsPerFrame) return;
    _damageTextsSpawnedThisFrame++;
    String text;
    if (amount >= 1000) {
      text = (amount / 1000).toStringAsFixed(amount >= 10000 ? 0 : 1) + 'K';
    } else if (amount >= 10) {
      text = amount.toStringAsFixed(0);
    } else {
      text = amount.toStringAsFixed(1);
    }
    final dmg = DamageText(
      text: text,
      position: worldPos,
    );
    add(dmg);
  }

  void spawnBattleNotice(String text) {
    add(
      DamageText(
        text: text,
        position: Vector2(size.x / 2, mapOrigin.y + tileSize * 0.9),
        lifeTime: 1.2,
      ),
    );
  }

  Map<String, UltimateFxDef> _parseUltimateFx(Map<String, dynamic> json) {
    final map = <String, UltimateFxDef>{};
    json.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        map[key] = UltimateFxDef.fromJson(value);
      }
    });
    return map;
  }

  UltimateFxDef? getUltimateFx(String towerId) {
    final base = ultimateFx['default'];
    final specific = ultimateFx[towerId];
    if (base == null) return specific;
    if (specific == null) return base;
    return base.merge(specific);
  }

  void spawnShockwave(Vector2 worldPos, ShockwaveDef def) {
    if (_visualEffectsSpawnedThisFrame >= _maxVisualEffectsPerFrame) return;
    _visualEffectsSpawnedThisFrame++;
    final effect = ShockwaveEffect(
      worldPos: worldPos,
      color: def.color,
      maxRadius: tileSize * def.radiusTiles,
      strokeWidth: def.width,
      life: def.duration,
    );
    add(effect);
  }

  void spawnEnemyEffect(EnemyType type, Vector2 worldPos,
      {double scale = 1.0}) {
    if (_visualEffectsSpawnedThisFrame >= _maxVisualEffectsPerFrame) return;
    _visualEffectsSpawnedThisFrame++;
    final path = _enemyEffectPath(type);
    final size = Vector2(tileSize * 0.9 * scale, tileSize * 0.9 * scale);
    final effect = TowerEffect(
      gameRef: this,
      spritePath: path,
      worldPos: worldPos,
      size: size,
    );
    add(effect);
  }

  void _onDefeat() {
    if (defeated || continueOverlay != null) return;
    defeated = true;
    spawner.pauseSpawning();
    if (!isInfiniteMode && !continueUsed) {
      continueOverlay = ContinueOverlay(gameRef: this);
      add(continueOverlay!);
      return;
    }
    _showDefeatResult();
  }

  void addBattleGold(int amount) {
    battleGold += amount;
  }

  void addBattleGoldScaled(int amount, {double extraMultiplier = 1.0}) {
    final scaled =
        (amount * difficultyDef.rewardMultiplier * extraMultiplier).round();
    battleGold += scaled;
  }

  void _cycleTargetRule() {
    final values = TargetingRule.values;
    final nextIndex = (currentRule.index + 1) % values.length;
    currentRule = values[nextIndex];
  }

  void _toggleSpeed() {
    timeScale = timeScale >= 1.5 ? 1.0 : 2.0;
  }

  void _setSpeed(double value) {
    timeScale = value;
  }

  void debugSpawn(String id) {
    spawnEnemyById(id);
  }

  void debugLevelUpTowers() {
    for (final tower in towers.values) {
      tower.upgrade();
    }
  }

  void _advanceWaveIfPossible() {
    if (isInfiniteMode) {
      currentWaveIndex = (currentWaveIndex + 1) % waves.length;
      infiniteWaveNumber++;
      waveClearRewarded = false;
      waveAdvanceDelayTimer = 0;
      spawner.resetWith(waves[currentWaveIndex]);
      if (_waveHasBoss(waves[currentWaveIndex])) {
        unawaited(AppAudioService.instance.playBossAlert());
        unawaited(AppAudioService.instance.playBossAlertStinger());
      }
      return;
    }
    if (currentWaveIndex >= waves.length - 1) {
      if (debugInfiniteWaves) {
        currentWaveIndex = 0;
        waveClearRewarded = false;
        waveAdvanceDelayTimer = 0;
        spawner.resetWith(waves[currentWaveIndex]);
        return;
      }
      if (_isWinCondition('allWavesCleared')) {
        _onVictory();
      }
      return;
    }
    currentWaveIndex++;
    waveClearRewarded = false;
    waveAdvanceDelayTimer = 0;
    spawner.resetWith(waves[currentWaveIndex]);
    if (_waveHasBoss(waves[currentWaveIndex])) {
      unawaited(AppAudioService.instance.playBossAlert());
      unawaited(AppAudioService.instance.playBossAlertStinger());
    }
  }

  bool _waveHasBoss(WaveDef wave) {
    return wave.spawns.any((spawn) => spawn.enemyId == 'boss_basic');
  }

  bool _isWinCondition(String key) => modeDef.winCondition == key;
  bool _isLoseCondition(String key) => modeDef.loseCondition == key;
  bool get isInfiniteMode => modeDef.id == 'endless_survival';
  int get displayedWaveNumber =>
      isInfiniteMode ? infiniteWaveNumber : currentWaveIndex + 1;

  void _onVictory() {
    if (victory || defeated) return;
    victory = true;
    spawner.pauseSpawning();
    timeScale = 1.0;
    resultActionPending = false;
    continueOverlay?.removeFromParent();
    continueOverlay = null;
    speedAdOverlay?.removeFromParent();
    speedAdOverlay = null;
    _closePicker();
    _closeTowerPanel();
    unawaited(AppAudioService.instance.playVictoryJingle()); // 내부에서 stopBgm/stopAllSfx 처리
    unawaited(_grantEndRewardsIfNeeded());
    if (!isInfiniteMode) {
      unawaited(_saveStageRankingIfNeeded());
    }
    resultOverlay = ResultOverlay(
      gameRef: this,
      title: '승리',
      subtitle: '모든 웨이브를 막았습니다',
      onExit: onExitToLobby,
    );
    add(resultOverlay!);
  }

  void _showDefeatResult() {
    if (resultOverlay != null) return;
    defeated = true;
    spawner.pauseSpawning();
    timeScale = 1.0;
    resultActionPending = false;
    continueOverlay?.removeFromParent();
    continueOverlay = null;
    speedAdOverlay?.removeFromParent();
    speedAdOverlay = null;
    _closePicker();
    _closeTowerPanel();
    for (final enemy in enemies) {
      enemy.removeFromParent();
    }
    enemies.clear();
    unawaited(AppAudioService.instance.playDefeatJingle()); // 내부에서 stopBgm/stopAllSfx 처리
    if (isInfiniteMode) {
      finalInfiniteScore = _calculateInfiniteScore();
      unawaited(_saveInfiniteScoreIfNeeded());
    } else {
      unawaited(_grantEndRewardsIfNeeded());
      unawaited(_saveStageRankingIfNeeded());
    }
    resultOverlay = ResultOverlay(
      gameRef: this,
      title: '패배',
      subtitle: '코어가 파괴되었습니다',
      onExit: onExitToLobby,
    );
    add(resultOverlay!);
  }

  void _continueFromDefeat() {
    continueUsed = true;
    continueOverlay?.removeFromParent();
    continueOverlay = null;
    unawaited(AppAudioService.instance.stopAllSfx());
    for (final enemy in enemies) {
      enemy.removeFromParent();
    }
    enemies.clear();
    coreHp = coreMaxHp;
    coreShield = coreMaxShield;
    core.setStats(coreHp, coreMaxHp, coreShield, coreMaxShield);
    defeated = false;
    // waveClearRewarded는 리셋하지 않음:
    // 이미 클리어 보상을 받은 웨이브는 true를 유지하여 컨티뉴 후 중복 지급 방지
    waveAdvanceDelayTimer = 0;
    spawner.resetWith(waves[currentWaveIndex]);
    spawnBattleNotice('광고 컨티뉴: 현재 웨이브 재시작');
  }

  Future<void> _handleSpeedAdOverlayAction(SpeedAdOverlayAction action) async {
    try {
      if (action == SpeedAdOverlayAction.unlockAd) {
        final watched = await AppAdService.instance.showRewardedAd();
        if (watched) {
          adSpeedUnlocked = true;
          timeScale = 2.0;
          spawnBattleNotice('광고 보상: 2배속 사용 가능');
          speedAdOverlay?.removeFromParent();
          speedAdOverlay = null;
        }
        // 광고 미시청 시 오버레이 유지 (다시 시도 가능)
        return;
      }
      speedAdOverlay?.removeFromParent();
      speedAdOverlay = null;
    } finally {
      resultActionPending = false;
    }
  }

  ({int gold, int tickets}) _calculateEndRewards() {
    final reached = (currentWaveIndex + 1).clamp(0, waves.length);
    if (reached <= 0) {
      return (gold: 0, tickets: 0);
    }

    final goldPerWave = switch (difficultyId) {
      'easy' => 180,
      'normal' => 260,
      'hard' => 380,
      'nightmare' => 520,
      _ => 180,
    };
    final goldReward = reached * goldPerWave;

    final ticketChance = switch (reached) {
      >= 45 => 0.85,
      >= 35 => 0.65,
      >= 25 => 0.45,
      >= 15 => 0.28,
      >= 5 => 0.12,
      _ => 0.0,
    };

    int tickets = 0;
    if (rng.nextDouble() < ticketChance) {
      final roll = rng.nextDouble();
      if (roll < 0.72) {
        tickets = 1;
      } else if (roll < 0.94) {
        tickets = 2;
      } else {
        tickets = 3;
      }
    }

    return (gold: goldReward, tickets: tickets);
  }

  int _killScoreForEnemy(EnemyDef def) {
    return switch (def.archetype) {
      'boss' => 250,
      'elite' => 45,
      'armored' => 24,
      'tank' => 18,
      'ranged' => 16,
      'fast' => 12,
      'swarm' => 8,
      _ => 10,
    };
  }

  void registerEnemyKill(EnemyDef def) {
    enemyKillScore += _killScoreForEnemy(def);
  }

  String get rankingPlayerName {
    final nickname = accountProgress.nickname.trim();
    if (nickname.isEmpty) return 'PLAYER';
    return nickname;
  }

  int _calculateInfiniteScore() {
    final reached = displayedWaveNumber;
    final waveScore = reached * 1000;
    final waveBonus = reached * reached * 12;
    final hpRatio = coreMaxHp <= 0 ? 0.0 : (coreHp / coreMaxHp).clamp(0.0, 1.0);
    final shieldRatio =
        coreMaxShield <= 0 ? 0.0 : (coreShield / coreMaxShield).clamp(0.0, 1.0);
    final coreBonus = (hpRatio * 2000).round() + (shieldRatio * 1000).round();
    final installRatio = TowerDefenseGame.maxPlacedTowers <= 0
        ? 1.0
        : (highestPlacedTowerCount / TowerDefenseGame.maxPlacedTowers)
            .clamp(0.0, 1.0);
    final installBonus = ((1.0 - installRatio) * (reached * 120)).round();
    return waveScore + enemyKillScore + waveBonus + coreBonus + installBonus;
  }

  Future<void> _grantEndRewardsIfNeeded() async {
    final inFlight = _endRewardsFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _grantEndRewardsInternal();
    _endRewardsFuture = future;
    try {
      await future;
    } finally {
      if (identical(_endRewardsFuture, future)) {
        _endRewardsFuture = null;
      }
    }
  }

  Future<void> _grantEndRewardsInternal() async {
    if (isInfiniteMode || endRewardsGranted || stageDef.id == 'test_u_stage') {
      return;
    }
    final reached = (currentWaveIndex + 1).clamp(0, waves.length);
    final currentBest = accountProgress.bestWaveByDifficulty[difficultyId] ?? 0;
    if (reached > currentBest) {
      accountProgress.bestWaveByDifficulty[difficultyId] = reached;
    }

    final rewards = _calculateEndRewards();
    endRewardGold = rewards.gold;
    endRewardTickets = rewards.tickets;
    if (rewards.gold <= 0 && rewards.tickets <= 0) {
      endRewardsGranted = true;
      return;
    }

    accountProgress.accountGold += rewards.gold;
    accountGold += rewards.gold;
    if (rewards.tickets > 0) {
      accountProgress.shardDrawTickets += rewards.tickets;
    }

    if (rewards.gold > 0) {
      unawaited(EconomyLogRepository().logCurrencyChange(
        source: 'battle_end_reward',
        currency: 'accountGold',
        amount: rewards.gold,
        balanceAfter: accountProgress.accountGold,
        metadata: {
          'stageId': stageDef.id,
          'difficultyId': difficultyId,
          'reachedWave': reached,
        },
      ));
    }
    if (rewards.tickets > 0) {
      unawaited(EconomyLogRepository().logCurrencyChange(
        source: 'battle_end_reward',
        currency: 'shardDrawTickets',
        amount: rewards.tickets,
        balanceAfter: accountProgress.shardDrawTickets,
        metadata: {
          'stageId': stageDef.id,
          'difficultyId': difficultyId,
          'reachedWave': reached,
        },
      ));
    }

    await AccountProgressRepository().save(accountProgress);
    endRewardsGranted = true;  // 저장 성공 후에만 플래그 설정
  }

  Future<void> _saveStageRankingIfNeeded() async {
    final inFlight = _stageRankingFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _saveStageRankingInternal();
    _stageRankingFuture = future;
    try {
      await future;
    } finally {
      if (identical(_stageRankingFuture, future)) {
        _stageRankingFuture = null;
      }
    }
  }

  Future<void> _saveStageRankingInternal() async {
    if (isInfiniteMode || stageRankingSaved || stageDef.id == 'test_u_stage') {
      return;
    }
    final reached = (currentWaveIndex + 1).clamp(0, waves.length);
    if (reached <= 0) {
      return;
    }
    final difficultyLabel = switch (difficultyId) {
      'easy' => '이지',
      'normal' => '노말',
      'hard' => '하드',
      'nightmare' => '나이트메어',
      _ => difficultyId,
    };
    final rankingRepo = RankingRepository();
    if (!rankingRepo.hasAuthenticatedUser) {
      return;
    }
    try {
      await rankingRepo.addStageScore(
        rankingPlayerName,
        reached,
        detail: difficultyLabel,
      );
      stageRankingSaved = true;
    } catch (e, st) {
      debugPrint('[RankingSave] 랭킹 저장 실패: $e\n$st');
    }
  }

  Future<void> _doubleEndRewards() async {
    await _grantEndRewardsIfNeeded();
    if (endRewardsDoubled || !endRewardsGranted) {
      return;
    }
    endRewardsDoubled = true;
    if (endRewardGold <= 0 && endRewardTickets <= 0) {
      return;
    }

    accountProgress.accountGold += endRewardGold;
    accountGold += endRewardGold;
    if (endRewardTickets > 0) {
      accountProgress.shardDrawTickets += endRewardTickets;
    }
    if (endRewardGold > 0) {
      unawaited(EconomyLogRepository().logCurrencyChange(
        source: 'battle_end_reward_double',
        currency: 'accountGold',
        amount: endRewardGold,
        balanceAfter: accountProgress.accountGold,
        metadata: {
          'stageId': stageDef.id,
          'difficultyId': difficultyId,
          'reachedWave': (currentWaveIndex + 1).clamp(0, waves.length),
        },
      ));
    }
    if (endRewardTickets > 0) {
      unawaited(EconomyLogRepository().logCurrencyChange(
        source: 'battle_end_reward_double',
        currency: 'shardDrawTickets',
        amount: endRewardTickets,
        balanceAfter: accountProgress.shardDrawTickets,
        metadata: {
          'stageId': stageDef.id,
          'difficultyId': difficultyId,
          'reachedWave': (currentWaveIndex + 1).clamp(0, waves.length),
        },
      ));
    }
    await AccountProgressRepository().save(accountProgress);
  }

  Future<void> _saveInfiniteScoreIfNeeded() async {
    final inFlight = _infiniteScoreFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final future = _saveInfiniteScoreInternal();
    _infiniteScoreFuture = future;
    try {
      await future;
    } finally {
      if (identical(_infiniteScoreFuture, future)) {
        _infiniteScoreFuture = null;
      }
    }
  }

  Future<void> _saveInfiniteScoreInternal() async {
    if (!isInfiniteMode ||
        infiniteScoreSaved ||
        stageDef.id == 'test_u_stage') {
      return;
    }
    final reached = displayedWaveNumber;
    if (reached > accountProgress.bestInfiniteWave) {
      accountProgress.bestInfiniteWave = reached;
    }
    final rankingRepo = RankingRepository();
    if (!rankingRepo.hasAuthenticatedUser) {
      return;
    }
    try {
      await rankingRepo.addInfiniteScore(
        rankingPlayerName,
        finalInfiniteScore,
      );
      infiniteScoreSaved = true;
    } catch (e, st) {
      debugPrint('[InfiniteSave] 점수 저장 실패: $e\n$st');
    }
    await AccountProgressRepository().save(accountProgress);
  }

  Future<void> _handleResultOverlayAction(ResultOverlayAction action) async {
    final reachedWave = isInfiniteMode
        ? displayedWaveNumber
        : (currentWaveIndex + 1).clamp(0, waves.length);
    try {
      if (isInfiniteMode) {
        await _saveInfiniteScoreIfNeeded();
        unawaited(AnalyticsRepository().logBattleResult(
          playerName: rankingPlayerName,
          mode: 'infinite',
          difficultyId: difficultyId,
          stageId: stageDef.id,
          reachedWave: reachedWave,
          victory: false,
          accountGoldReward: 0,
          ticketReward: 0,
          infiniteScore: finalInfiniteScore,
          highestPlacedTowerCount: highestPlacedTowerCount,
          usedContinue: continueUsed,
        ));
        return;
      }
      if (action == ResultOverlayAction.doubleReward) {
        final watched = await AppAdService.instance.showRewardedAd();
        if (watched) {
          await _doubleEndRewards();
        } else {
          await _grantEndRewardsIfNeeded();
        }
      } else {
        await _grantEndRewardsIfNeeded();
      }
      await _saveStageRankingIfNeeded();
      unawaited(AnalyticsRepository().logBattleResult(
        playerName: rankingPlayerName,
        mode: 'story',
        difficultyId: difficultyId,
        stageId: stageDef.id,
        reachedWave: reachedWave,
        victory: victory,
        accountGoldReward: endRewardsDoubled ? endRewardGold * 2 : endRewardGold,
        ticketReward: endRewardsDoubled ? endRewardTickets * 2 : endRewardTickets,
        infiniteScore: 0,
        highestPlacedTowerCount: highestPlacedTowerCount,
        usedContinue: continueUsed,
      ));
    } catch (e, st) {
      debugPrint('[ResultAction] 저장 중 오류: $e\n$st');
    } finally {
      onExitToLobby?.call();
    }
  }

  Future<void> _handleContinueOverlayAction(
      ContinueOverlayAction action) async {
    try {
      if (action == ContinueOverlayAction.continueAd) {
        final watched = await AppAdService.instance.showRewardedAd();
        if (watched) {
          _continueFromDefeat();
        }
        // 광고 미시청 시 오버레이 유지 (다시 시도 또는 포기 선택 가능)
      } else {
        continueOverlay?.removeFromParent();
        continueOverlay = null;
        _showDefeatResult();
      }
    } finally {
      resultActionPending = false;
    }
  }
}

part of 'tower_management_screen.dart';

extension _TowerManagementScreenViewExt on _TowerManagementScreenState {
  Widget _towerGridTile(TowerDef def) {
    final p = progress.towers[def.id] ??
        TowerProgress(towerId: def.id, unlocked: false);
    final rarityColor = _rarityColor(def.rarity);

    return InkWell(
      onTap: p.unlocked ? () => _openTowerDetailSheet(def) : null,
      borderRadius: BorderRadius.circular(0),
      child: Ink(
        decoration: BoxDecoration(
          color: p.unlocked ? const Color(0xFFFDFEFF) : const Color(0xFFEDEFF5),
          border: Border.all(color: const Color(0xFF9EB1DF), width: 0.9),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(3, 3, 3, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 72,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        rarityColor.withOpacity(0.26),
                        const Color(0xFFFFFFFF)
                      ],
                    ),
                    border: Border.all(
                        color: rarityColor.withOpacity(0.6), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: p.unlocked
                                ? Image.asset(
                                    _towerManageImagePath(def.id),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFE2E8F8),
                                      child: const Icon(
                                          Icons.image_not_supported,
                                          size: 18),
                                    ),
                                  )
                                : ColorFiltered(
                                    colorFilter:
                                        const ColorFilter.matrix(<double>[
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0.2126,
                                      0.7152,
                                      0.0722,
                                      0,
                                      0,
                                      0,
                                      0,
                                      0,
                                      1,
                                      0,
                                    ]),
                                    child: Image.asset(
                                      _towerManageImagePath(def.id),
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      color: Colors.black.withOpacity(0.85),
                                      colorBlendMode: BlendMode.darken,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: const Color(0xFF0E1522),
                                        child: const Icon(
                                            Icons.image_not_supported,
                                            size: 18),
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned.fill(
                            child: TowerVisualFxOverlay(
                              permanentLevel: p.level,
                              towerId: def.id,
                              rarity: def.rarity,
                              opacity: p.unlocked ? 0.9 : 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _towerDisplayNameKoMultiline(def.id),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  height: 1.06,
                  color: Color(0xFFF4F8FF),
                  shadows: [
                    Shadow(
                      color: Color(0xCC07111F),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                'Lv.${p.level}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: p.unlocked
                      ? const Color(0xFFCFE1FF)
                      : const Color(0xFF7F90B2),
                  shadows: const [
                    Shadow(
                      color: Color(0xCC07111F),
                      blurRadius: 5,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTowerDetailSheet(TowerDef def) async {
    final p = progress.towers[def.id] ??
        TowerProgress(towerId: def.id, unlocked: false);
    final lp = progress.lobbyUpgrades[def.id] ??
        TowerLobbyUpgradeProgress(towerId: def.id);
    progress.towers[def.id] = p;
    progress.lobbyUpgrades[def.id] = lp;
    final maxLevel = 15;
    final maxTrackLevel = _lobbyMaxTrackLevel();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            final levelUpCost = _levelUpShards(def, p.level);
            final canLevelUp = p.level < maxLevel && p.shards >= levelUpCost;
            final maxPoints = p.level.clamp(1, maxLevel);
            final usedPoints = lp.identity + lp.operations + lp.synergy;
            final remainingPoints = math.max(0, maxPoints - usedPoints);

            void applyChange(VoidCallback fn) {
              setState(fn);
              sheetSetState(() {});
            }

            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFDFEFF), Color(0xFFE9F1FF)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF93AEE8), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                          border: Border(
                            bottom: BorderSide(
                                color:
                                    const Color(0xFFC8D8FA).withOpacity(0.9)),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 98,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                          color: _rarityColor(def.rarity),
                                          width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x22000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Stack(
                                        children: [
                                          Image.asset(
                                            _towerManageImagePath(def.id),
                                            width: 98,
                                            height: 98,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 98,
                                              height: 98,
                                              color: const Color(0xFFE2E8F8),
                                              child: const Icon(
                                                  Icons.image_not_supported),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: TowerVisualFxOverlay(
                                              permanentLevel: p.level,
                                              towerId: def.id,
                                              rarity: def.rarity,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _sheetLevelActionButton(
                                    label: (p.level >= maxLevel)
                                        ? 'MAX'
                                        : '${p.shards}/$levelUpCost\n레벨업',
                                    enabled: canLevelUp,
                                    onPressed: () {
                                      final previousLevel = p.level;
                                      applyChange(() {
                                        if (canLevelUp) {
                                          p.shards -= levelUpCost;
                                          p.level += 1;
                                        }
                                        progress.towers[def.id] = p;
                                      });
                                      if (p.level != previousLevel) {
                                        economyLogRepo.logUpgrade(
                                          upgradeType: 'tower_level',
                                          targetId: def.id,
                                          fromLevel: previousLevel,
                                          toLevel: p.level,
                                          metadata: {'shardCost': levelUpCost},
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 156,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _towerDisplayNameKo(def.id),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF21366F),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _rarityColor(def.rarity)
                                                .withOpacity(0.14),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                                color: _rarityColor(def.rarity),
                                                width: 1.2),
                                          ),
                                          child: Text(
                                            _rarityLabelKo(def.rarity),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _rarityColor(def.rarity),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _sheetStatChip(
                                            '레벨 ${p.level}/$maxLevel'),
                                        _sheetStatChip(
                                            '포인트 $remainingPoints/$maxPoints'),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '공격타입 ${_attackTypeLabelKo(def.attackType)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4E648F),
                                      ),
                                    ),
                                    const Spacer(),
                                    _towerHeaderSkillIcons(
                                      def.id,
                                      onSkillTap: (index) {
                                        _showSkillDescriptionOverlay(
                                          context,
                                          def.id,
                                          index,
                                          p,
                                          lp,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: _towerDescriptionBox(def.id),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: _towerInfoPanel(def, p, lp),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          children: [
                            _lobbyTrackControl(
                              def: def,
                              trackId: 'identity',
                              label: _trackCardTitle(def, 'identity'),
                              level: lp.identity,
                              maxLevel: maxTrackLevel,
                              canUpgrade: lp.identity < maxTrackLevel &&
                                  remainingPoints > 0,
                              disabledReason: _trackDisabledReason(
                                unlocked: true,
                                level: lp.identity,
                                maxLevel: maxTrackLevel,
                                remainingPoints: remainingPoints,
                              ),
                              onUpgrade: () {
                                final previous = lp.identity;
                                applyChange(() {
                                  if (lp.identity >= maxTrackLevel ||
                                      remainingPoints <= 0) {
                                    return;
                                  }
                                  lp.identity += 1;
                                  progress.lobbyUpgrades[def.id] = lp;
                                });
                                if (lp.identity != previous) {
                                  economyLogRepo.logUpgrade(
                                    upgradeType: 'tower_identity_point',
                                    targetId: def.id,
                                    fromLevel: previous,
                                    toLevel: lp.identity,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            _lobbyTrackControl(
                              def: def,
                              trackId: 'operations',
                              label: _trackCardTitle(def, 'operations'),
                              level: lp.operations,
                              maxLevel: maxTrackLevel,
                              canUpgrade: lp.operations < maxTrackLevel &&
                                  remainingPoints > 0,
                              disabledReason: _trackDisabledReason(
                                unlocked: true,
                                level: lp.operations,
                                maxLevel: maxTrackLevel,
                                remainingPoints: remainingPoints,
                              ),
                              onUpgrade: () {
                                final previous = lp.operations;
                                applyChange(() {
                                  if (lp.operations >= maxTrackLevel ||
                                      remainingPoints <= 0) {
                                    return;
                                  }
                                  lp.operations += 1;
                                  progress.lobbyUpgrades[def.id] = lp;
                                });
                                if (lp.operations != previous) {
                                  economyLogRepo.logUpgrade(
                                    upgradeType: 'tower_operations_point',
                                    targetId: def.id,
                                    fromLevel: previous,
                                    toLevel: lp.operations,
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            _lobbyTrackControl(
                              def: def,
                              trackId: 'synergy',
                              label: _trackCardTitle(def, 'synergy'),
                              level: lp.synergy,
                              maxLevel: maxTrackLevel,
                              canUpgrade: lp.synergy < maxTrackLevel &&
                                  remainingPoints > 0,
                              disabledReason: _trackDisabledReason(
                                unlocked: true,
                                level: lp.synergy,
                                maxLevel: maxTrackLevel,
                                remainingPoints: remainingPoints,
                              ),
                              onUpgrade: () {
                                final previous = lp.synergy;
                                applyChange(() {
                                  if (lp.synergy >= maxTrackLevel ||
                                      remainingPoints <= 0) {
                                    return;
                                  }
                                  lp.synergy += 1;
                                  progress.lobbyUpgrades[def.id] = lp;
                                });
                                if (lp.synergy != previous) {
                                  economyLogRepo.logUpgrade(
                                    upgradeType: 'tower_synergy_point',
                                    targetId: def.id,
                                    fromLevel: previous,
                                    toLevel: lp.synergy,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: AppPanelButton(
                                    label: usedPoints > 0
                                        ? '다이아 100 초기화'
                                        : '초기화 불가',
                                    compact: true,
                                    onPressed: usedPoints > 0 &&
                                            progress.diamonds >= 100
                                        ? () {
                                            final balanceAfter =
                                                progress.diamonds - 100;
                                            applyChange(() {
                                              progress.diamonds -= 100;
                                              lp.identity = 0;
                                              lp.operations = 0;
                                              lp.synergy = 0;
                                              progress.lobbyUpgrades[def.id] =
                                                  lp;
                                            });
                                            economyLogRepo.logCurrencyChange(
                                              source:
                                                  'tower_point_reset_diamond',
                                              currency: 'diamonds',
                                              amount: -100,
                                              balanceAfter: balanceAfter,
                                              metadata: {'towerId': def.id},
                                            );
                                            economyLogRepo.logUpgrade(
                                              upgradeType: 'tower_point_reset',
                                              targetId: def.id,
                                              fromLevel: usedPoints,
                                              toLevel: 0,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: AppPanelButton(
                                    label: usedPoints > 0
                                        ? '광고 초기화 ${((5 - progress.adPointResetDailyCount).clamp(0, 5))}/5'
                                        : '초기화 불가',
                                    compact: true,
                                    onPressed: usedPoints > 0
                                        ? () async {
                                            final watched = await AppAdService
                                                .instance
                                                .showRewardedAd();
                                            if (!watched) return;
                                            final now = DateTime.now();
                                            final month = now.month
                                                .toString()
                                                .padLeft(2, '0');
                                            final day = now.day
                                                .toString()
                                                .padLeft(2, '0');
                                            final today =
                                                '${now.year}-$month-$day';
                                            if (progress.adDailyDate != today) {
                                              progress.adDailyDate = today;
                                              progress.adPointResetDailyCount =
                                                  0;
                                              progress
                                                  .adShardDrawTenDailyCount = 0;
                                            }
                                            if (progress
                                                    .adPointResetDailyCount >=
                                                5) {
                                              showDialog<void>(
                                                context: context,
                                                builder: (context) => Dialog(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF102033),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                        color: const Color(
                                                            0xFF83B5FF),
                                                        width: 1.4,
                                                      ),
                                                      boxShadow: const [
                                                        BoxShadow(
                                                          color:
                                                              Color(0x66000000),
                                                          blurRadius: 20,
                                                          offset: Offset(0, 10),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Text(
                                                          '알림',
                                                          style: TextStyle(
                                                            color: Color(
                                                                0xFFF3F7FF),
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 12),
                                                        const Text(
                                                          '광고 포인트 초기화는 하루 5회까지만 가능합니다.',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color: Color(
                                                                0xFFD9E7FF),
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            height: 1.35,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                            height: 14),
                                                        AppPanelButton(
                                                          label: '확인',
                                                          compact: true,
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            applyChange(() {
                                              progress.adPointResetDailyCount +=
                                                  1;
                                              lp.identity = 0;
                                              lp.operations = 0;
                                              lp.synergy = 0;
                                              progress.lobbyUpgrades[def.id] =
                                                  lp;
                                            });
                                            economyLogRepo.logAdReward(
                                              placement: 'tower_point_reset',
                                              reward: {
                                                'towerId': def.id,
                                                'reset': true
                                              },
                                            );
                                            economyLogRepo.logUpgrade(
                                              upgradeType:
                                                  'tower_point_reset_ad',
                                              targetId: def.id,
                                              fromLevel: usedPoints,
                                              toLevel: 0,
                                            );
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AppPanelButton(
                              label: '닫기',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _lobbyTrackControl({
    required TowerDef def,
    required String trackId,
    required String label,
    required int level,
    required int maxLevel,
    required bool canUpgrade,
    required String disabledReason,
    required VoidCallback onUpgrade,
  }) {
    final key = _trackKey(def.id, trackId);
    final perLevel = _trackPerLevel(def.id, trackId);
    final cap = _trackCap(def.id, trackId);
    final currentBonus = _trackBonusAtLevel(def.id, trackId, level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FF)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC8D7FA)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A468A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$level/$maxLevel',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2A468A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  '레벨당 ${_formatTrackValue(perLevel, key)} | 최대 ${_formatTrackValue(cap, key)}',
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF4964A8)),
                ),
                Text(
                  '현재 효과 ${_formatTrackValue(currentBonus, key)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF1D4FB8),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!canUpgrade)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      disabledReason,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF8A2A2A)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: AppPanelButton(
              label: canUpgrade ? '강화' : '강화 불가',
              onPressed: canUpgrade ? onUpgrade : null,
            ),
          ),
        ],
      ),
    );
  }

  String _trackDisabledReason({
    required bool unlocked,
    required int level,
    required int maxLevel,
    required int remainingPoints,
  }) {
    if (!unlocked) return '잠금: 타워 해금 필요';
    if (level >= maxLevel) return '최대 레벨 도달';
    if (remainingPoints <= 0) return '포인트 부족: 타워 레벨업 필요';
    return '';
  }

  String _trackCardTitle(TowerDef def, String trackId) {
    final key = _trackKey(def.id, trackId);
    return _upgradeKeyLabel(key);
  }

  Widget _towerInfoPanel(
    TowerDef def,
    TowerProgress p,
    TowerLobbyUpgradeProgress lp,
  ) {
    final towerLevel = p.level;
    final effectiveDamage = _effectiveDamage(def, towerLevel, lp.operations);
    final damageDelta = effectiveDamage - def.baseDamage;
    final effectiveInterval =
        _effectiveAttackInterval(def, towerLevel, lp.operations);
    final intervalDelta = effectiveInterval - def.fireRate;
    final effectiveRange = _effectiveRange(def, towerLevel, lp.operations);
    final rangeDelta = effectiveRange - def.range;
    final identityKey = _trackKey(def.id, 'identity');
    final synergyKey = _trackKey(def.id, 'synergy');
    final identityBonus = _trackBonusAtLevel(def.id, 'identity', lp.identity);
    final synergyBonus = _trackBonusAtLevel(def.id, 'synergy', lp.synergy);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F7FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8D7FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _infoCompactStatCell(
                  '공격력',
                  def.baseDamage
                      .toStringAsFixed(def.baseDamage % 1 == 0 ? 0 : 1),
                  _formatSignedValue(damageDelta),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _infoCompactStatCell(
                  '공격주기',
                  '${def.fireRate.toStringAsFixed(2)}s',
                  '${_formatSignedValue(intervalDelta)}s',
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _infoCompactStatCell(
                  '사거리',
                  def.range.toStringAsFixed(0),
                  _formatSignedValue(rangeDelta),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _infoPillWithAccent(
                  _upgradeKeyLabel(identityKey),
                  _formatTrackValue(identityBonus, identityKey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _infoPillWithAccent(
                  _upgradeKeyLabel(synergyKey),
                  _formatTrackValue(synergyBonus, synergyKey),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _infoPlaceholderPill(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sheetStatChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFECF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCAD9FB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2C4F9D),
        ),
      ),
    );
  }

  Widget _sheetLevelActionButton({
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    final top = enabled ? const Color(0xFF4A77E8) : const Color(0xFFBCC4D8);
    final bottom = enabled ? const Color(0xFF2E57BF) : const Color(0xFFA4ADBF);
    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(9),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [top, bottom],
              ),
              border: Border.all(
                color:
                    enabled ? const Color(0xFF1F3D8B) : const Color(0xFF8D95A8),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(String label, String value) {
    final text = label.isEmpty ? value : '$label: $value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0DDFB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A468A),
        ),
      ),
    );
  }

  Widget _infoPillWithAccent(String label, String accentValue) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0DDFB)),
      ),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2A468A),
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: accentValue,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFD84315),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPlaceholderPill() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0DDFB)),
      ),
      child: const Text(
        '???',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A468A),
        ),
      ),
    );
  }

  Widget _infoCompactStatCell(
      String label, String baseValue, String deltaValue) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0DDFB)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A468A),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            baseValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A468A),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '($deltaValue)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Color(0xFFD84315),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _towerDescriptionBox(String towerId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F7FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8D7FA)),
      ),
      child: Text(
        _towerBriefDescription(towerId),
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF3C4F86),
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _towerHeaderSkillIcons(
    String towerId, {
    required ValueChanged<int> onSkillTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Transform.translate(
          offset: const Offset(0, 6),
          child: _skillIconFrame(
            towerId,
            1,
            size: 56,
            onTap: () => onSkillTap(1),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 6),
          child: _skillIconFrame(
            towerId,
            2,
            size: 56,
            onTap: () => onSkillTap(2),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, 6),
          child: _skillIconFrame(
            towerId,
            3,
            size: 56,
            onTap: () => onSkillTap(3),
          ),
        ),
      ],
    );
  }

  Future<void> _showSkillDescriptionOverlay(
    BuildContext context,
    String towerId,
    int index,
    TowerProgress progress,
    TowerLobbyUpgradeProgress lobbyProgress,
  ) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'skill_desc',
      barrierColor: const Color(0x99000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 18,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFFFFF), Color(0xFFF0F6FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF8FB0EA), width: 1.4),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _skillDescriptionText(
                            towerId,
                            index,
                            progress,
                            lobbyProgress,
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF314B86),
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  String _skillDescriptionText(
    String towerId,
    int index,
    TowerProgress progress,
    TowerLobbyUpgradeProgress lobbyProgress,
  ) {
    final def = towerDefs[towerId];
    if (def == null) {
      return '설명 데이터를 불러오는 중';
    }

    if (index == 1) {
      final effectiveDamage =
          _effectiveDamage(def, progress.level, lobbyProgress.operations);
      final effectiveInterval = _effectiveAttackInterval(
          def, progress.level, lobbyProgress.operations);
      final effectiveRange =
          _effectiveRange(def, progress.level, lobbyProgress.operations);
      final damage =
          effectiveDamage.toStringAsFixed(effectiveDamage % 1 == 0 ? 0 : 1);
      return '${_basicAttackSummary(towerId)}\n'
          '공격력 $damage, 공격주기 ${effectiveInterval.toStringAsFixed(2)}초, '
          '사거리 ${effectiveRange.toStringAsFixed(0)}, '
          '${_attackTypeLabelKo(def.attackType)} 방식';
    }
    if (index == 2) {
      return '${_skillSimpleDescription(towerId, index)}\n'
          '발동 확률 ${_formatPercent(def.ultimateChance)}, '
          '피해 배율 x${def.ultimateDamageMultiplier.toStringAsFixed(2)}, '
          '${_ultimateAlphaSummary(towerId)}';
    }
    return '${_skillSimpleDescription(towerId, index)}\n'
        '${_specialEffectNumericSummary(def)}';
  }

  String _formatPercent(double v) {
    return '${(v * 100).toStringAsFixed(v * 100 >= 10 ? 0 : 1)}%';
  }

  String _specialEffectNumericSummary(TowerDef def) {
    if (def.effects.isEmpty) return '특수효과 수치 없음';
    final lv1 = def.effects.where((e) => (e.atLevel ?? 1) <= 1).toList();
    final lv7 = def.effects.where((e) => (e.atLevel ?? 1) >= 7).toList();
    final first = lv1.isNotEmpty ? lv1.first : def.effects.first;
    final boosted = lv7.isNotEmpty ? lv7.first : null;
    final baseText = _effectLine(def.id, first);
    if (boosted == null) return baseText;
    return '$baseText, Lv7 강화: ${_effectLine(def.id, boosted)}';
  }

  String _effectLine(String towerId, TowerEffectSpec e) {
    switch (e.type) {
      case 'slow':
        return '감속 ${_formatPercent((e.value ?? 0).clamp(0, 0.95).toDouble())}, 지속 ${_fmtSec(e.durationSec)}';
      case 'freeze':
        return '빙결 확률 ${_formatPercent((e.chance ?? 0).clamp(0, 1).toDouble())}, 지속 ${_fmtSec(e.durationSec)}';
      case 'vulnerability':
        return '취약 ${_formatPercent((e.value ?? 0).clamp(0, 1.5).toDouble())}, 지속 ${_fmtSec(e.durationSec)}';
      case 'time_dilate':
        return '시간왜곡 ${_formatPercent((e.value ?? 0).clamp(0, 0.8).toDouble())}, 지속 ${_fmtSec(e.durationSec)}';
      case 'pull':
        return '끌어당김 ${((e.value ?? 1).round())}칸, 확률 ${_formatPercent((e.chance ?? 1).clamp(0, 1).toDouble())}';
      case 'dot':
        return '도트 ${((e.value ?? 0)).toStringAsFixed((e.value ?? 0) % 1 == 0 ? 0 : 1)}/초, 지속 ${_fmtSec(e.durationSec)}';
      case 'attack_weaken':
        return '공격약화 ${_formatPercent((e.value ?? 0).clamp(0, 0.8).toDouble())}, 지속 ${_fmtSec(e.durationSec)}';
      case 'chain_arc':
        return '연쇄피해 ${_formatPercent((e.value ?? 0).clamp(0, 2).toDouble())}, 연쇄수 ${e.maxStack ?? 1}';
      case 'max_hp_burst':
        return '최대체력 비례 ${_formatPercent((e.value ?? 0).clamp(0, 0.3).toDouble())}';
      default:
        return _towerSpecialEffectSummary(towerId);
    }
  }

  String _fmtSec(double? v) {
    final sec = v ?? 0;
    return '${sec.toStringAsFixed(sec >= 1 ? 1 : 2)}초';
  }

  String _ultimateAlphaSummary(String towerId) {
    return switch (towerId) {
      'cannon_basic' => '주변 3명 폭발+감속',
      'rapid_basic' => '주변 4명 연사 확산+취약',
      'shotgun_basic' => '근접 산탄 강화+추가타격',
      'frost_basic' => '주변 2명 추가 빙결',
      'drone_basic' => '주변 4명 공격약화 강화',
      'chain_basic' => '연쇄 대상수/피해 증가',
      'missile_basic' => '주변 4명 폭발+취약 확산',
      'support_basic' => '주변 5명 강한 취약+코어실드 회복',
      'laser_basic' => '주변 3명 도트 확산',
      'sniper_basic' => '저체력 처형+1명 관통',
      'gravity_basic' => '주변 4명 2칸 끌어당김+감속',
      'infection_basic' => '주변 4명 감염+약한 취약',
      'chrono_basic' => '주변 5명 시간왜곡+감속',
      'singularity_basic' => '주변 6명 붕괴+끌어당김',
      'mortar_basic' => '주변 5명 포격+장시간 감속',
      _ => '타워별 추가 효과',
    };
  }

  String _skillSimpleDescription(String towerId, int index) {
    return switch (index) {
      1 => '기본 타격으로 전투의 핵심 화력을 담당',
      2 => switch (towerId) {
          'cannon_basic' => '폭발 반경을 넓혀 군집 적을 한 번에 무너뜨리는 강화 포격',
          'rapid_basic' => '초고속 연사로 다수 적에게 취약을 빠르게 퍼뜨리는 강화 사격',
          'shotgun_basic' => '강한 근접 산탄으로 전열을 무너뜨리는 폭딜 제압 사격',
          'frost_basic' => '광역 빙결 파동으로 적 진군을 끊어내는 냉각 폭주',
          'drone_basic' => '드론 화력을 폭주시켜 적 전열의 공격력을 크게 깎는 집중 요격',
          'chain_basic' => '연쇄 전류를 증폭해 적 무리를 순식간에 감전시키는 과부하 방전',
          'missile_basic' => '확산 폭격으로 취약 표식을 넓게 남기는 미사일 폭주',
          'support_basic' => '강한 취약 지원과 실드 회복으로 전장을 안정화시키는 지원 프로토콜 폭증',
          'laser_basic' => '고출력 레이저로 도트 피해를 급격히 누적하는 과열 조사',
          'sniper_basic' => '핵심 적을 꿰뚫어 전선을 정리하는 정밀 처형 사격',
          'gravity_basic' => '중력장을 압축해 적 무리를 한곳으로 끌어모으는 왜곡 붕괴',
          'infection_basic' => '감염 확산을 가속해 적 전체를 오염시키는 바이러스 폭발',
          'chrono_basic' => '시간 왜곡을 넓게 퍼뜨려 전장의 흐름을 멈추게 하는 크로노 폭주',
          'singularity_basic' => '특이점을 증폭해 고체력 적까지 붕괴시키는 초중력 포격',
          'mortar_basic' => '대형 포격과 장시간 제어로 진군을 묶어두는 박격 제압',
          _ => '타워 고유 성능을 극대화하는 궁극기',
        },
      _ => _towerSpecialEffectSummary(towerId),
    };
  }

  String _basicAttackSummary(String towerId) {
    return switch (towerId) {
      'cannon_basic' => '폭발탄으로 군집을 압박하는 광역 화력형 기본공격',
      'rapid_basic' => '초고속 연사로 약한 적을 정리하며 취약 갱신을 이어가는 기본공격',
      'shotgun_basic' => '짧은 사거리에서 강한 산탄 피해를 몰아넣는 근접 폭딜 기본공격',
      'frost_basic' => '빙결 연계를 위한 제어 중심 견제형 기본공격',
      'drone_basic' => '안정적인 투사체 견제로 공격약화 효과를 오래 유지하는 기본공격',
      'chain_basic' => '인접 적까지 연쇄 타격하는 전기 확산형 기본공격',
      'missile_basic' => '고단일 폭딜로 핵심 목표를 빠르게 제거하는 기본공격',
      'support_basic' => '장거리 안정 타격으로 강한 취약 지원을 이어가는 기본공격',
      'laser_basic' => '정밀 빔 타격으로 지속 압박을 누적하는 기본공격',
      'sniper_basic' => '긴 사거리 고위력으로 후방에서 저격하는 기본공격',
      'gravity_basic' => '고위력 투사체로 적 동선을 흔드는 제어형 기본공격',
      'infection_basic' => '감염 누적을 노리는 지속 압박형 기본공격',
      'chrono_basic' => '시간왜곡 연계를 위한 템포 제어형 기본공격',
      'singularity_basic' => '초고위력 포격으로 전장을 붕괴시키는 중화기 기본공격',
      'mortar_basic' => '포물선 포격으로 넓은 지역을 견제하는 박격 기본공격',
      _ => '전투 핵심 화력을 담당하는 기본공격',
    };
  }

  String _skillLabel(int index) {
    return switch (index) {
      1 => '기본공격',
      2 => '궁극기',
      _ => '특수효과',
    };
  }

  String _towerSpecialEffectSummary(String towerId) {
    return switch (towerId) {
      'cannon_basic' => '연쇄 포격으로 주변 적에게 추가 피해를 연결',
      'rapid_basic' => '취약 디버프를 빠르게 갱신해 약한 적 처리 효율을 증폭',
      'shotgun_basic' => '짧은 사거리 대신 높은 순간 화력으로 전면 돌파를 저지',
      'frost_basic' => '빙결로 적 행동을 끊어 전선 유지 시간을 확보',
      'drone_basic' => '적 공격력을 크게 약화시켜 코어 피해를 감소',
      'chain_basic' => '전기 연쇄로 인접 적까지 동시 타격',
      'missile_basic' => '취약 표식으로 단일 고체력 대상 처리력 강화',
      'support_basic' => '강한 취약 지원과 실드 회복으로 아군 전체 화력을 보조',
      'laser_basic' => '지속 도트로 장기전 누적 피해를 강화',
      'sniper_basic' => '강한 단일 타격과 취약 부여로 핵심 목표 제거',
      'gravity_basic' => '끌어당김으로 적 동선을 뒤로 되돌려 지연',
      'infection_basic' => '감염 도트로 지속 피해와 전염 압박 제공',
      'chrono_basic' => '시간 왜곡으로 적 이동/행동 템포를 저하시킴',
      'singularity_basic' => '최대체력 비례 폭발로 고체력 적에게 강한 피해',
      'mortar_basic' => '광역 감속으로 군집 적 진군을 장시간 통제',
      _ => '전투 상황에 맞춰 고유 효과를 부여',
    };
  }

  Widget _towerSkillIcons(String towerId) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8D7FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '스킬',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A468A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _skillIconFrame(towerId, 1),
              _skillIconFrame(towerId, 2),
              _skillIconFrame(towerId, 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skillIconFrame(
    String towerId,
    int index, {
    double size = 76,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      _towerSkillIconPath(towerId, index),
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image,
                            color: Color(0xFF8EA4D8)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0E1A34),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFF6E8FD6), width: 0.8),
                        ),
                        child: Text(
                          _skillLabel(index),
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

part of 'tower_management_screen.dart';

extension _TowerManagementScreenLogicExt on _TowerManagementScreenState {
  String _towerSkillIconPath(String towerId, int index) {
    final base = _towerDisplayName(towerId);
    return 'assets/images/towers_skill/${base}_$index.png';
  }

  String _rarityLabelKo(String rarity) {
    return switch (rarity) {
      'common' => '일반',
      'rare' => '보통',
      'unique' => '유니크',
      'legendary' => '전설',
      _ => rarity,
    };
  }

  String _attackTypeLabelKo(String attackType) {
    return switch (attackType) {
      'hitscan' => '히트스캔',
      'projectile' => '투사체',
      _ => attackType,
    };
  }

  String _trackRoleDescription(String trackId) {
    return switch (trackId) {
      'identity' => '핵심효과 강화',
      'operations' => '전투운영 강화',
      'synergy' => '조합시너지 강화',
      _ => '강화',
    };
  }

  String _trackKey(String towerId, String trackId) {
    final towers = lobbyPresets?['towers'];
    if (towers is! Map) return '';
    final tower = towers[towerId];
    if (tower is! Map) return '';
    final track = tower[trackId];
    if (track is! Map) return '';
    return (track['key'] as String?) ?? '';
  }

  double _trackPerLevel(String towerId, String trackId) {
    final towers = lobbyPresets?['towers'];
    if (towers is! Map) return 0;
    final tower = towers[towerId];
    if (tower is! Map) return 0;
    final track = tower[trackId];
    if (track is! Map) return 0;
    return (track['perLevel'] as num?)?.toDouble() ?? 0;
  }

  double _trackCap(String towerId, String trackId) {
    final towers = lobbyPresets?['towers'];
    if (towers is! Map) return 0;
    final tower = towers[towerId];
    if (tower is! Map) return 0;
    final track = tower[trackId];
    if (track is! Map) return 0;
    return (track['cap'] as num?)?.toDouble() ?? 0;
  }

  double _trackBonusAtLevel(String towerId, String trackId, int level) {
    final perLevel = _trackPerLevel(towerId, trackId);
    final cap = _trackCap(towerId, trackId);
    final raw = level * perLevel;
    if (cap <= 0) return raw;
    return raw.clamp(0, cap).toDouble();
  }

  String _upgradeKeyLabel(String key) {
    return switch (key) {
      'effect.chain_arc.value' => '연쇄 피해량',
      'stat.range_pct' => '사거리 증가',
      'vs.vulnerable_damage_pct' => '취약 대상 추가 피해',
      'effect.vulnerability.value' => '취약 배율',
      'stat.fire_rate_pct' => '공격주기 단축',
      'on_mark_refresh_damage_pct' => '표식 갱신 추가 피해',
      'effect.slow.value' => '감속 강도',
      'stat.damage_pct' => '공격력 증가',
      'vs.slowed_damage_pct' => '감속 대상 추가 피해',
      'effect.vulnerability.duration_pct' => '취약 지속시간',
      'build.cost_reduction_pct' => '건설 비용 절감',
      'ally_damage_aura_pct' => '아군 공격력 오라',
      'effect.slow.duration_pct' => '감속 지속시간',
      'on_heavy_hit_vulnerable_chance' => '강타 시 취약 부여 확률',
      'effect.chain_arc.max_targets' => '연쇄 최대 타겟',
      'vs.chained_damage_pct' => '연쇄 대상 추가 피해',
      'effect.attack_weaken.value' => '공격력 약화 수치',
      'stat.projectile_speed_pct' => '투사체 속도',
      'core_damage_mitigation_bonus' => '코어 피해 경감',
      'effect.freeze.duration_pct' => '빙결 지속시간',
      'vs.frozen_damage_pct' => '빙결 대상 추가 피해',
      'effect.dot.value_pct' => '도트 피해량',
      'dot_spread_chance' => '도트 확산 확률',
      'effect.dot.duration_pct' => '도트 지속시간',
      'vs.dot_target_damage_pct' => '도트 대상 추가 피해',
      'effect.pull.chance_flat' => '끌어당김 발동 확률',
      'on_pull_vulnerable_apply' => '끌어당김 시 취약 부여',
      'critical_vs_marked_pct' => '표식 대상 치명 보정',
      'splash_vs_marked_pct' => '표식 대상 폭발 피해',
      'effect.time_dilate.value' => '시간왜곡 강도',
      'vs.time_dilated_damage_pct' => '왜곡 대상 추가 피해',
      'effect.max_hp_burst.value' => '최대체력 비례 피해',
      'execute_threshold_bonus' => '처형 임계치 증가',
      _ => key.isEmpty ? '효과 정보 없음' : key,
    };
  }

  String _formatTrackValue(double value, String key) {
    if (key.contains('max_targets')) {
      return '+${value.toStringAsFixed(2)}';
    }
    return '+${(value * 100).toStringAsFixed(value * 100 >= 10 ? 0 : 1)}%';
  }

  String _formatSignedValue(double value) {
    final sign = value >= 0 ? '+' : '-';
    final abs = value.abs();
    return '$sign${abs.toStringAsFixed(abs >= 10 ? 0 : 1)}';
  }

  double _operationsBonusForKeyAtLevel(TowerDef def, int operationsLevel, String key) {
    final opKey = _trackKey(def.id, 'operations');
    if (opKey != key) return 0;
    return _trackBonusAtLevel(def.id, 'operations', operationsLevel);
  }

  PermanentGrowthConfig _growthForTower(String towerId) {
    final config = balanceConfig;
    if (config == null) {
      return const PermanentGrowthConfig(
        damagePercentPerLevel: 0.06,
        fireRatePercentPerLevel: 0.03,
        rangeBonusEveryLevels: 4,
        rangeBonusPerStep: 0.15,
      );
    }
    return config.growthForTower(towerId);
  }

  int _safePermanentLevel(int rawLevel) {
    return rawLevel.clamp(1, 15).toInt();
  }

  double _permanentDamageMultiplier(TowerDef def, int towerLevel) {
    final growth = _growthForTower(def.id);
    final bonusLevel = _safePermanentLevel(towerLevel) - 1;
    return 1.0 + bonusLevel * growth.damagePercentPerLevel;
  }

  double _permanentFireRateMultiplier(TowerDef def, int towerLevel) {
    final growth = _growthForTower(def.id);
    final bonusLevel = _safePermanentLevel(towerLevel) - 1;
    return (1.0 - bonusLevel * growth.fireRatePercentPerLevel).clamp(0.35, 1.0);
  }

  double _permanentRangeBonus(TowerDef def, int towerLevel) {
    final growth = _growthForTower(def.id);
    final bonusLevel = _safePermanentLevel(towerLevel) - 1;
    if (growth.rangeBonusEveryLevels <= 0) return 0.0;
    if (bonusLevel < growth.rangeBonusEveryLevels) return 0.0;
    return growth.rangeBonusPerStep * (bonusLevel ~/ growth.rangeBonusEveryLevels);
  }

  double _effectiveDamage(TowerDef def, int towerLevel, int operationsLevel) {
    final dmgPct = _operationsBonusForKeyAtLevel(def, operationsLevel, 'stat.damage_pct');
    final base = def.baseDamage * _permanentDamageMultiplier(def, towerLevel);
    return base * (1 + dmgPct);
  }

  double _effectiveAttackInterval(TowerDef def, int towerLevel, int operationsLevel) {
    final fireRatePct = _operationsBonusForKeyAtLevel(def, operationsLevel, 'stat.fire_rate_pct');
    final base = def.fireRate * _permanentFireRateMultiplier(def, towerLevel);
    final mul = (1 - fireRatePct).clamp(0.7, 1.0);
    return base * mul;
  }

  double _effectiveRange(TowerDef def, int towerLevel, int operationsLevel) {
    final rangePct = _operationsBonusForKeyAtLevel(def, operationsLevel, 'stat.range_pct');
    final base = def.range + _permanentRangeBonus(def, towerLevel);
    return base + def.range * rangePct;
  }

  String _rangeTypeLabelKo(TowerDef def) {
    final types = def.effects.map((e) => e.type).toSet();
    if (types.contains('chain_arc')) return '연쇄';
    if (def.attackType == 'projectile' && def.projectileSize >= 30) return '광역';
    return '단일';
  }

  String _towerBriefDescription(String id) {
    return switch (id) {
      'cannon_basic' => '폭발 탄을 발사해 넓은 범위를 안정적으로 압박하는 기본 화력 타워',
      'rapid_basic' => '초고속 연사로 약한 적을 빠르게 정리하고 취약을 갱신하는 타워',
      'shotgun_basic' => '짧은 사거리에서 강한 산탄 피해를 몰아넣는 근접 폭딜 타워',
      'frost_basic' => '빙결 효과로 적의 이동을 끊어 아군 포화 시간을 벌어주는 제어형 타워',
      'drone_basic' => '적의 공격력을 크게 약화시켜 전열 부담을 줄이는 지원형 투사체 타워',
      'chain_basic' => '전기를 튕겨 인접 적까지 동시에 타격하는 연쇄 화력 타워',
      'missile_basic' => '강한 미사일 타격과 취약 부여로 단일 고체력 적을 빠르게 녹이는 타워',
      'support_basic' => '강한 취약 디버프로 아군 전체 화력을 끌어올리는 지원 타워',
      'laser_basic' => '도트 피해를 꾸준히 누적시켜 긴 전투에서 효율이 높은 레이저 타워',
      'sniper_basic' => '긴 사거리와 높은 단발 피해로 핵심 목표를 정확히 제거하는 저격 타워',
      'gravity_basic' => '중력 왜곡으로 적의 진군을 지연시켜 동선을 재정렬하는 제어 특화 타워',
      'infection_basic' => '감염 디버프로 지속 피해를 부여해 적 체력을 안정적으로 깎아내는 타워',
      'chrono_basic' => '시간 왜곡으로 적의 행동 속도를 늦춰 전체 전장의 템포를 장악하는 타워',
      'singularity_basic' => '특이점 충격으로 고체력 적에게 강한 비례 피해를 주는 최상위 화력 타워',
      'mortar_basic' => '박격 포격으로 넓은 범위를 감속시키며 군집 적을 제어하는 광역 타워',
      _ => '전투 상황에 맞춰 핵심 역할을 수행하는 전술 타워',
    };
  }

  List<String> _orderedTowerIds() {
    final ids = [...kTowerIds];
    ids.sort((a, b) {
      final ar = _rarityRank(towerDefs[a]?.rarity);
      final br = _rarityRank(towerDefs[b]?.rarity);
      if (ar != br) return ar.compareTo(br);
      return _towerDisplayNameKo(a).compareTo(_towerDisplayNameKo(b));
    });
    return ids;
  }

  int _rarityRank(String? rarity) {
    return switch (rarity) {
      'common' => 0,
      'rare' => 1,
      'unique' => 2,
      'legendary' => 3,
      _ => 9,
    };
  }

  String _towerDisplayNameKoMultiline(String id) {
    final name = _towerDisplayNameKo(id).trim();
    final firstSpace = name.indexOf(' ');
    if (firstSpace <= 0 || firstSpace >= name.length - 1) return name;
    final first = name.substring(0, firstSpace).trim();
    final second = name.substring(firstSpace + 1).trim();
    return '$first\n$second';
  }

  int _lobbyMaxTrackLevel() {
    return (lobbyConfig?['maxTrackLevel'] as int?) ?? 15;
  }

  void _normalizeLobbyPoints(
    TowerProgress p,
    TowerLobbyUpgradeProgress lp,
    int maxTrackLevel,
  ) {
    lp.identity = lp.identity.clamp(0, maxTrackLevel);
    lp.operations = lp.operations.clamp(0, maxTrackLevel);
    lp.synergy = lp.synergy.clamp(0, maxTrackLevel);

    final maxPoints = p.unlocked ? p.level.clamp(1, 15) : 0;
    while (lp.identity + lp.operations + lp.synergy > maxPoints) {
      if (lp.synergy > 0) {
        lp.synergy -= 1;
      } else if (lp.operations > 0) {
        lp.operations -= 1;
      } else if (lp.identity > 0) {
        lp.identity -= 1;
      } else {
        break;
      }
    }
  }

  int _levelUpShards(TowerDef def, int level) {
    final multiplier = math.pow(def.levelUpShardsMultiplier, (level - 1)).toDouble();
    return (def.levelUpShardsBase * multiplier).round();
  }

  String _towerManageImagePath(String towerId) => 'assets/images/main_towers/$towerId.png';
}


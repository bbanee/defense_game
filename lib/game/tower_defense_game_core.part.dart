part of 'tower_defense_game.dart';

enum EnemyType {
  grunt,
  sprinter,
  tank,
  brute,
  scout,
  spitter,
  armored,
  swarm,
  elite,
  boss,
}

enum EnemyAnim { right, up, hit, die }

String _enemySpritePath(EnemyType type) {
  return switch (type) {
    EnemyType.grunt => 'enemies/Runner Drone.png',
    EnemyType.sprinter => 'enemies/Riot Bot.png',
    EnemyType.tank => 'enemies/Shield Carrier.png',
    EnemyType.brute => 'enemies/Swarm Mite.png',
    EnemyType.scout => 'enemies/Repair Unit.png',
    EnemyType.spitter => 'enemies/Phase Stalker.png',
    EnemyType.armored => 'enemies/EMP Wasp.png',
    EnemyType.swarm => 'enemies/Siege Mech.png',
    EnemyType.elite => 'enemies/Clone Husk.png',
    EnemyType.boss => 'enemies/Data Behemoth.png',
  };
}

String _enemyEffectPath(EnemyType type) {
  return switch (type) {
    EnemyType.grunt => 'enemies_effect/Runner Drone.png',
    EnemyType.sprinter => 'enemies_effect/Riot Bot.png',
    EnemyType.tank => 'enemies_effect/Shield Carrier.png',
    EnemyType.brute => 'enemies_effect/Swarm Mite.png',
    EnemyType.scout => 'enemies_effect/Repair Unit.png',
    EnemyType.spitter => 'enemies_effect/Phase Stalker.png',
    EnemyType.armored => 'enemies_effect/EMP Wasp.png',
    EnemyType.swarm => 'enemies_effect/Siege Mech.png',
    EnemyType.elite => 'enemies_effect/Clone Husk.png',
    EnemyType.boss => 'enemies_effect/Data Behemoth.png',
  };
}

String? _towerSpritePath(String towerId) {
  return switch (towerId) {
    'cannon_basic' => 'towers/Pulse Turret.png',
    'rapid_basic' => 'towers/Railguard Battery.png',
    'shotgun_basic' => 'towers/Scatter Blaster.png',
    'frost_basic' => 'towers/Frost Relay.png',
    'drone_basic' => 'towers/Drone Dock.png',
    'chain_basic' => 'towers/Tesla Arc Node.png',
    'missile_basic' => 'towers/Missile Matrix.png',
    'support_basic' => 'towers/Nano Support Beacon.png',
    'laser_basic' => 'towers/Prism Laser Array.png',
    'sniper_basic' => 'towers/Holo Sniper Spire.png',
    'gravity_basic' => 'towers/Gravity Well Emitter.png',
    'infection_basic' => 'towers/Virus Injector.png',
    'chrono_basic' => 'towers/Chrono Distortion Core.png',
    'singularity_basic' => 'towers/Singularity Cannon.png',
    'mortar_basic' => 'towers/Aegis AI Citadel.png',
    _ => null,
  };
}


Color _rarityColor(String? rarity) {
  return switch (rarity) {
    'common' => const Color(0xFF6C63FF),
    'rare' => const Color(0xFF00D2A5),
    'unique' => const Color(0xFFB85BFF),
    'legendary' => const Color(0xFFFFC857),
    _ => const Color(0xFF7A7A7A),
  };
}

String _towerLabelFromId(String id) {
  final base = id.split('_').first;
  if (base.length <= 2) return base.toUpperCase();
  return base.substring(0, 2).toUpperCase();
}

String _towerDisplayName(String id) {
  return switch (id) {
    'cannon_basic' => 'Pulse Turret',
    'rapid_basic' => 'Railguard Battery',
    'shotgun_basic' => 'Scatter Blaster',
    'frost_basic' => 'Frost Relay',
    'drone_basic' => 'Drone Dock',
    'chain_basic' => 'Tesla Arc Node',
    'missile_basic' => 'Missile Matrix',
    'support_basic' => 'Nano Support Beacon',
    'laser_basic' => 'Prism Laser Array',
    'sniper_basic' => 'Holo Sniper Spire',
    'gravity_basic' => 'Gravity Well Emitter',
    'infection_basic' => 'Virus Injector',
    'chrono_basic' => 'Chrono Distortion Core',
    'singularity_basic' => 'Singularity Cannon',
    'mortar_basic' => 'Aegis AI Citadel',
    _ => id,
  };
}

String _towerDisplayNameKo(String id) {
  return switch (id) {
    'cannon_basic' => '캐논 터렛',
    'rapid_basic' => '래피드 포탑',
    'shotgun_basic' => '샷건 포탑',
    'frost_basic' => '프로스트 타워',
    'drone_basic' => '드론 기지',
    'chain_basic' => '체인 노드',
    'missile_basic' => '미사일 매트릭스',
    'support_basic' => '서포트 비콘',
    'laser_basic' => '레이저 어레이',
    'sniper_basic' => '스나이퍼 스파이어',
    'gravity_basic' => '그래비티 웰',
    'infection_basic' => '인펙션 인젝터',
    'chrono_basic' => '크로노 코어',
    'singularity_basic' => '싱귤래리티 캐논',
    'mortar_basic' => '모르타 시타델',
    _ => id,
  };
}

enum TargetingRule { nearest, farthestProgress, highestHp, lowestHp }

enum TacticalModule { none, focus, overclock, range }

const List<String> kAllTowerIds = [
  'cannon_basic',
  'rapid_basic',
  'shotgun_basic',
  'frost_basic',
  'drone_basic',
  'chain_basic',
  'missile_basic',
  'support_basic',
  'laser_basic',
  'sniper_basic',
  'gravity_basic',
  'infection_basic',
  'chrono_basic',
  'singularity_basic',
  'mortar_basic',
];



class CoreProgress {
  int level;
  int hp;
  int shield;
  double defenseRate;
  int hpLevel;
  int shieldLevel;
  int defenseLevel;

  CoreProgress({
    this.level = 1,
    this.hp = 3000,
    this.shield = 400,
    this.defenseRate = 0.10,
    this.hpLevel = 1,
    this.shieldLevel = 1,
    this.defenseLevel = 1,
  });

  factory CoreProgress.fromJson(Map<String, dynamic> json) {
    return CoreProgress(
      level: json['level'] as int? ?? 1,
      hp: json['hp'] as int? ?? 3000,
      shield: json['shield'] as int? ?? 400,
      defenseRate: (json['defenseRate'] as num?)?.toDouble() ?? 0.10,
      hpLevel: json['hpLevel'] as int? ?? 1,
      shieldLevel: json['shieldLevel'] as int? ?? 1,
      defenseLevel: json['defenseLevel'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'hp': hp,
      'shield': shield,
      'defenseRate': defenseRate,
      'hpLevel': hpLevel,
      'shieldLevel': shieldLevel,
      'defenseLevel': defenseLevel,
    };
  }

  CoreProgress copy() {
    return CoreProgress(
      level: level,
      hp: hp,
      shield: shield,
      defenseRate: defenseRate,
      hpLevel: hpLevel,
      shieldLevel: shieldLevel,
      defenseLevel: defenseLevel,
    );
  }
}

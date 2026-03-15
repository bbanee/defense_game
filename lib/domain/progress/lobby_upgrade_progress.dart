class TowerLobbyUpgradeProgress {
  final String towerId;
  int identity;
  int operations;
  int synergy;

  TowerLobbyUpgradeProgress({
    required this.towerId,
    this.identity = 0,
    this.operations = 0,
    this.synergy = 0,
  });

  factory TowerLobbyUpgradeProgress.fromJson(
    String towerId,
    Map<String, dynamic> json,
  ) {
    return TowerLobbyUpgradeProgress(
      towerId: towerId,
      identity: json['identity'] as int? ?? 0,
      operations: json['operations'] as int? ?? 0,
      synergy: json['synergy'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identity': identity,
      'operations': operations,
      'synergy': synergy,
    };
  }

  TowerLobbyUpgradeProgress copy() {
    return TowerLobbyUpgradeProgress(
      towerId: towerId,
      identity: identity,
      operations: operations,
      synergy: synergy,
    );
  }
}

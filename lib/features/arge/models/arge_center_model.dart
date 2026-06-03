class ArgeCenterModel {
  final String id;
  final String playerId;
  final String name;
  final int level;
  final int maxConcurrentResearches;
  final double durationReductionPct;
  final bool isActive;

  const ArgeCenterModel({
    required this.id,
    required this.playerId,
    required this.name,
    required this.level,
    required this.maxConcurrentResearches,
    required this.durationReductionPct,
    required this.isActive,
  });

  factory ArgeCenterModel.fromJson(Map<String, dynamic> json) {
    return ArgeCenterModel(
      id: (json['id'] ?? '').toString(),
      playerId: (json['player_id'] ?? '').toString(),
      name: (json['name'] ?? 'AR-GE Merkezi').toString(),
      level: (json['level'] as num?)?.toInt() ?? 1,
      maxConcurrentResearches:
          (json['max_concurrent_researches'] as num?)?.toInt() ?? 1,
      durationReductionPct:
          (json['duration_reduction_pct'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

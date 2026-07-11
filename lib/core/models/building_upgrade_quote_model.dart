class BuildingUpgradeEffectModel {
  const BuildingUpgradeEffectModel({
    required this.metricKey,
    required this.operation,
    required this.value,
    required this.previousValue,
    required this.nextValue,
  });

  final String metricKey;
  final String operation;
  final double value;
  final double previousValue;
  final double nextValue;

  double get increase => nextValue - previousValue;

  factory BuildingUpgradeEffectModel.fromJson(Map<String, dynamic> json) {
    return BuildingUpgradeEffectModel(
      metricKey: (json['metric_key'] ?? '').toString(),
      operation: (json['operation'] ?? '').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      previousValue: (json['previous_value'] as num?)?.toDouble() ?? 0,
      nextValue: (json['next_value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BuildingUpgradeQuoteModel {
  const BuildingUpgradeQuoteModel({
    required this.canUpgrade,
    required this.blockReason,
    required this.buildingKind,
    required this.entityId,
    required this.currentLevel,
    required this.targetLevel,
    required this.maxLevel,
    required this.requiredPlayerLevel,
    required this.cashCost,
    required this.durationSeconds,
    required this.effects,
  });

  final bool canUpgrade;
  final String? blockReason;
  final String buildingKind;
  final String entityId;
  final int currentLevel;
  final int? targetLevel;
  final int maxLevel;
  final int? requiredPlayerLevel;
  final double cashCost;
  final int durationSeconds;
  final List<BuildingUpgradeEffectModel> effects;

  bool get isMaximumLevel => blockReason == 'maximum_level';
  int get durationMinutes => (durationSeconds / 60).ceil();

  String get requirementLabel {
    if (blockReason == 'active_upgrade') {
      return 'Baska bir bina yukseltmesi devam ediyor';
    }
    if (blockReason == 'inactive') {
      return 'Yukseltme icin bina aktif olmali';
    }
    return 'Gerekli oyuncu seviyesi: ${requiredPlayerLevel ?? 1}';
  }

  BuildingUpgradeEffectModel? effect(String metricKey) {
    for (final effect in effects) {
      if (effect.metricKey == metricKey) return effect;
    }
    return null;
  }

  factory BuildingUpgradeQuoteModel.fromJson(Map<String, dynamic> json) {
    final rawEffects = json['effects'] as List? ?? const [];
    return BuildingUpgradeQuoteModel(
      canUpgrade: json['can_upgrade'] == true,
      blockReason: json['block_reason']?.toString(),
      buildingKind: (json['building_kind'] ?? '').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      currentLevel: (json['current_level'] as num?)?.toInt() ?? 1,
      targetLevel: (json['target_level'] as num?)?.toInt(),
      maxLevel: (json['max_level'] as num?)?.toInt() ?? 5,
      requiredPlayerLevel: (json['required_player_level'] as num?)?.toInt(),
      cashCost: (json['cash_cost'] as num?)?.toDouble() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      effects: rawEffects
          .whereType<Map>()
          .map(
            (effect) => BuildingUpgradeEffectModel.fromJson(
              Map<String, dynamic>.from(effect),
            ),
          )
          .toList(growable: false),
    );
  }
}

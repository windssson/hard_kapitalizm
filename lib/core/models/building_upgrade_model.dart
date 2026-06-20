class BuildingUpgradeModel {
  final String id;
  final String buildingKind;
  final String entityId;
  final int currentLevel;
  final int targetLevel;
  final String status;
  final DateTime startedAt;
  final DateTime finishAt;
  final DateTime? completedAt;
  final String? name;
  final int durationMinutes;
  final double upgradeCost;
  final int slotCapacityIncrease;
  final int maxSlotIncrease;
  final int previousSlotCapacity;
  final int nextSlotCapacity;
  final int previousMaxSlotCount;
  final int nextMaxSlotCount;
  final int inputCapacityIncrease;
  final int outputCapacityIncrease;
  final int previousInputCapacity;
  final int nextInputCapacity;
  final int previousOutputCapacity;
  final int nextOutputCapacity;
  final double capacityIncrease;
  final double previousCapacity;
  final double nextCapacity;
  final Map<String, dynamic> params;

  const BuildingUpgradeModel({
    required this.id,
    required this.buildingKind,
    required this.entityId,
    required this.currentLevel,
    required this.targetLevel,
    required this.status,
    required this.startedAt,
    required this.finishAt,
    required this.completedAt,
    required this.name,
    required this.durationMinutes,
    required this.upgradeCost,
    required this.slotCapacityIncrease,
    required this.maxSlotIncrease,
    required this.previousSlotCapacity,
    required this.nextSlotCapacity,
    required this.previousMaxSlotCount,
    required this.nextMaxSlotCount,
    required this.inputCapacityIncrease,
    required this.outputCapacityIncrease,
    required this.previousInputCapacity,
    required this.nextInputCapacity,
    required this.previousOutputCapacity,
    required this.nextOutputCapacity,
    required this.capacityIncrease,
    required this.previousCapacity,
    required this.nextCapacity,
    required this.params,
  });

  bool get isInProgress => status == 'in_progress';

  factory BuildingUpgradeModel.fromJson(Map<String, dynamic> json) {
    final params = (json['params'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return BuildingUpgradeModel(
      id: (json['id'] ?? '').toString(),
      buildingKind: (json['building_kind'] ?? '').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      currentLevel: (json['current_level'] as num?)?.toInt() ?? 1,
      targetLevel: (json['target_level'] as num?)?.toInt() ?? 1,
      status: (json['status'] ?? 'in_progress').toString(),
      startedAt:
          DateTime.tryParse((json['started_at'] ?? '').toString()) ??
          DateTime.now(),
      finishAt:
          DateTime.tryParse((json['finish_at'] ?? '').toString()) ??
          DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      name: params['name']?.toString(),
      durationMinutes: (params['duration_minutes'] as num?)?.toInt() ?? 0,
      upgradeCost: (params['upgrade_cost'] as num?)?.toDouble() ?? 0,
      slotCapacityIncrease:
          (params['slot_capacity_increase'] as num?)?.toInt() ?? 0,
      maxSlotIncrease: (params['max_slot_increase'] as num?)?.toInt() ?? 0,
      previousSlotCapacity:
          (params['previous_slot_capacity'] as num?)?.toInt() ?? 0,
      nextSlotCapacity: (params['next_slot_capacity'] as num?)?.toInt() ?? 0,
      previousMaxSlotCount:
          (params['previous_max_slot_count'] as num?)?.toInt() ?? 0,
      nextMaxSlotCount:
          (params['next_max_slot_count'] as num?)?.toInt() ?? 0,
      inputCapacityIncrease:
          (params['input_capacity_increase'] as num?)?.toInt() ?? 0,
      outputCapacityIncrease:
          (params['output_capacity_increase'] as num?)?.toInt() ?? 0,
      previousInputCapacity:
          (params['previous_input_capacity'] as num?)?.toInt() ?? 0,
      nextInputCapacity:
          (params['next_input_capacity'] as num?)?.toInt() ?? 0,
      previousOutputCapacity:
          (params['previous_output_capacity'] as num?)?.toInt() ?? 0,
      nextOutputCapacity:
          (params['next_output_capacity'] as num?)?.toInt() ?? 0,
      capacityIncrease:
          (params['capacity_increase'] as num?)?.toDouble() ?? 0,
      previousCapacity:
          (params['previous_capacity'] as num?)?.toDouble() ?? 0,
      nextCapacity: (params['next_capacity'] as num?)?.toDouble() ?? 0,
      params: params,
    );
  }

  static BuildingUpgradeModel? fromJsonNullable(Map<String, dynamic>? json) {
    if (json == null || json['id'] == null) {
      return null;
    }
    return BuildingUpgradeModel.fromJson(json);
  }
}

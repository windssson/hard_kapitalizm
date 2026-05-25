class BuildingBoostModel {
  final String id;
  final String buildingKind;
  final String entityId;
  final int durationHours;
  final int starCost;
  final double multiplier;
  final String status;
  final DateTime startedAt;
  final DateTime finishAt;
  final DateTime? completedAt;

  const BuildingBoostModel({
    required this.id,
    required this.buildingKind,
    required this.entityId,
    required this.durationHours,
    required this.starCost,
    required this.multiplier,
    required this.status,
    required this.startedAt,
    required this.finishAt,
    required this.completedAt,
  });

  bool get isInProgress => status == 'in_progress';

  factory BuildingBoostModel.fromJson(Map<String, dynamic> json) {
    return BuildingBoostModel(
      id: (json['id'] ?? '').toString(),
      buildingKind: (json['building_kind'] ?? '').toString(),
      entityId: (json['entity_id'] ?? '').toString(),
      durationHours: (json['duration_hours'] as num?)?.toInt() ?? 0,
      starCost: (json['star_cost'] as num?)?.toInt() ?? 0,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
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
    );
  }
}

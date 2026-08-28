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

  BuildingBoostModel copyWith({
    String? id,
    String? buildingKind,
    String? entityId,
    int? durationHours,
    int? starCost,
    double? multiplier,
    String? status,
    DateTime? startedAt,
    DateTime? finishAt,
    DateTime? completedAt,
  }) {
    return BuildingBoostModel(
      id: id ?? this.id,
      buildingKind: buildingKind ?? this.buildingKind,
      entityId: entityId ?? this.entityId,
      durationHours: durationHours ?? this.durationHours,
      starCost: starCost ?? this.starCost,
      multiplier: multiplier ?? this.multiplier,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishAt: finishAt ?? this.finishAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
  Duration get totalDuration => finishAt.difference(startedAt);
  int get durationMinutes {
    final derived = totalDuration.inMinutes;
    if (derived > 0) return derived;
    return durationHours > 0 ? durationHours * 60 : 0;
  }

  String get durationLabel {
    final minutes = durationMinutes;
    if (minutes <= 0) {
      return durationHours > 0 ? '$durationHours saat' : '0 dk';
    }
    if (minutes < 60) return '$minutes dk';
    final hours = minutes ~/ 60;
    final extraMinutes = minutes % 60;
    if (extraMinutes == 0) return '$hours saat';
    return '$hours sa $extraMinutes dk';
  }

  factory BuildingBoostModel.fromJson(Map<String, dynamic> json) {
    return BuildingBoostModel(
      id: (json['id'] ?? json['boost_id'] ?? '').toString(),
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

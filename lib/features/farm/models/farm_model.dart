class FarmModel {
  final String id;
  final String playerId;
  final String farmTypeId;
  final String cityId;
  final String name;
  final int level;
  final int currentSlotCount;
  final int maxSlotCount;
  final int inputCapacity;
  final int outputCapacity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FarmModel({
    required this.id,
    required this.playerId,
    required this.farmTypeId,
    required this.cityId,
    required this.name,
    required this.level,
    required this.currentSlotCount,
    required this.maxSlotCount,
    required this.inputCapacity,
    required this.outputCapacity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      farmTypeId: json['farm_type_id'] as String,
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      currentSlotCount: (json['current_slot_count'] as num?)?.toInt() ?? 0,
      maxSlotCount: (json['max_slot_count'] as num?)?.toInt() ?? 0,
      inputCapacity: (json['input_capacity'] as num?)?.toInt() ?? 0,
      outputCapacity: (json['output_capacity'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'farm_type_id': farmTypeId,
      'city_id': cityId,
      'name': name,
      'level': level,
      'current_slot_count': currentSlotCount,
      'max_slot_count': maxSlotCount,
      'input_capacity': inputCapacity,
      'output_capacity': outputCapacity,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FarmModel copyWith({
    String? id,
    String? playerId,
    String? farmTypeId,
    String? cityId,
    String? name,
    int? level,
    int? currentSlotCount,
    int? maxSlotCount,
    int? inputCapacity,
    int? outputCapacity,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FarmModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      farmTypeId: farmTypeId ?? this.farmTypeId,
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      level: level ?? this.level,
      currentSlotCount: currentSlotCount ?? this.currentSlotCount,
      maxSlotCount: maxSlotCount ?? this.maxSlotCount,
      inputCapacity: inputCapacity ?? this.inputCapacity,
      outputCapacity: outputCapacity ?? this.outputCapacity,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

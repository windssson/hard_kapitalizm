class FactoryModel {
  final String id;
  final String playerId;
  final String factoryTypeId;
  final String cityId;
  final String name;
  final int level;
  final String? productId;
  final int qualityLevel;
  final int inputCapacity;
  final int outputCapacity;
  final double boostMultiplier;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  FactoryModel({
    required this.id,
    required this.playerId,
    required this.factoryTypeId,
    required this.cityId,
    required this.name,
    required this.level,
    this.productId,
    required this.qualityLevel,
    required this.inputCapacity,
    required this.outputCapacity,
    required this.boostMultiplier,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FactoryModel.fromJson(Map<String, dynamic> json) {
    return FactoryModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      factoryTypeId: json['factory_type_id'] as String,
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      level: json['level'] as int? ?? 1,
      productId: json['product_id'] as String?,
      qualityLevel: json['quality_level'] as int? ?? 0,
      inputCapacity: json['input_capacity'] as int? ?? 0,
      outputCapacity: json['output_capacity'] as int? ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'factory_type_id': factoryTypeId,
      'city_id': cityId,
      'name': name,
      'level': level,
      'product_id': productId,
      'quality_level': qualityLevel,
      'input_capacity': inputCapacity,
      'output_capacity': outputCapacity,
      'boost_multiplier': boostMultiplier,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

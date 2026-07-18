class FactoryModel {
  final String id;
  final String playerId;
  final String factoryTypeId;
  final String cityId;
  final String name;
  final int level;
  final String? productId;
  final String brandId;
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
    this.brandId = '00000000-0000-0000-0000-000000000000',
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
      brandId:
          (json['brand_id'] ?? '00000000-0000-0000-0000-000000000000')
              .toString(),
      qualityLevel: json['quality_level'] as int? ?? 0,
      inputCapacity: json['input_capacity'] as int? ?? 0,
      outputCapacity: json['output_capacity'] as int? ?? 0,
      boostMultiplier: (json['boost_multiplier'] as num?)?.toDouble() ?? 1.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  FactoryModel copyWith({
    String? id,
    String? playerId,
    String? factoryTypeId,
    String? cityId,
    String? name,
    int? level,
    String? productId,
    String? brandId,
    int? qualityLevel,
    int? inputCapacity,
    int? outputCapacity,
    double? boostMultiplier,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FactoryModel(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      factoryTypeId: factoryTypeId ?? this.factoryTypeId,
      cityId: cityId ?? this.cityId,
      name: name ?? this.name,
      level: level ?? this.level,
      productId: productId ?? this.productId,
      brandId: brandId ?? this.brandId,
      qualityLevel: qualityLevel ?? this.qualityLevel,
      inputCapacity: inputCapacity ?? this.inputCapacity,
      outputCapacity: outputCapacity ?? this.outputCapacity,
      boostMultiplier: boostMultiplier ?? this.boostMultiplier,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'brand_id': brandId,
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

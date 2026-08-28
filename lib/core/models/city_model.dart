class CityModel {
  final String id;
  final String name;
  final int population;
  final double taxRate;
  final double mapPositionX;
  final double mapPositionY;
  final bool isActive;
  final Map<String, double> categoryBonuses;

  CityModel({
    required this.id,
    required this.name,
    required this.population,
    required this.taxRate,
    required this.mapPositionX,
    required this.mapPositionY,
    required this.isActive,
    required this.categoryBonuses,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final bonuses = <String, double>{};
    json.forEach((key, val) {
      if (key.startsWith('bonus_')) {
        bonuses[key] = parseDouble(val);
      }
    });

    return CityModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      population: (json['population'] as num?)?.toInt() ?? 0,
      taxRate: parseDouble(json['tax_rate']),
      mapPositionX: parseDouble(json['map_position_x']),
      mapPositionY: parseDouble(json['map_position_y']),
      isActive: json['is_active'] as bool? ?? true,
      categoryBonuses: bonuses,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'population': population,
      'tax_rate': taxRate,
      'map_position_x': mapPositionX,
      'map_position_y': mapPositionY,
      'is_active': isActive,
      ...categoryBonuses,
    };
  }
}

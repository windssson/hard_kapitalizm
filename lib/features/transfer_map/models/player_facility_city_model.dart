class PlayerFacilityItemModel {
  final String id;
  final String name;
  final String kind;
  final String kindDisplay;
  final int totalCapacity;
  final int totalStock;

  const PlayerFacilityItemModel({
    required this.id,
    required this.name,
    required this.kind,
    required this.kindDisplay,
    required this.totalCapacity,
    required this.totalStock,
  });

  factory PlayerFacilityItemModel.fromJson(Map<String, dynamic> json) {
    return PlayerFacilityItemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Tesis',
      kind: json['kind'] as String? ?? '',
      kindDisplay: json['kind_display'] as String? ?? 'Tesis',
      totalCapacity: (json['total_capacity'] as num?)?.toInt() ?? 0,
      totalStock: (json['total_stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerFacilityCityModel {
  final String cityId;
  final String cityName;
  final int facilityCount;
  final int totalCityStock;
  final List<PlayerFacilityItemModel> facilities;

  const PlayerFacilityCityModel({
    required this.cityId,
    required this.cityName,
    required this.facilityCount,
    required this.totalCityStock,
    required this.facilities,
  });

  factory PlayerFacilityCityModel.fromJson(Map<String, dynamic> json) {
    final rawFacilities = json['facilities'] as List<dynamic>? ?? const [];
    return PlayerFacilityCityModel(
      cityId: json['city_id'] as String? ?? '',
      cityName: json['city_name'] as String? ?? '',
      facilityCount: (json['facility_count'] as num?)?.toInt() ?? 0,
      totalCityStock: (json['total_city_stock'] as num?)?.toInt() ?? 0,
      facilities: rawFacilities
          .map((e) => PlayerFacilityItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

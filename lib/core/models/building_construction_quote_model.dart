import 'package:hard_kapitalizm/core/models/required_material_model.dart';

class BuildingConstructionQuoteModel {
  const BuildingConstructionQuoteModel({
    required this.success,
    required this.canConstruct,
    required this.blockReason,
    required this.cityId,
    required this.buildingKind,
    required this.buildingTypeId,
    required this.name,
    required this.cashCost,
    required this.playerCash,
    required this.hasRequiredCash,
    required this.requiredPlayerLevel,
    required this.durationMinutes,
    required this.requiredMaterials,
    required this.materialsAllMet,
    required this.materialSource,
    required this.materialSourceCityId,
    required this.constructionMaterialsExempt,
    required this.completedDueConstructions,
  });

  final bool success;
  final bool canConstruct;
  final String? blockReason;
  final String cityId;
  final String buildingKind;
  final String? buildingTypeId;
  final String name;
  final double cashCost;
  final double playerCash;
  final bool hasRequiredCash;
  final int requiredPlayerLevel;
  final int durationMinutes;
  final List<RequiredMaterialModel> requiredMaterials;
  final bool materialsAllMet;
  final String materialSource;
  final String? materialSourceCityId;
  final bool constructionMaterialsExempt;
  final int completedDueConstructions;

  factory BuildingConstructionQuoteModel.fromJson(Map<String, dynamic> json) {
    final materials = json['required_materials'] as List? ?? const [];
    return BuildingConstructionQuoteModel(
      success: json['success'] == true,
      canConstruct: json['can_construct'] == true,
      blockReason: json['block_reason']?.toString(),
      cityId: (json['city_id'] ?? '').toString(),
      buildingKind: (json['building_kind'] ?? '').toString(),
      buildingTypeId: json['building_type_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      cashCost: (json['cash_cost'] as num?)?.toDouble() ?? 0,
      playerCash: (json['player_cash'] as num?)?.toDouble() ?? 0,
      hasRequiredCash: json['has_required_cash'] as bool? ?? false,
      requiredPlayerLevel:
          (json['required_player_level'] as num?)?.toInt() ?? 1,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      requiredMaterials: materials
          .whereType<Map>()
          .map(
            (row) => RequiredMaterialModel.fromJson(
              Map<String, dynamic>.from(row),
            ),
          )
          .toList(growable: false),
      materialsAllMet: json['materials_all_met'] as bool? ?? true,
      materialSource: (json['material_source'] ?? '').toString(),
      materialSourceCityId: json['material_source_city_id']?.toString(),
      constructionMaterialsExempt:
          json['construction_materials_exempt'] as bool? ?? false,
      completedDueConstructions:
          (json['completed_due_constructions'] as num?)?.toInt() ?? 0,
    );
  }
}

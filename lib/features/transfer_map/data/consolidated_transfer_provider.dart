import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/features/market/models/market_transfer_vehicle_option_model.dart';
import 'package:hard_kapitalizm/features/transfer_map/models/player_facility_city_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// MODELLER
// ============================================================================

class ConsolidatedTargetModel {
  final String id;
  final String name;
  final String entityKind;
  final String entityKindDisplay;
  final String cityId;
  final String cityName;
  final double totalCapacity;
  final double usedCapacity;
  final double emptyCapacity;
  final List<String>? acceptedProductIds;
  final Map<String, int>? acceptedProductQualities;
  final int minQualityLevel;

  const ConsolidatedTargetModel({
    required this.id,
    required this.name,
    required this.entityKind,
    required this.entityKindDisplay,
    required this.cityId,
    required this.cityName,
    required this.totalCapacity,
    required this.usedCapacity,
    required this.emptyCapacity,
    this.acceptedProductIds,
    this.acceptedProductQualities,
    this.minQualityLevel = 1,
  });

  bool acceptsProduct(String productId) {
    if (acceptedProductIds == null) return true; // Genel depolar her ürünü kabul eder
    final upper = productId.trim().toUpperCase();
    return acceptedProductIds!.any((id) => id.trim().toUpperCase() == upper);
  }

  bool get isProductionUnit =>
      entityKind == 'factory' || entityKind == 'farm' || entityKind == 'field';

  int getRequiredQualityFor(String productId) {
    if (!isProductionUnit) return 1;
    if (acceptedProductQualities != null) {
      final upper = productId.trim().toUpperCase();
      for (final entry in acceptedProductQualities!.entries) {
        if (entry.key.trim().toUpperCase() == upper) {
          return entry.value;
        }
      }
    }
    return minQualityLevel;
  }

  bool acceptsQuality(String productId, int itemQuality) {
    if (!isProductionUnit) return true;
    final req = getRequiredQualityFor(productId);
    return itemQuality == req;
  }

  bool acceptsItem({required String productId, required int qualityLevel}) {
    return acceptsProduct(productId) && acceptsQuality(productId, qualityLevel);
  }

  bool acceptsAllProducts(Set<String> selectedProductIds) {
    if (acceptedProductIds == null) return true;
    if (selectedProductIds.isEmpty) return true;
    return selectedProductIds.every((id) => acceptsProduct(id));
  }

  factory ConsolidatedTargetModel.fromJson(Map<String, dynamic> json) {
    final rawAccepted = json['accepted_product_ids'];
    List<String>? accepted;
    if (rawAccepted is List) {
      accepted = rawAccepted.map((e) => e.toString()).toList();
    }

    final rawQualities = json['accepted_product_qualities'];
    Map<String, int>? qualities;
    if (rawQualities is Map) {
      qualities = {};
      for (final entry in rawQualities.entries) {
        final val = (entry.value as num?)?.toInt();
        if (val != null) {
          qualities[entry.key.toString()] = val;
        }
      }
    }

    return ConsolidatedTargetModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      entityKind: json['entity_kind']?.toString() ?? 'warehouse',
      entityKindDisplay: json['entity_kind_display']?.toString() ?? 'Tesis',
      cityId: json['city_id']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? '',
      totalCapacity: (json['total_capacity'] as num?)?.toDouble() ?? 0.0,
      usedCapacity: (json['used_capacity'] as num?)?.toDouble() ?? 0.0,
      emptyCapacity: (json['empty_capacity'] as num?)?.toDouble() ?? 0.0,
      acceptedProductIds: accepted,
      acceptedProductQualities: qualities,
      minQualityLevel: (json['min_quality_level'] as num?)?.toInt() ?? 1,
    );
  }
}

class ConsolidatedSourceCityModel {
  final String cityId;
  final String cityName;
  final int facilityCount;
  final int totalStock;
  final double mapPositionX;
  final double mapPositionY;

  const ConsolidatedSourceCityModel({
    required this.cityId,
    required this.cityName,
    this.facilityCount = 0,
    this.totalStock = 0,
    this.mapPositionX = 0.5,
    this.mapPositionY = 0.5,
  });

  factory ConsolidatedSourceCityModel.fromJson(Map<String, dynamic> json) {
    return ConsolidatedSourceCityModel(
      cityId: json['city_id']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? '',
      facilityCount: (json['facility_count'] as num?)?.toInt() ?? 0,
      totalStock: (json['total_stock'] as num?)?.toInt() ?? 0,
      mapPositionX: (json['map_position_x'] as num?)?.toDouble() ?? 0.0,
      mapPositionY: (json['map_position_y'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ConsolidatedCandidateItemModel {
  final String sourceKind;
  final String sourceKindDisplay;
  final String sourceId;
  final String sourceName;
  final String itemId;
  final String productId;
  final String productName;
  final String? productIcon;
  final double birimHacim;
  final int availableQuantity;
  final int qualityLevel;
  final double unitCost;
  final String brandId;
  final String brandName;

  const ConsolidatedCandidateItemModel({
    required this.sourceKind,
    required this.sourceKindDisplay,
    required this.sourceId,
    required this.sourceName,
    required this.itemId,
    required this.productId,
    required this.productName,
    this.productIcon,
    required this.birimHacim,
    required this.availableQuantity,
    required this.qualityLevel,
    required this.unitCost,
    required this.brandId,
    required this.brandName,
  });

  factory ConsolidatedCandidateItemModel.fromJson(Map<String, dynamic> json) {
    return ConsolidatedCandidateItemModel(
      sourceKind: json['source_kind']?.toString() ?? 'warehouse',
      sourceKindDisplay: json['source_kind_display']?.toString() ?? 'Tesis',
      sourceId: json['source_id']?.toString() ?? '',
      sourceName: json['source_name']?.toString() ?? '',
      itemId: json['item_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      productIcon: json['product_icon']?.toString(),
      birimHacim: (json['birim_hacim'] as num?)?.toDouble() ?? 1.0,
      availableQuantity: (json['quantity'] as num?)?.toInt() ?? 0,
      qualityLevel: (json['quality_level'] as num?)?.toInt() ?? 1,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0.0,
      brandId: json['brand_id']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? 'Standart',
    );
  }
}

// ============================================================================
// PROVIDER'LAR
// ============================================================================

final consolidatedTransferTargetsProvider =
    FutureProvider.autoDispose<List<ConsolidatedTargetModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_city_consolidated_transfer_targets');
  final list = response as List<dynamic>? ?? const [];
  return list
      .map((e) => ConsolidatedTargetModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final consolidatedTransferSourceCitiesProvider =
    FutureProvider.autoDispose<List<ConsolidatedSourceCityModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_city_consolidated_transfer_source_cities');
  final list = response as List<dynamic>? ?? const [];
  return list
      .map((e) => ConsolidatedSourceCityModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});

final consolidatedTransferCityCandidatesProvider = FutureProvider.autoDispose
    .family<List<ConsolidatedCandidateItemModel>, String>(
  (ref, sourceCityId) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.rpc(
      'get_city_consolidated_transfer_candidates',
      params: {
        'p_source_city_id': sourceCityId,
      },
    );
    final list = response as List<dynamic>? ?? const [];
    return list
        .map((e) => ConsolidatedCandidateItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  },
);

final consolidatedTransferActionProvider = Provider((ref) => ConsolidatedTransferAction(ref));

class ConsolidatedTransferAction {
  final Ref ref;
  ConsolidatedTransferAction(this.ref);

  Future<Map<String, dynamic>> startCityConsolidatedTransfer({
    required String sourceCityId,
    required String targetEntityKind,
    required String targetEntityId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
  }) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'start_city_consolidated_transfer',
        params: {
          'p_source_city_id': sourceCityId,
          'p_target_entity_kind': targetEntityKind,
          'p_target_entity_id': targetEntityId,
          'p_items': items,
          'p_vehicle_id': vehicleId,
        },
      );
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<TransferVehicleOptionsResult<MarketTransferVehicleOptionModel>> getRouteOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) async {
    final service = TransferVehicleOptionsService();
    final rows = await service.getRouteOptions(
      RouteTransferVehicleOptionsRequest(
        sourceCityId: sourceCityId,
        targetCityId: targetCityId,
        totalVolume: totalVolume,
      ),
    );
    return mapTransferVehicleOptions(
      rows: rows,
      mapper: MarketTransferVehicleOptionModel.fromJson,
    );
  }
}

final playerFacilityCitiesProvider =
    FutureProvider.autoDispose<List<PlayerFacilityCityModel>>((ref) async {
  final supabase = Supabase.instance.client;
  final response = await supabase.rpc('get_player_facility_cities_summary');
  final map = response as Map<String, dynamic>? ?? {};
  final list = map['cities'] as List<dynamic>? ?? const [];
  return list
      .map((e) => PlayerFacilityCityModel.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
});


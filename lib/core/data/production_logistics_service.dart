import 'package:hard_kapitalizm/core/data/transfer_vehicle_options_service.dart';
import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductionLogisticsService {
  final SupabaseClient _supabase;
  final TransferVehicleOptionsService _vehicleOptionsService;

  ProductionLogisticsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client,
      _vehicleOptionsService = TransferVehicleOptionsService(
        supabase: supabase,
      );

  Future<List<Map<String, dynamic>>> getPlayerWarehouses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase.rpc(
      'get_player_active_warehouses_basic',
    );

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPlayerWarehousesRaw() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Oturum acilmamis.');
    }

    final response = await _supabase.rpc(
      'get_player_warehouses_raw',
    );

    return (response as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<List<ProductionLogisticsWarehouseOption>> getWarehouseOptions({
    required String productionCityId,
    required String productId,
  }) async {
    final warehouses = await getPlayerWarehousesRaw();
    return warehouses
        .where((row) => row['is_active'] == true)
        .where((row) {
          final warehouseType = row['warehouse_type'];
          if (warehouseType is! Map) return false;
          final acceptedProductIds = _parseAcceptedProductIds(
            warehouseType['accepted_product_ids'],
          );
          if (acceptedProductIds.isEmpty) return false;
          final normalizedProductId = productId.trim().toLowerCase();
          return acceptedProductIds.any(
            (acceptedId) => acceptedId.toLowerCase() == normalizedProductId,
          );
        })
        .map(
          (row) => ProductionLogisticsWarehouseOption.fromJson(
            row,
            productionCityId: productionCityId,
          ),
        )
        .toList();
  }

  List<String> _parseAcceptedProductIds(dynamic rawValue) {
    if (rawValue == null) return const [];

    return rawValue
        .toString()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
  getProductionInputTransferVehicleOptions({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
  }) async {
    final response = await _vehicleOptionsService.getOptions(
      TransferVehicleOptionsRequest(
        sourceKind: 'warehouse_slot',
        sourceId: warehouseSlotId,
        targetKind: 'production_inventory',
        targetId: productionInventoryId,
        quantity: quantity,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: ProductionLogisticsVehicleOption.fromJson,
    );
  }

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
  getProductionOutputTransferVehicleOptions({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
  }) async {
    final response = await _vehicleOptionsService.getOptions(
      TransferVehicleOptionsRequest(
        sourceKind: 'production_inventory',
        sourceId: productionInventoryId,
        targetKind: 'warehouse',
        targetId: buyerWarehouseId,
        quantity: quantity,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: ProductionLogisticsVehicleOption.fromJson,
    );
  }

  Future<TransferVehicleOptionsResult<ProductionLogisticsVehicleOption>>
  getRouteVehicleOptions({
    required String sourceCityId,
    required String targetCityId,
    required double totalVolume,
  }) async {
    final response = await _vehicleOptionsService.getRouteOptions(
      RouteTransferVehicleOptionsRequest(
        sourceCityId: sourceCityId,
        targetCityId: targetCityId,
        totalVolume: totalVolume,
      ),
    );

    return mapTransferVehicleOptions(
      rows: response,
      mapper: ProductionLogisticsVehicleOption.fromJson,
    );
  }

  Future<ProductionLogisticsStartResult> startMultiWarehouseToProductionTransfer({
    required String sourceWarehouseId,
    String? productionInventoryId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
  }) async {
    try {
      String? resolvedProductionInventoryId = productionInventoryId;
      if (resolvedProductionInventoryId == null ||
          resolvedProductionInventoryId.isEmpty) {
        final inventoryIds = items
            .map((item) => item['production_inventory_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        if (inventoryIds.length == 1) {
          resolvedProductionInventoryId = inventoryIds.first;
        }
      }

      final params = <String, dynamic>{
        'p_source_warehouse_id': sourceWarehouseId,
        'p_items': items,
        'p_vehicle_id': vehicleId,
      };
      if (resolvedProductionInventoryId != null &&
          resolvedProductionInventoryId.isNotEmpty) {
        params['p_production_inventory_id'] = resolvedProductionInventoryId;
      }

      final response = await _supabase.rpc(
        'start_multi_warehouse_to_production_transfer',
        params: params,
      );

      return ProductionLogisticsStartResult.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      return ProductionLogisticsStartResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<ProductionLogisticsStartResult> startMultiProductionToWarehouseTransfer({
    required String sourceOwnerKind,
    required String sourceOwnerId,
    required String buyerWarehouseId,
    required List<Map<String, dynamic>> items,
    String? vehicleId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'start_multi_production_to_warehouse_transfer',
        params: {
          'p_source_owner_kind': sourceOwnerKind,
          'p_source_owner_id': sourceOwnerId,
          'p_buyer_warehouse_id': buyerWarehouseId,
          'p_items': items,
          'p_vehicle_id': vehicleId,
        },
      );

      return ProductionLogisticsStartResult.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (e) {
      return ProductionLogisticsStartResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

import 'package:hard_kapitalizm/core/models/production_logistics_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _routeMismatchReason =
    'Aracin rotasi bu sehir ciftini desteklemiyor.';

class ProductionLogisticsService {
  final SupabaseClient _supabase;

  ProductionLogisticsService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

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

  Future<List<ProductionLogisticsWarehouseOption>> getWarehouseOptions({
    required String productionCityId,
  }) async {
    final warehouses = await getPlayerWarehouses();
    return warehouses
        .map(
          (row) => ProductionLogisticsWarehouseOption.fromJson(
            row,
            productionCityId: productionCityId,
          ),
        )
        .toList();
  }

  Future<List<ProductionLogisticsVehicleOption>>
  getProductionInputTransferVehicleOptions({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_production_input_transfer_vehicle_options',
      params: {
        'p_warehouse_slot_id': warehouseSlotId,
        'p_production_inventory_id': productionInventoryId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (row) => ProductionLogisticsVehicleOption.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((option) => option.disabledReason != _routeMismatchReason)
        .toList();
  }

  Future<List<ProductionLogisticsVehicleOption>>
  getProductionOutputTransferVehicleOptions({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
  }) async {
    final response = await _supabase.rpc(
      'get_production_output_transfer_vehicle_options',
      params: {
        'p_production_inventory_id': productionInventoryId,
        'p_buyer_warehouse_id': buyerWarehouseId,
        'p_quantity': quantity,
      },
    );

    return (response as List<dynamic>)
        .map(
          (row) => ProductionLogisticsVehicleOption.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .where((option) => option.disabledReason != _routeMismatchReason)
        .toList();
  }

  Future<ProductionLogisticsStartResult> startWarehouseToProductionTransfer({
    required String warehouseSlotId,
    required String productionInventoryId,
    required int quantity,
    String? vehicleId,
  }) async {
    final response = await _supabase.rpc(
      'start_warehouse_to_production_transfer',
      params: {
        'p_warehouse_slot_id': warehouseSlotId,
        'p_production_inventory_id': productionInventoryId,
        'p_quantity': quantity,
        'p_vehicle_id': vehicleId,
      },
    );

    return ProductionLogisticsStartResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<ProductionLogisticsStartResult> startProductionToWarehouseTransfer({
    required String productionInventoryId,
    required String buyerWarehouseId,
    required int quantity,
    String? vehicleId,
  }) async {
    final response = await _supabase.rpc(
      'start_production_to_warehouse_transfer',
      params: {
        'p_production_inventory_id': productionInventoryId,
        'p_buyer_warehouse_id': buyerWarehouseId,
        'p_quantity': quantity,
        'p_vehicle_id': vehicleId,
      },
    );

    return ProductionLogisticsStartResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }
}

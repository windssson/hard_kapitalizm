import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/models/player_active_product_model.dart';
import 'dart:developer' as developer;

class PlayerActiveProductsService {
  final SupabaseClient _supabase;

  PlayerActiveProductsService(this._supabase);

  Future<List<PlayerActiveProductModel>> getPlayerActiveProducts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      developer.log('getPlayerActiveProducts: No user session', name: 'PlayerActiveProducts');
      return [];
    }

    try {
      // Single RPC call replacing 6 separate database queries:
      final response = await _supabase.rpc(
        'get_player_active_products_data',
        params: {'p_player_id': user.id},
      );

      if (response == null) return [];

      final data = Map<String, dynamic>.from(response as Map);

      final storesList = data['stores'] as List<dynamic>? ?? const [];
      final factoriesList = data['factories'] as List<dynamic>? ?? const [];
      final farmsList = data['farms'] as List<dynamic>? ?? const [];
      final minesList = data['mines'] as List<dynamic>? ?? const [];
      final fieldsList = data['fields'] as List<dynamic>? ?? const [];
      final inventoriesList = data['inventories'] as List<dynamic>? ?? const [];

      // Group production unit IDs and names
      final productionUnits = <String, Map<String, String>>{}; // id -> {name, kind}

      for (final row in factoriesList) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'factory',
        };
      }

      for (final row in farmsList) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'farm',
        };
      }

      for (final row in minesList) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'mine',
        };
      }

      for (final row in fieldsList) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'field',
        };
      }

      final results = <PlayerActiveProductModel>[];

      // Process store slots (Role: 'sale')
      for (final storeRow in storesList) {
        final store = Map<String, dynamic>.from(storeRow as Map);
        final storeId = store['id'].toString();
        final storeName = store['name'].toString();
        final slots = store['store_slots'] as List<dynamic>? ?? const [];
        for (final slotRow in slots) {
          final slot = Map<String, dynamic>.from(slotRow as Map);
          final productId = slot['product_id'] as String?;
          final quantity = (slot['quantity'] as num?)?.toInt() ?? 0;
          if (productId != null && quantity > 0) {
            final productMap = slot['products'] != null
                ? Map<String, dynamic>.from(slot['products'] as Map)
                : null;
            results.add(PlayerActiveProductModel(
              productId: productId,
              quantity: quantity,
              sourceKind: 'store',
              sourceName: storeName,
              sourceId: storeId,
              role: 'sale',
              productName: productMap?['urun_adi']?.toString(),
              productIcon: productMap?['urun_iconu']?.toString(),
            ));
          }
        }
      }

      // Process production unit inventories (Role: 'input' or 'output')
      for (final itemRow in inventoriesList) {
        final item = Map<String, dynamic>.from(itemRow as Map);
        final ownerId = item['owner_id'].toString();
        final productId = item['product_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final inventoryType = (item['inventory_type'] ?? 'output').toString();

        if (productId != null && quantity > 0) {
          final unitInfo = productionUnits[ownerId];
          final productMap = item['products'] != null
              ? Map<String, dynamic>.from(item['products'] as Map)
              : null;
          results.add(PlayerActiveProductModel(
            productId: productId,
            quantity: quantity,
            sourceKind: unitInfo?['kind'] ?? 'production',
            sourceName: unitInfo?['name'] ?? 'Uretim Birimi',
            sourceId: ownerId,
            role: inventoryType == 'input' ? 'input' : 'output',
            productName: productMap?['urun_adi']?.toString(),
            productIcon: productMap?['urun_iconu']?.toString(),
          ));
        }
      }

      developer.log('getPlayerActiveProducts: Loaded ${results.length} active products/inputs', name: 'PlayerActiveProducts');
      return results;
    } catch (e, stack) {
      developer.log('getPlayerActiveProducts: Error fetching player active products', error: e, stackTrace: stack, name: 'PlayerActiveProducts');
      return [];
    }
  }
}

final playerActiveProductsServiceProvider = Provider<PlayerActiveProductsService>((ref) {
  return PlayerActiveProductsService(Supabase.instance.client);
});

final playerActiveProductsProvider = FutureProvider<List<PlayerActiveProductModel>>((ref) async {
  final service = ref.watch(playerActiveProductsServiceProvider);
  return service.getPlayerActiveProducts();
});

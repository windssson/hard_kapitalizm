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
      // 1. Query all stores of the player along with their slots and product details
      final List<dynamic> storesResponse = await _supabase
          .from('stores')
          .select('id, name, store_slots(product_id, quantity, products(urun_adi, urun_iconu))')
          .eq('player_id', user.id);

      // 2. Query all production entities of the player (factories, farms, mines, fields)
      final List<dynamic> factoriesResponse = await _supabase
          .from('factories')
          .select('id, name')
          .eq('player_id', user.id);

      final List<dynamic> farmsResponse = await _supabase
          .from('farms')
          .select('id, name')
          .eq('player_id', user.id);

      final List<dynamic> minesResponse = await _supabase
          .from('mines')
          .select('id, name')
          .eq('player_id', user.id);

      final List<dynamic> fieldsResponse = await _supabase
          .from('fields')
          .select('id, name')
          .eq('player_id', user.id);

      // Group production unit IDs and names
      final productionUnits = <String, Map<String, String>>{}; // id -> {name, kind}
      
      for (final row in factoriesResponse) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'factory',
        };
      }
      
      for (final row in farmsResponse) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'farm',
        };
      }
      
      for (final row in minesResponse) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'mine',
        };
      }
      
      for (final row in fieldsResponse) {
        final map = Map<String, dynamic>.from(row as Map);
        productionUnits[map['id'].toString()] = {
          'name': map['name'].toString(),
          'kind': 'field',
        };
      }

      final results = <PlayerActiveProductModel>[];

      // Process store slots (Role: 'sale')
      for (final storeRow in storesResponse) {
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

      // If there are production units, query their inventories (both input and output)
      if (productionUnits.isNotEmpty) {
        final unitIds = productionUnits.keys.toList();
        final List<dynamic> inventoryResponse = await _supabase
            .from('production_inventory')
            .select('owner_id, product_id, inventory_type, quantity, products(urun_adi, urun_iconu)')
            .inFilter('owner_id', unitIds);

        for (final itemRow in inventoryResponse) {
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
      }

      developer.log('getPlayerActiveProducts: Loaded ${results.length} active products/inputs', name: 'PlayerActiveProducts');
      for (final p in results) {
        developer.log(' - [${p.role.toUpperCase()}] Product: ${p.productName ?? p.productId} (${p.quantity}) from ${p.sourceKind}:${p.sourceName}', name: 'PlayerActiveProducts');
      }

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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/industrial_production_slot_patch_service.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/core/models/production_slot_model.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reuses the already-loaded Factory detail payload instead of issuing a
/// second get_factory_detail_data RPC just to hydrate production slots.
final factoryProductionSlotBootstrapProvider = FutureProvider.autoDispose
    .family<void, String>((ref, factoryId) async {
      if (factoryId.isEmpty) return;

      final detail = await ref.watch(factoryDetailProvider(factoryId).future);
      ref.read(industrialProductionSlotRegistryProvider.notifier).seed(
            ownerKind: 'factory',
            ownerId: factoryId,
            slots: detail.productionSlots,
          );
    });

final factoryProductionSlotsProvider = Provider.autoDispose
    .family<AsyncValue<List<ProductionSlotContractModel>>, String>((ref, factoryId) {
      final bootstrap = ref.watch(factoryProductionSlotBootstrapProvider(factoryId));
      final slots = ref.watch(
        industrialProductionSlotsProvider(
          (ownerKind: 'factory', ownerId: factoryId),
        ),
      );

      if (slots.isNotEmpty) return AsyncData(slots);
      return bootstrap.when(
        data: (_) => AsyncData(slots),
        loading: () => const AsyncLoading(),
        error: AsyncError.new,
      );
    });

class FactoryMultiSlotActionService {
  FactoryMultiSlotActionService(this._ref);

  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> addSlot({required String factoryId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const {'success': false, 'message': 'Oturum açılmamış.'};
    }

    return _rpcAndSync(
      'add_production_slot',
      {
        'p_player_id': user.id,
        'p_owner_kind': 'factory',
        'p_owner_id': factoryId,
      },
    );
  }

  Future<Map<String, dynamic>> configureSlot({
    required String factoryId,
    required String slotId,
    required String productId,
    required int qualityLevel,
    String? brandId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const {'success': false, 'message': 'Oturum açılmamış.'};
    }

    final slots = _ref
        .read(industrialProductionSlotRegistryProvider.notifier)
        .slotsFor(ownerKind: 'factory', ownerId: factoryId);
    ProductionSlotContractModel? current;
    for (final slot in slots) {
      if (slot.id == slotId) {
        current = slot;
        break;
      }
    }

    final rpcName = current == null || current.isEmpty
        ? 'assign_production_slot_product'
        : 'change_production_slot_product';

    return _rpcAndSync(
      rpcName,
      {
        'p_player_id': user.id,
        'p_production_slot_id': slotId,
        'p_product_id': productId,
        'p_quality_level': qualityLevel,
        'p_brand_id': brandId,
      },
    );
  }

  Future<Map<String, dynamic>> setSlotActive({
    required String slotId,
    required bool isActive,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const {'success': false, 'message': 'Oturum açılmamış.'};
    }

    return _rpcAndSync(
      'set_production_slot_active',
      {
        'p_player_id': user.id,
        'p_production_slot_id': slotId,
        'p_is_active': isActive,
      },
    );
  }

  Future<Map<String, dynamic>> _rpcAndSync(
    String rpcName,
    Map<String, dynamic> params,
  ) async {
    try {
      final response = await _supabase.rpc(rpcName, params: params);
      final result = Map<String, dynamic>.from(response as Map);
      _ref.read(mutationSyncServiceProvider).applyRaw(result);
      return result;
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message, 'code': e.code};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final factoryMultiSlotActionProvider = Provider<FactoryMultiSlotActionService>((ref) {
  return FactoryMultiSlotActionService(ref);
});

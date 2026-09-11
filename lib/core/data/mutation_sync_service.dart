import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/entity_patch_dispatcher.dart';
import 'package:hard_kapitalizm/core/data/industrial_production_slot_patch_service.dart';
import 'package:hard_kapitalizm/core/data/production_building_insert_patch_service.dart';
import 'package:hard_kapitalizm/core/data/warehouse_slot_metadata_patch_service.dart';
import 'package:hard_kapitalizm/core/models/mutation/entity_patch.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';

/// Ortak mutation sync servisi.
/// RPC response'larından gelen `changed` bloğunu parse ederek
/// player, entity patches, dashboard, notification, tax vb. sağlayıcıları günceller.
///
/// Önemli: Backend mutation başarılı olduktan sonra oluşan yerel provider/patch
/// senkronizasyon hataları backend işlemini başarısız hale getirmemelidir. Aksi
/// halde kullanıcı "işlem başarısız" görüp aynı mutation'ı tekrar çalıştırabilir.
class MutationSyncService {
  final Ref _ref;

  MutationSyncService(this._ref);

  /// `MutationResponse` parse edilmiş bir RPC yanıtını uygular.
  void apply(MutationResponse mutation) {
    // Player
    if (mutation.playerChanges != null) {
      try {
        _ref.read(playerProvider.notifier).applyChanges(mutation.playerChanges!);
      } catch (e, st) {
        debugPrint('[MutationSync] player patch failed: $e\n$st');
      }
    }

    // Entity patches (store, warehouse, logistics, production, construction vb.)
    if (mutation.patches.isNotEmpty) {
      final dispatcher = _ref.read(entityPatchDispatcherProvider);
      final industrialSlotPatchService =
          _ref.read(industrialProductionSlotPatchServiceProvider);
      final productionBuildingInsertPatchService =
          _ref.read(productionBuildingInsertPatchServiceProvider);
      final warehouseMetadataPatchService =
          _ref.read(warehouseSlotMetadataPatchServiceProvider);
      for (final patch in mutation.patches) {
        try {
          // Raw production-building insert rows need local static-catalog
          // enrichment. This also handles Field/Farm initial slot inserts so a
          // successful construction completion does not need a list refetch.
          final handledProductionInsert =
              productionBuildingInsertPatchService.apply(patch);

          if (!handledProductionInsert) {
            // Factory/Mine multi-slot state is migrated in a small dedicated
            // layer before the legacy dispatcher. Field/Farm keep their
            // existing update handlers.
            final handledIndustrialSlot = industrialSlotPatchService.apply(patch);
            if (!handledIndustrialSlot) {
              dispatcher.dispatch(patch);
            }
          }
        } catch (e, st) {
          // Backend mutation bu noktaya gelmeden önce commit edilmiş olabilir.
          // Yerel cache/provider hatasını çağırana fırlatmak, başarılı işlemin
          // başarısız gösterilmesine ve çift mutation riskine yol açar.
          debugPrint(
            '[MutationSync] ${patch.entity}/${patch.operation.name} '
            'patch failed for ${patch.id}: $e\n$st',
          );
        }

        // Warehouse slot patch'leri wire üzerinde bilinçli olarak ham DB satırı
        // taşır. Dispatcher miktar/cost gibi state'i uygular; ardından statik ürün
        // kataloğundan ad/ikon/hacim metadata'sını network çağrısı olmadan tamamla.
        try {
          warehouseMetadataPatchService.apply(patch);
        } catch (e, st) {
          debugPrint(
            '[MutationSync] warehouse metadata enrichment failed for '
            '${patch.entity}/${patch.id}: $e\n$st',
          );
        }

        // Bazı entity'lerde terminal durum, "update" patch'iyle gelir. Dispatcher
        // model alanlarını patchledikten sonra lifecycle kuralını ayrıca uygula.
        // Böylece completed/cancelled/failed kayıtlar aktif listede kalmaz.
        try {
          _applyPatchLifecycleGuard(patch);
        } catch (e, st) {
          debugPrint(
            '[MutationSync] lifecycle guard failed for '
            '${patch.entity}/${patch.id}: $e\n$st',
          );
        }
      }
    }

    // Store history/performance dirty değerleri latch'tir: bir mutation true
    // yaptıktan sonra yalnız ilgili ekran başarılı refresh sonrasında false'a
    // çekebilir. Sıradan rebuild veya eski page snapshot'ı true değeri ezmemeli.
    _applyStoreDirtyFlags(mutation);

    // Dashboard dirty → invalidate (FutureProvider olduğu için doğrudan patch yok)
    if (mutation.dashboardDirty) {
      _ref.invalidate(homeDashboardProvider);
    }

    // Mission dirty
    if (mutation.missionDirty) {
      final hasMissionPatch = mutation.patches.any(
        (p) => p.entity == 'player_mission',
      );
      if (!hasMissionPatch) {
        _ref.invalidate(playerMissionDashboardProvider);
      }
    }

    // Achievement dirty
    if (mutation.achievementDirty) {
      _ref.invalidate(playerAchievementDashboardProvider);
    }

    // Tax dirty
    if (mutation.taxDirty) {
      final hasTaxPatch = mutation.patches.any(
        (p) => p.entity == 'player_tax',
      );
      if (!hasTaxPatch) {
        _ref.invalidate(taxDebtProvider);
        _ref.invalidate(playerTaxProvider);
      }
    }
  }

  void _applyPatchLifecycleGuard(EntityPatch patch) {
    if (patch.entity != 'tender_delivery') return;

    final status = patch.changes['status']?.toString().toLowerCase() ?? '';
    final terminal = patch.operation == PatchOperation.delete ||
        const {
          'completed',
          'cancelled',
          'failed',
          'failed_late',
          'expired',
        }.contains(status);
    if (!terminal) return;

    final playerTenderId =
        patch.changes['player_tender_id']?.toString().trim() ?? '';
    if (playerTenderId.isNotEmpty) {
      if (PlayerTenderDetailNotifier.activePlayerTenderIds
          .contains(playerTenderId)) {
        _ref
            .read(playerTenderDetailProvider(playerTenderId).notifier)
            .removeDelivery(patch.id);
      }
      return;
    }

    // Eski backend delete patch'lerinde identity key bulunmayabiliyordu.
    // Yeni contract bunu taşıyor; fallback yalnız geriye uyumluluk için kalır.
    for (final activeId
        in PlayerTenderDetailNotifier.activePlayerTenderIds.toList()) {
      _ref
          .read(playerTenderDetailProvider(activeId).notifier)
          .removeDelivery(patch.id);
    }
  }

  void _applyStoreDirtyFlags(MutationResponse mutation) {
    final hasPerformancePatch = mutation.patches.any(
      (patch) => patch.entity == 'store_daily_performance',
    );
    final shouldMarkPerformance =
        mutation.performanceDirty || hasPerformancePatch;
    final shouldMarkHistory = mutation.historyDirty;

    if (!shouldMarkPerformance && !shouldMarkHistory) return;

    final storeIds = _extractStoreIds(mutation);
    if (storeIds.isEmpty) {
      storeIds.addAll(StoreDetailPageNotifier.activeStoreIds);
    }

    for (final storeId in storeIds) {
      if (storeId.isEmpty) continue;
      try {
        final page = _ref.read(storeDetailPageProvider(storeId)).value;
        if (shouldMarkPerformance) {
          _ref.read(storePerformanceDirtyProvider(storeId).notifier).state = true;
          if (page != null) {
            _ref
                .read(storeDetailPageProvider(storeId).notifier)
                .markPerformanceDirty(true);
          }
        }
        if (shouldMarkHistory && page != null) {
          _ref
              .read(storeDetailPageProvider(storeId).notifier)
              .markHistoryDirty(true);
        }
      } catch (e, st) {
        debugPrint('[MutationSync] store dirty sync failed for $storeId: $e\n$st');
      }
    }
  }

  Set<String> _extractStoreIds(MutationResponse mutation) {
    final ids = <String>{};

    void add(dynamic value) {
      final id = value?.toString().trim() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }

    add(mutation.raw['store_id']);

    final rawStore = mutation.raw['store'];
    if (rawStore is Map) {
      add(rawStore['id']);
      final nestedStore = rawStore['store'];
      if (nestedStore is Map) add(nestedStore['id']);
    }

    for (final patch in mutation.patches) {
      if (patch.entity == 'store' ||
          patch.entity == 'store_slot' ||
          patch.entity == 'store_daily_performance') {
        add(patch.changes['store_id']);
        if (patch.entity == 'store') add(patch.id);
      }
    }

    return ids;
  }

  /// Ham RPC response Map'ini parse edip uygular.
  ///
  /// RPC cevabı zaten alınmışsa burada oluşabilecek istemci tarafı parse/sync
  /// hataları backend mutation sonucunu değiştirmez. Hata debug loguna yazılır.
  void applyRaw(Map<String, dynamic> response) {
    try {
      apply(MutationResponse.fromJson(response));
    } catch (e, st) {
      debugPrint('[MutationSync] response sync failed: $e\n$st');
    }
  }

  /// Sadece player'ı güncelle (sık kullanılan kısayol).
  void syncPlayer(Map<String, dynamic> response) {
    try {
      final mutation = MutationResponse.fromJson(response);
      if (mutation.playerChanges != null) {
        _ref.read(playerProvider.notifier).applyChanges(mutation.playerChanges!);
      }
    } catch (e, st) {
      debugPrint('[MutationSync] player-only sync failed: $e\n$st');
    }
  }
}

final mutationSyncServiceProvider = Provider<MutationSyncService>((ref) {
  return MutationSyncService(ref);
});

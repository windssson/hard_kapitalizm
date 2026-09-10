import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/entity_patch_dispatcher.dart';
import 'package:hard_kapitalizm/core/data/industrial_production_slot_patch_service.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';

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
      for (final patch in mutation.patches) {
        try {
          // Factory/Mine multi-slot state is migrated in a small dedicated layer
          // before the legacy dispatcher. Field/Farm keep their existing handler.
          final handledIndustrialSlot = industrialSlotPatchService.apply(patch);
          if (!handledIndustrialSlot) {
            dispatcher.dispatch(patch);
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
      }
    }

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
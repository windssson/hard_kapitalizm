import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/entity_patch_dispatcher.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';

import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';

/// Ortak mutation sync servisi.
/// RPC response'larından gelen `changed` bloğunu parse ederek
/// player, entity patches, dashboard, notification, tax vb. sağlayıcıları günceller.
class MutationSyncService {
  final Ref _ref;

  MutationSyncService(this._ref);

  /// `MutationResponse` parse edilmiş bir RPC yanıtını uygular.
  void apply(MutationResponse mutation) {
    // Player
    if (mutation.playerChanges != null) {
      _ref.read(playerProvider.notifier).applyChanges(mutation.playerChanges!);
    }

    // Entity patches (store, warehouse, logistics, production, construction vb.)
    if (mutation.patches.isNotEmpty) {
      final dispatcher = _ref.read(entityPatchDispatcherProvider);
      for (final patch in mutation.patches) {
        dispatcher.dispatch(patch);
      }
    }

    // Dashboard dirty → invalidate (FutureProvider olduğu için doğrudan patch yok)
    if (mutation.dashboardDirty) {
      _ref.invalidate(homeDashboardProvider);
    }



    // Mission dirty
    if (mutation.missionDirty) {
      _ref.invalidate(playerMissionDashboardProvider);
    }

    // Achievement dirty
    if (mutation.achievementDirty) {
      _ref.invalidate(playerAchievementDashboardProvider);
    }

    // Tax dirty → invalidate (TODO: tax_debt patch için RPC response'u genişletilmeli)
    if (mutation.taxDirty) {
      _ref.invalidate(taxDebtProvider);
      _ref.invalidate(playerTaxProvider);
    }
  }

  /// Ham RPC response Map'ini parse edip uygular.
  void applyRaw(Map<String, dynamic> response) {
    apply(MutationResponse.fromJson(response));
  }

  /// Sadece player'ı güncelle (sık kullanılan kısayol).
  void syncPlayer(Map<String, dynamic> response) {
    final mutation = MutationResponse.fromJson(response);
    if (mutation.playerChanges != null) {
      _ref.read(playerProvider.notifier).applyChanges(mutation.playerChanges!);
    }
  }
}

final mutationSyncServiceProvider = Provider<MutationSyncService>((ref) {
  return MutationSyncService(ref);
});

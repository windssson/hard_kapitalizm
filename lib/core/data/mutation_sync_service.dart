import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/models/mutation/mutation_response.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';

/// Ortak mutation sync servisi.
/// RPC response'larından gelen `changed` bloğunu parse ederek
/// player, dashboard, notification, tax vb. ortak provider'ları günceller.
///
/// Feature-specific entity değişimleri (store, factory, warehouse vb.)
/// ilgili feature'ın kendi notifier'ı tarafından uygulanır.
class MutationSyncService {
  final Ref _ref;

  MutationSyncService(this._ref);

  /// `MutationResponse` parse edilmiş bir RPC yanıtını uygular.
  void apply(MutationResponse mutation) {
    // Player
    if (mutation.playerChanges != null) {
      _ref.read(playerProvider.notifier).applyChanges(mutation.playerChanges!);
    }

    // Dashboard dirty → invalidate (FutureProvider olduğu için doğrudan patch yok)
    if (mutation.dashboardDirty) {
      _ref.invalidate(homeDashboardProvider);
    }

    // Notification dirty
    if (mutation.notificationDirty) {
      _ref.invalidate(playerNotificationDashboardProvider);
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

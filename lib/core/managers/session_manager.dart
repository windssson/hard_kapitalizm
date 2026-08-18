import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hard_kapitalizm/core/managers/auth_manager.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/arge/data/arge_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/auth_identity_provider.dart';
import 'package:hard_kapitalizm/features/auth/data/player_provider.dart';
import 'package:hard_kapitalizm/features/bank/data/bank_provider.dart';
import 'package:hard_kapitalizm/features/cash_flow/data/cash_flow_provider.dart';
import 'package:hard_kapitalizm/features/chat/providers/chat_provider.dart';
import 'package:hard_kapitalizm/features/company/data/company_provider.dart';
import 'package:hard_kapitalizm/features/factory/data/factory_provider.dart';
import 'package:hard_kapitalizm/features/farm/data/farm_provider.dart';
import 'package:hard_kapitalizm/features/field/data/field_provider.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/leaderboard/data/leaderboard_provider.dart';
import 'package:hard_kapitalizm/features/logistics/data/logistics_provider.dart';
import 'package:hard_kapitalizm/features/mine/data/mine_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/daily_streak_provider.dart';
import 'package:hard_kapitalizm/features/mission/data/mission_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/notification_provider.dart';
import 'package:hard_kapitalizm/features/notification/data/push_notification_service.dart';
import 'package:hard_kapitalizm/features/store/data/store_provider.dart';
import 'package:hard_kapitalizm/features/tax/data/tax_provider.dart';
import 'package:hard_kapitalizm/features/tender/data/tender_provider.dart';
import 'package:hard_kapitalizm/features/transfer_map/data/transfer_map_provider.dart';
import 'package:hard_kapitalizm/features/warehouse/data/warehouse_provider.dart';
import 'package:hard_kapitalizm/core/widgets/tutorial_provider.dart';

class SessionManager {
  /// Tum oyun provider'larini sifirlayarak yeni kullanici/oturum verilerini temiz yukler.
  static void invalidateAllGameProviders(WidgetRef ref) {
    ref.invalidate(authIdentityProvider);
    ref.invalidate(playerProvider);
    ref.invalidate(homeDashboardProvider);
    ref.invalidate(playerNotificationDashboardProvider);
    ref.invalidate(playerAchievementDashboardProvider);
    ref.invalidate(storesListProvider);
    ref.invalidate(warehouseListProvider);
    ref.invalidate(factoryListProvider);
    ref.invalidate(farmListProvider);
    ref.invalidate(fieldListProvider);
    ref.invalidate(mineListProvider);
    ref.invalidate(playerBrandCompanyProvider);
    ref.invalidate(playerBrandCompanyProductsProvider);
    ref.invalidate(playerLogisticsCompanyProvider);
    ref.invalidate(playerLogisticsConstructionProvider);
    ref.invalidate(logisticsVehicleListProvider);
    ref.invalidate(playerArgeCenterProvider);
    ref.invalidate(playerArgeConstructionProvider);
    ref.invalidate(playerMissionDashboardProvider);
    ref.invalidate(dailyStreakProvider);
    ref.invalidate(cashMovementEntriesProvider);
    ref.invalidate(tenderCenterProvider);
    ref.invalidate(buyerTransferMapProvider);
    ref.invalidate(buyerTransferHistoryProvider);
    ref.invalidate(transferItemsProvider);
    ref.invalidate(leaderboardProvider);
    ref.invalidate(tutorialProvider);
    ref.invalidate(chatProvider);
    ref.invalidate(taxDebtProvider);
    ref.invalidate(playerTaxProvider);
    ref.invalidate(playerLoansProvider);
    ref.invalidate(playerDepositsProvider);
    ref.invalidate(loanLimitProvider);
  }

  /// Oturum degistiginde veya Google ile giris yapildiginda oturumu bootstrap eder
  /// ve ardindan tum oyun verilerini gunceller.
  static Future<void> bootstrapAndRefreshAll(WidgetRef ref) async {
    try {
      await Supabase.instance.client.rpc('bootstrap_game_session');
    } catch (_) {}

    try {
      await ref.read(authManagerProvider).syncLinkedGoogleProfileMetadata();
    } catch (_) {}

    try {
      await ref.read(pushNotificationServiceProvider).initialize();
    } catch (_) {}

    invalidateAllGameProviders(ref);

    // Ana verileri onceden cek
    try {
      await Future.wait([
        ref.refresh(playerProvider.future),
        ref.refresh(homeDashboardProvider.future),
        ref.refresh(authIdentityProvider.future),
      ]);
    } catch (_) {}
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/core/data/mutation_sync_service.dart';
import 'package:hard_kapitalizm/features/achievement/models/achievement_badge_model.dart';
import 'package:hard_kapitalizm/features/achievement/models/player_achievement_dashboard_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerAchievementDashboardNotifier
    extends AsyncNotifier<PlayerAchievementDashboardModel> {
  @override
  Future<PlayerAchievementDashboardModel> build() async {
    final supabase = Supabase.instance.client;
    final response = await supabase.rpc('get_player_achievement_dashboard');
    return PlayerAchievementDashboardModel.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  void patchClaimAchievement(String achievementId) {
    final current = state.value;
    if (current == null) return;

    AchievementBadgeModel patchBadge(AchievementBadgeModel b) {
      if (b.id == achievementId) {
        return b.copyWith(
          isClaimed: true,
          isClaimable: false,
          isUnlocked: true,
        );
      }
      return b;
    }

    final newFeatured = current.featuredBadges.map(patchBadge).toList();
    final newActive = current.activeAchievements.map(patchBadge).toList();
    final newUnlocked = current.unlockedAchievements.map(patchBadge).toList();

    state = AsyncData(
      current.copyWith(
        featuredBadges: newFeatured,
        activeAchievements: newActive,
        unlockedAchievements: newUnlocked,
        claimableCount: (current.claimableCount - 1).clamp(0, 999999),
        unlockedCount: current.unlockedCount + 1,
      ),
    );
  }

  Future<void> refresh() async {
    try {
      final fresh = await build();
      state = AsyncData(fresh);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final playerAchievementDashboardProvider = AsyncNotifierProvider<
    PlayerAchievementDashboardNotifier, PlayerAchievementDashboardModel>(
  PlayerAchievementDashboardNotifier.new,
);

final achievementActionProvider =
    Provider((ref) => AchievementActionService(ref));

class AchievementActionService {
  final Ref _ref;
  final SupabaseClient _supabase = Supabase.instance.client;

  AchievementActionService(this._ref);

  Future<Map<String, dynamic>> claimAchievementReward(
    String achievementId,
  ) async {
    final response = await _supabase.rpc(
      'claim_player_achievement_reward',
      params: {'p_achievement_id': achievementId},
    );

    final resultMap = response is Map<String, dynamic>
        ? response
        : response is Map
            ? Map<String, dynamic>.from(response)
            : <String, dynamic>{'success': false};

    if (resultMap['success'] == true) {
      _ref
          .read(playerAchievementDashboardProvider.notifier)
          .patchClaimAchievement(achievementId);
      _ref.read(mutationSyncServiceProvider).applyRaw(resultMap);
    }

    return resultMap;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hard_kapitalizm/features/home/data/home_dashboard_provider.dart';
import 'package:hard_kapitalizm/features/achievement/data/achievement_provider.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_dashboard_model.dart';
import 'package:hard_kapitalizm/features/mission/models/player_mission_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlayerMissionDashboardNotifier
    extends AsyncNotifier<PlayerMissionDashboardModel> {
  @override
  Future<PlayerMissionDashboardModel> build() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc('get_player_mission_dashboard');
      return PlayerMissionDashboardModel.fromJson(
        Map<String, dynamic>.from(response as Map),
      );
    } catch (_) {
      return const PlayerMissionDashboardModel(
        success: false,
        mainMission: null,
        mainMissions: [],
        dailyMissions: [],
        achievements: [],
        weeklyMissions: [],
        sideMissions: [],
        claimableCount: 0,
        mainClaimableCount: 0,
        dailyClaimableCount: 0,
        achievementClaimableCount: 0,
        weeklyClaimableCount: 0,
        completedCount: 0,
        dailyCompletedCount: 0,
        totalCount: 0,
      );
    }
  }

  void patchClaimMission(String missionId) {
    final current = state.value;
    if (current == null) return;

    bool isDaily = false;
    bool isMain = false;
    bool isAchievement = false;
    bool isWeekly = false;

    PlayerMissionModel patchItem(PlayerMissionModel item) {
      if (item.id == missionId) {
        return item.copyWith(
          isClaimed: true,
          claimable: false,
          isCompleted: true,
        );
      }
      return item;
    }

    PlayerMissionModel? newMainMission = current.mainMission;
    if (newMainMission != null && newMainMission.id == missionId) {
      isMain = true;
      newMainMission = patchItem(newMainMission);
    }

    final newMainMissions = current.mainMissions.map((item) {
      if (item.id == missionId) isMain = true;
      return patchItem(item);
    }).toList();

    final newDailyMissions = current.dailyMissions.map((item) {
      if (item.id == missionId) isDaily = true;
      return patchItem(item);
    }).toList();

    final newAchievements = current.achievements.map((item) {
      if (item.id == missionId) isAchievement = true;
      return patchItem(item);
    }).toList();

    final newWeeklyMissions = current.weeklyMissions.map((item) {
      if (item.id == missionId) isWeekly = true;
      return patchItem(item);
    }).toList();

    final newSideMissions = current.sideMissions.map((item) {
      return patchItem(item);
    }).toList();

    state = AsyncData(
      current.copyWith(
        mainMission: newMainMission,
        mainMissions: newMainMissions,
        dailyMissions: newDailyMissions,
        achievements: newAchievements,
        weeklyMissions: newWeeklyMissions,
        sideMissions: newSideMissions,
        claimableCount: (current.claimableCount - 1).clamp(0, 999999),
        completedCount: current.completedCount + 1,
        dailyClaimableCount: isDaily
            ? (current.dailyClaimableCount - 1).clamp(0, 999999)
            : current.dailyClaimableCount,
        dailyCompletedCount:
            isDaily ? current.dailyCompletedCount + 1 : current.dailyCompletedCount,
        mainClaimableCount: isMain
            ? (current.mainClaimableCount - 1).clamp(0, 999999)
            : current.mainClaimableCount,
        achievementClaimableCount: isAchievement
            ? (current.achievementClaimableCount - 1).clamp(0, 999999)
            : current.achievementClaimableCount,
        weeklyClaimableCount: isWeekly
            ? (current.weeklyClaimableCount - 1).clamp(0, 999999)
            : current.weeklyClaimableCount,
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

final playerMissionDashboardProvider = AsyncNotifierProvider<
    PlayerMissionDashboardNotifier, PlayerMissionDashboardModel>(
  PlayerMissionDashboardNotifier.new,
);

class MissionActionNotifier {
  final Ref _ref;
  MissionActionNotifier(this._ref);

  Future<Map<String, dynamic>> claimMissionReward(String missionId) async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase.rpc(
        'claim_player_mission_reward',
        params: {'p_mission_id': missionId},
      );

      final result = Map<String, dynamic>.from(response as Map);

      if (result['success'] == true) {
        _ref
            .read(playerMissionDashboardProvider.notifier)
            .patchClaimMission(missionId);
        _ref.invalidate(homeDashboardProvider);
        _ref.invalidate(playerAchievementDashboardProvider);
        // Silently refresh in background in case subsequent missions are unlocked
        _ref.read(playerMissionDashboardProvider.notifier).refresh();
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

final missionActionProvider = Provider<MissionActionNotifier>((ref) {
  return MissionActionNotifier(ref);
});
